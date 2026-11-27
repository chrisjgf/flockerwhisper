import Foundation

public struct TranscriptItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let createdAt: Date
    public let durationSeconds: Double
    public let modelVariant: String

    public init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date(),
        durationSeconds: Double,
        modelVariant: String
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.durationSeconds = durationSeconds
        self.modelVariant = modelVariant
    }
}
