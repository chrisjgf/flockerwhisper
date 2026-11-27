import FlockerwhisperCore
import XCTest

@MainActor
final class TranscriptStoreTests: XCTestCase {
    private var tempDir: URL!
    private var historyURL: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlockerwhisperStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        historyURL = tempDir.appendingPathComponent("history.json")
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    func testAddPersistsAndOrdersNewestFirst() {
        let store = TranscriptStore(storageURL: historyURL, maxItems: 10)
        store.add(text: "First note", durationSeconds: 2.1, modelVariant: "large-v3-v20240930_turbo")
        store.add(text: "Second note", durationSeconds: 3.4, modelVariant: "large-v3-v20240930_turbo")

        XCTAssertEqual(store.items.map(\.text), ["Second note", "First note"])

        // Reload from disk
        let reloaded = TranscriptStore(storageURL: historyURL, maxItems: 10)
        XCTAssertEqual(reloaded.items.map(\.text), ["Second note", "First note"])
    }

    func testIgnoresBlankOrNoiseOnlyTranscripts() {
        let store = TranscriptStore(storageURL: historyURL)
        XCTAssertNil(store.add(text: "   [BLANK_AUDIO]  ", durationSeconds: 1.0, modelVariant: "small.en"))
        XCTAssertTrue(store.items.isEmpty)
    }

    func testCapsHistoryToMaxItems() {
        let store = TranscriptStore(storageURL: historyURL, maxItems: 3)
        for i in 1...5 {
            store.add(text: "Item \(i)", durationSeconds: 1.0, modelVariant: "small.en")
        }
        XCTAssertEqual(store.items.map(\.text), ["Item 5", "Item 4", "Item 3"])
    }

    func testSearchDeleteAndClear() {
        let store = TranscriptStore(storageURL: historyURL)
        let first = store.add(text: "Buy coffee beans", durationSeconds: 1.2, modelVariant: "small.en")
        _ = store.add(text: "Deploy staging server", durationSeconds: 2.5, modelVariant: "small.en")

        XCTAssertEqual(store.filtered(query: "coffee").map(\.text), ["Buy coffee beans"])
        XCTAssertEqual(store.filtered(query: "  ").count, 2)

        if let id = first?.id {
            store.delete(id: id)
        }
        XCTAssertEqual(store.items.map(\.text), ["Deploy staging server"])

        store.clearAll()
        XCTAssertTrue(store.items.isEmpty)
    }
}
