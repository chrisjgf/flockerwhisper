import AVFoundation
import Foundation

public struct WaveformMeter: Sendable {
    public let barCount: Int
    private var levels: [Float]

    public init(barCount: Int = 64) {
        self.barCount = max(8, barCount)
        self.levels = Array(repeating: 0, count: max(8, barCount))
    }

    public var currentLevels: [Float] {
        levels
    }

    public mutating func reset() {
        levels = Array(repeating: 0, count: barCount)
    }

    /// Computes a normalized [0, 1] loudness value from PCM Float32 samples and pushes it into the rolling bar buffer.
    public mutating func ingest(samples: [Float]) -> [Float] {
        let level = Self.normalizedLevel(from: samples)
        return push(level: level)
    }

    public mutating func push(level: Float) -> [Float] {
        let clamped = max(0, min(1, level))
        // Shift left and append newest level at the right so speech flows smoothly across the dot array.
        if !levels.isEmpty {
            levels.removeFirst()
            levels.append(clamped)
        }
        return levels
    }

    public static func normalizedLevel(from samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sumSquares: Float = 0
        for sample in samples {
            sumSquares += sample * sample
        }
        let rms = sqrt(sumSquares / Float(samples.count))
        guard rms > 0.0001 else { return 0 }

        // Map roughly -52 dB ... -10 dB into 0 ... 1 with a gentle curve so normal speech looks lively
        // while room-tone silence stays cleanly at 0 (flat dots).
        let db = 20 * log10(rms)
        let minDb: Float = -50
        let maxDb: Float = -10
        let linear = (db - minDb) / (maxDb - minDb)
        let clamped = max(0, min(1, linear))
        return pow(clamped, 1.25)
    }
}

public enum AudioCaptureError: LocalizedError, Sendable {
    case permissionDenied
    case audioFormatUnavailable
    case converterCreationFailed
    case engineStartFailed(String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access is required. Enable Flockerwhisper in System Settings → Privacy & Security → Microphone."
        case .audioFormatUnavailable:
            return "No active microphone input device was found."
        case .converterCreationFailed:
            return "Could not initialize 16 kHz audio converter."
        case .engineStartFailed(let reason):
            return "Could not start microphone recording: \(reason)"
        }
    }
}

public final class AudioCaptureService: @unchecked Sendable {
    public static let targetSampleRate: Double = 16_000

    private let lock = NSLock()
    private var engine: AVAudioEngine?
    private var capturedSamples: [Float] = []
    private var meter: WaveformMeter
    private var recordingStartedAt: Date?
    private var isCapturing = false

    public init(barCount: Int = 64) {
        self.meter = WaveformMeter(barCount: barCount)
    }

    public static func authorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    public static func requestPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    public func startRecording(
        onLevels: @escaping @Sendable ([Float]) -> Void
    ) throws {
        stopEngineOnly()

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw AudioCaptureError.audioFormatUnavailable
        }

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioCaptureError.audioFormatUnavailable
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioCaptureError.converterCreationFailed
        }

        lock.lock()
        capturedSamples.removeAll(keepingCapacity: true)
        capturedSamples.reserveCapacity(Int(Self.targetSampleRate) * 30)
        meter.reset()
        recordingStartedAt = Date()
        isCapturing = true
        let initialLevels = meter.currentLevels
        lock.unlock()

        onLevels(initialLevels)

        // ~35 ms tap buffer for snappy waveform updates
        let tapFrameCount = AVAudioFrameCount(max(512, Int(inputFormat.sampleRate * 0.035)))

        inputNode.installTap(onBus: 0, bufferSize: tapFrameCount, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }

            let converted = Self.convertToMono16k(buffer: buffer, converter: converter, targetFormat: targetFormat)
            guard !converted.isEmpty else { return }

            let updatedLevels: [Float]
            self.lock.lock()
            guard self.isCapturing else {
                self.lock.unlock()
                return
            }
            self.capturedSamples.append(contentsOf: converted)
            updatedLevels = self.meter.ingest(samples: converted)
            self.lock.unlock()

            onLevels(updatedLevels)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            lock.lock()
            isCapturing = false
            lock.unlock()
            throw AudioCaptureError.engineStartFailed(error.localizedDescription)
        }

        lock.lock()
        self.engine = engine
        lock.unlock()
    }

    public func stopRecording() -> (samples: [Float], durationSeconds: Double) {
        stopEngineOnly()

        lock.lock()
        let samples = capturedSamples
        let duration: Double
        if !samples.isEmpty {
            duration = Double(samples.count) / Self.targetSampleRate
        } else if let started = recordingStartedAt {
            duration = Date().timeIntervalSince(started)
        } else {
            duration = 0
        }
        capturedSamples.removeAll(keepingCapacity: false)
        meter.reset()
        recordingStartedAt = nil
        isCapturing = false
        lock.unlock()

        return (samples, duration)
    }

    public func cancelRecording() {
        stopEngineOnly()

        lock.lock()
        capturedSamples.removeAll(keepingCapacity: false)
        meter.reset()
        recordingStartedAt = nil
        isCapturing = false
        lock.unlock()
    }

    private func stopEngineOnly() {
        lock.lock()
        let activeEngine = engine
        engine = nil
        isCapturing = false
        lock.unlock()

        if let activeEngine {
            activeEngine.inputNode.removeTap(onBus: 0)
            activeEngine.stop()
        }
    }

    private static func convertToMono16k(
        buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) -> [Float] {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio)) + 32
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return []
        }

        var error: NSError?
        var consumed = false
        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, error == nil, let channelData = outputBuffer.floatChannelData else {
            return []
        }

        let count = Int(outputBuffer.frameLength)
        guard count > 0 else { return [] }
        return Array(UnsafeBufferPointer(start: channelData[0], count: count))
    }
}
