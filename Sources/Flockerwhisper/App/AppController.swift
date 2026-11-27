import AppKit
import FlockerwhisperCore
import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppController {
    private static let selectedModelDefaultsKey = "Flockerwhisper.selectedModelVariant"

    let transcriptStore: TranscriptStore
    private let audioService: AudioCaptureService
    private let whisperEngine: WhisperEngine
    private let hotKeyManager: GlobalHotKeyManager
    private let panelController: OverlayPanelController

    var phase: OverlayPhase = .hidden
    var modelStatus: ModelEngineStatus = .idle
    var waveformLevels: [Float] = Array(repeating: 0, count: 64)
    var isCompactHUD = false
    var selectedModel: WhisperModelOption
    var launchAtLogin: Bool = false

    private var transcriptionTask: Task<Void, Never>?
    private var progressAnimationTask: Task<Void, Never>?
    private var dismissTask: Task<Void, Never>?
    private var preloadTask: Task<Void, Never>?

    init(
        transcriptStore: TranscriptStore? = nil,
        audioService: AudioCaptureService = AudioCaptureService(barCount: 64),
        whisperEngine: WhisperEngine = WhisperEngine(),
        hotKeyManager: GlobalHotKeyManager? = nil,
        panelController: OverlayPanelController? = nil
    ) {
        self.transcriptStore = transcriptStore ?? TranscriptStore()
        self.audioService = audioService
        self.whisperEngine = whisperEngine
        self.hotKeyManager = hotKeyManager ?? GlobalHotKeyManager()
        self.panelController = panelController ?? OverlayPanelController()

        if let saved = UserDefaults.standard.string(forKey: Self.selectedModelDefaultsKey),
           let option = WhisperModelOption(rawValue: saved)
        {
            self.selectedModel = option
        } else {
            self.selectedModel = .defaultOption
        }

        self.launchAtLogin = SMAppService.mainApp.status == .enabled

        setupHotKeys()
        preloadSelectedModel()
    }

    var menuBarIconName: String {
        switch phase {
        case .recording:
            return "mic.fill"
        case .downloadingModel, .transcribing:
            return "waveform.badge.magnifyingglass"
        default:
            return "waveform"
        }
    }

    func toggleCompactHUD() {
        isCompactHUD.toggle()
        DispatchQueue.main.async { [weak self] in
            self?.panelController.updateLayout()
        }
    }

    func selectModel(_ option: WhisperModelOption) {
        guard option != selectedModel else { return }
        selectedModel = option
        UserDefaults.standard.set(option.rawValue, forKey: Self.selectedModelDefaultsKey)
        preloadSelectedModel()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    func toggleFromHotKey() {
        switch phase {
        case .hidden, .copied, .error:
            startRecordingFlow()
        case .recording:
            stopAndTranscribe()
        case .downloadingModel, .transcribing:
            // Already processing the utterance; ignore repeated Option+Space until done or cancelled.
            break
        }
    }

    func startRecordingFlow() {
        dismissTask?.cancel()
        dismissTask = nil
        transcriptionTask?.cancel()
        transcriptionTask = nil
        progressAnimationTask?.cancel()
        progressAnimationTask = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            let granted = await AudioCaptureService.requestPermission()
            guard granted else {
                self.showHUD(phase: .error(
                    message: AudioCaptureError.permissionDenied.localizedDescription,
                    showMicrophoneSettings: true
                ))
                return
            }

            self.waveformLevels = Array(repeating: 0, count: 64)
            self.showHUD(phase: .recording(startedAt: Date()))

            do {
                try self.audioService.startRecording { [weak self] levels in
                    Task { @MainActor [weak self] in
                        guard let self, self.phase.isRecording else { return }
                        self.waveformLevels = levels
                    }
                }
            } catch {
                self.showHUD(phase: .error(
                    message: error.localizedDescription,
                    showMicrophoneSettings: false
                ))
            }
        }
    }

    func stopAndTranscribe() {
        guard case .recording = phase else { return }

        let (samples, duration) = audioService.stopRecording()
        waveformLevels = Array(repeating: 0, count: 64)

        guard samples.count > 1600 else {
            hideHUD()
            return
        }

        let variant = selectedModel.rawValue
        showHUD(phase: .transcribing(progress: 0.08, statusText: "Analysing audio…"))
        startSmoothProgressTicker()

        transcriptionTask?.cancel()
        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await self.whisperEngine.transcribe(
                    samples: samples,
                    variant: variant,
                    onStatus: { [weak self] status in
                        Task { @MainActor [weak self] in
                            self?.modelStatus = status
                        }
                    },
                    onProgress: { [weak self] progress, statusText in
                        Task { @MainActor [weak self] in
                            guard let self, self.phase.isProcessing else { return }
                            let current = self.currentProcessingProgress
                            let next = max(current, progress)
                            if case .downloading = self.modelStatus {
                                self.phase = .downloadingModel(progress: next, statusText: statusText)
                            } else {
                                self.phase = .transcribing(progress: next, statusText: statusText)
                            }
                        }
                    }
                )

                self.progressAnimationTask?.cancel()
                self.progressAnimationTask = nil

                guard !Task.isCancelled else { return }

                if text.isEmpty {
                    self.hideHUD()
                    return
                }

                self.transcriptStore.copyToClipboard(text)
                self.transcriptStore.add(
                    text: text,
                    durationSeconds: duration,
                    modelVariant: variant
                )

                self.phase = .copied(preview: text)
                self.dismissTask?.cancel()
                self.dismissTask = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(550))
                    guard !Task.isCancelled else { return }
                    self?.hideHUD()
                }
            } catch WhisperEngineError.cancelled {
                self.progressAnimationTask?.cancel()
                self.hideHUD()
            } catch WhisperEngineError.emptyAudio {
                self.progressAnimationTask?.cancel()
                self.hideHUD()
            } catch {
                self.progressAnimationTask?.cancel()
                guard !Task.isCancelled else { return }
                self.showHUD(phase: .error(
                    message: error.localizedDescription,
                    showMicrophoneSettings: false
                ))
            }
        }
    }

    func cancelCurrentSession() {
        dismissTask?.cancel()
        dismissTask = nil
        progressAnimationTask?.cancel()
        progressAnimationTask = nil
        transcriptionTask?.cancel()
        transcriptionTask = nil
        audioService.cancelRecording()
        waveformLevels = Array(repeating: 0, count: 64)
        hideHUD()
    }

    func openMicrophonePrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private Helpers

    private var currentProcessingProgress: Double {
        switch phase {
        case .downloadingModel(let p, _), .transcribing(let p, _):
            return p
        default:
            return 0
        }
    }

    private func setupHotKeys() {
        hotKeyManager.onToggle = { [weak self] in
            self?.toggleFromHotKey()
        }
        hotKeyManager.onCancel = { [weak self] in
            self?.cancelCurrentSession()
        }
        _ = hotKeyManager.registerToggleHotKey()
    }

    private func preloadSelectedModel() {
        let variant = selectedModel.rawValue
        preloadTask?.cancel()
        preloadTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.whisperEngine.preload(variant: variant) { [weak self] status in
                    Task { @MainActor [weak self] in
                        self?.modelStatus = status
                    }
                }
            } catch {
                // Error status already reflected via onStatus callback.
            }
        }
    }

    private func startSmoothProgressTicker() {
        progressAnimationTask?.cancel()
        progressAnimationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(90))
                guard let self, !Task.isCancelled else { return }
                switch self.phase {
                case .transcribing(let progress, let status):
                    if progress < 0.88 {
                        let step = max(0.015, (0.88 - progress) * 0.14)
                        self.phase = .transcribing(progress: min(0.88, progress + step), statusText: status)
                    }
                default:
                    break
                }
            }
        }
    }

    private func showHUD(phase: OverlayPhase) {
        self.phase = phase
        hotKeyManager.setEscapeHotKeyEnabled(true)
        panelController.show {
            OverlayHUDView(controller: self)
        }
    }

    private func hideHUD() {
        phase = .hidden
        hotKeyManager.setEscapeHotKeyEnabled(false)
        panelController.hide()
    }
}
