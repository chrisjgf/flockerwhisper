import Foundation

public enum WhisperModelOption: String, CaseIterable, Identifiable, Codable, Sendable {
    case largeV3Turbo = "large-v3-v20240930_turbo"
    case largeV3TurboCompact = "large-v3-v20240930_626MB"
    case smallEnglish = "small.en"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .largeV3Turbo:
            return "Large v3 Turbo"
        case .largeV3TurboCompact:
            return "Large v3 Turbo (Compact)"
        case .smallEnglish:
            return "Small (English)"
        }
    }

    public var subtitle: String {
        switch self {
        case .largeV3Turbo:
            return "Best accuracy & speed on Apple Silicon (~1.5 GB)"
        case .largeV3TurboCompact:
            return "High accuracy, smaller download (~626 MB)"
        case .smallEnglish:
            return "Lightweight English-only model (~240 MB)"
        }
    }

    public static let defaultOption: WhisperModelOption = .largeV3Turbo
}
