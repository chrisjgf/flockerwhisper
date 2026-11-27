import Foundation
import WhisperKit

public enum WhisperEngineError: LocalizedError, Sendable {
    case emptyAudio
    case cancelled
    case modelLoadFailed(String)
    case transcriptionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptyAudio:
            return "No speech detected."
        case .cancelled:
            return "Transcription cancelled."
        case .modelLoadFailed(let reason):
            return "Failed to load local Whisper model: \(reason)"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        }
    }
}

public actor WhisperEngine {
    private var whisperKit: WhisperKit?
    private var loadedVariant: String?
    private var prepareTask: Task<Void, Error>?
    private var preparingVariant: String?

    private let modelsBaseURL: URL

    public init(modelsBaseURL: URL? = nil) {
        if let modelsBaseURL {
            self.modelsBaseURL = modelsBaseURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
            self.modelsBaseURL = appSupport
                .appendingPathComponent("Flockerwhisper", isDirectory: true)
                .appendingPathComponent("Models", isDirectory: true)
        }
    }

    public func isReady(for variant: String) -> Bool {
        whisperKit != nil && loadedVariant == variant
    }

    public func preload(
        variant: String,
        onStatus: @escaping @Sendable (ModelEngineStatus) -> Void
    ) async throws {
        _ = try await ensurePipeline(variant: variant, onStatus: onStatus)
    }

    public func transcribe(
        samples: [Float],
        variant: String,
        onStatus: @escaping @Sendable (ModelEngineStatus) -> Void,
        onProgress: @escaping @Sendable (Double, String) -> Void
    ) async throws -> String {
        guard samples.count > 1600 else { // < 0.1s of 16 kHz audio
            throw WhisperEngineError.emptyAudio
        }

        try Task.checkCancellation()

        let pipeline: WhisperKit
        if let existing = whisperKit, loadedVariant == variant {
            pipeline = existing
        } else {
            onProgress(0.05, "Preparing local model…")
            pipeline = try await ensurePipeline(variant: variant) { status in
                onStatus(status)
                switch status {
                case .downloading(_, let fraction):
                    onProgress(0.05 + fraction * 0.65, "Downloading model (\(Int((fraction * 100).rounded()))%)…")
                case .loading:
                    onProgress(0.75, "Loading Core ML model…")
                case .ready:
                    onProgress(0.85, "Analysing audio…")
                default:
                    break
                }
            }
        }

        try Task.checkCancellation()
        onProgress(0.25, "Analysing speech…")

        let audioSeconds = max(1.0, Double(samples.count) / 16_000.0)
        let expectedWindows = max(1.0, ceil(audioSeconds / 30.0))

        let decodeOptions = DecodingOptions(
            verbose: false,
            task: .transcribe,
            temperature: 0.0,
            temperatureFallbackCount: 2,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: false,
            suppressBlank: true,
            noSpeechThreshold: 0.6
        )

        let results: [TranscriptionResult]
        do {
            results = try await pipeline.transcribe(
                audioArray: samples,
                decodeOptions: decodeOptions,
                callback: { progress in
                    if Task.isCancelled {
                        return false
                    }
                    let windowProgress = min(0.92, 0.30 + (Double(progress.windowId + 1) / (expectedWindows + 0.35)) * 0.62)
                    onProgress(windowProgress, "Converting speech to text…")
                    return true
                }
            )
        } catch is CancellationError {
            throw WhisperEngineError.cancelled
        } catch {
            if Task.isCancelled {
                throw WhisperEngineError.cancelled
            }
            throw WhisperEngineError.transcriptionFailed(error.localizedDescription)
        }

        try Task.checkCancellation()
        onProgress(0.96, "Finalising transcript…")

        let joined = results.map(\.text).joined(separator: " ")
        let cleaned = TranscriptTextCleaner.clean(joined)
        onProgress(1.0, "Copied to clipboard")
        return cleaned
    }

    private func ensurePipeline(
        variant: String,
        onStatus: @escaping @Sendable (ModelEngineStatus) -> Void
    ) async throws -> WhisperKit {
        if let existing = whisperKit, loadedVariant == variant {
            onStatus(.ready(variant: variant))
            return existing
        }

        if let existingTask = prepareTask, preparingVariant == variant {
            try await existingTask.value
            if let readyKit = whisperKit, loadedVariant == variant {
                return readyKit
            }
            throw WhisperEngineError.modelLoadFailed("Model failed to initialize.")
        }

        // Switching models: unload previous model first to free memory.
        if let previous = whisperKit, loadedVariant != variant {
            await previous.unloadModels()
            whisperKit = nil
            loadedVariant = nil
        }

        let baseURL = modelsBaseURL
        let task = Task<Void, Error> {
            do {
                try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

                let modelFolder: URL
                if let cached = Self.findCachedModelFolder(baseURL: baseURL, variant: variant) {
                    modelFolder = cached
                } else {
                    onStatus(.downloading(variant: variant, progress: 0))
                    modelFolder = try await WhisperKit.download(
                        variant: variant,
                        downloadBase: baseURL,
                        progressCallback: { progress in
                            onStatus(.downloading(variant: variant, progress: progress.fractionCompleted))
                        }
                    )
                }

                onStatus(.loading(variant: variant))

                let config = WhisperKitConfig(
                    modelFolder: modelFolder.path,
                    verbose: false,
                    logLevel: .error,
                    prewarm: false,
                    load: true,
                    download: false
                )

                let kit = try await WhisperKit(config)
                self.whisperKit = kit
                self.loadedVariant = variant
                onStatus(.ready(variant: variant))
            } catch {
                onStatus(.failed(error.localizedDescription))
                throw WhisperEngineError.modelLoadFailed(error.localizedDescription)
            }
        }

        prepareTask = task
        preparingVariant = variant

        do {
            try await task.value
            prepareTask = nil
            preparingVariant = nil
            guard let kit = whisperKit else {
                throw WhisperEngineError.modelLoadFailed("Model failed to initialize.")
            }
            return kit
        } catch {
            prepareTask = nil
            preparingVariant = nil
            throw error
        }
    }

    private static func findCachedModelFolder(baseURL: URL, variant: String) -> URL? {
        let fm = FileManager.default
        let hubModelsRoot = baseURL
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("argmaxinc", isDirectory: true)
            .appendingPathComponent("whisperkit-coreml", isDirectory: true)

        guard let entries = try? fm.contentsOfDirectory(
            at: hubModelsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for entry in entries {
            let name = entry.lastPathComponent
            if name == variant || name == "openai_whisper-\(variant)" || name.hasSuffix(variant) {
                let melPath = entry.appendingPathComponent("MelSpectrogram.mlmodelc").path
                let encoderPath = entry.appendingPathComponent("AudioEncoder.mlmodelc").path
                let decoderPath = entry.appendingPathComponent("TextDecoder.mlmodelc").path
                if fm.fileExists(atPath: melPath)
                    && fm.fileExists(atPath: encoderPath)
                    && fm.fileExists(atPath: decoderPath)
                {
                    return entry
                }
            }
        }

        return nil
    }
}
