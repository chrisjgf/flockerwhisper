import Foundation

public enum OverlayPhase: Equatable, Sendable {
    case hidden
    case recording(startedAt: Date)
    case downloadingModel(progress: Double, statusText: String)
    case transcribing(progress: Double, statusText: String)
    case copied(preview: String)
    case error(message: String, showMicrophoneSettings: Bool)

    public var isVisible: Bool {
        if case .hidden = self { return false }
        return true
    }

    public var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    public var isProcessing: Bool {
        switch self {
        case .downloadingModel, .transcribing:
            return true
        default:
            return false
        }
    }
}

public enum ModelEngineStatus: Equatable, Sendable {
    case idle
    case downloading(variant: String, progress: Double)
    case loading(variant: String)
    case ready(variant: String)
    case failed(String)

    public var shortLabel: String {
        switch self {
        case .idle:
            return "Not loaded"
        case .downloading(_, let progress):
            return "Downloading \(Int((progress * 100).rounded()))%"
        case .loading:
            return "Loading model…"
        case .ready(let variant):
            if let option = WhisperModelOption(rawValue: variant) {
                return "\(option.displayName) ready"
            }
            return "Ready"
        case .failed:
            return "Model error"
        }
    }
}
