import AppKit
import Foundation
import Observation

@MainActor
@Observable
public final class TranscriptStore {
    public private(set) var items: [TranscriptItem] = []

    private let storageURL: URL
    private let maxItems: Int
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(storageURL: URL? = nil, maxItems: Int = 200) {
        self.storageURL = storageURL ?? Self.defaultStorageURL()
        self.maxItems = max(1, maxItems)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        load()
    }

    public static func defaultStorageURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return appSupport
            .appendingPathComponent("Flockerwhisper", isDirectory: true)
            .appendingPathComponent("history.json")
    }

    @discardableResult
    public func add(text: String, durationSeconds: Double, modelVariant: String) -> TranscriptItem? {
        let cleaned = TranscriptTextCleaner.clean(text)
        guard !cleaned.isEmpty else { return nil }

        let item = TranscriptItem(
            text: cleaned,
            createdAt: Date(),
            durationSeconds: max(0, durationSeconds),
            modelVariant: modelVariant
        )
        items.insert(item, at: 0)
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        save()
        return item
    }

    public func delete(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    public func clearAll() {
        items.removeAll()
        save()
    }

    public func filtered(query: String) -> [TranscriptItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { $0.text.localizedCaseInsensitiveContains(trimmed) }
    }

    public func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            items = []
            return
        }
        do {
            let data = try Data(contentsOf: storageURL)
            items = try decoder.decode([TranscriptItem].self, from: data)
        } catch {
            items = []
        }
    }

    private func save() {
        do {
            let dir = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try encoder.encode(items)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            // Keep running even if disk write fails.
        }
    }
}
