import FlockerwhisperCore
import XCTest

final class TranscriptTextCleanerTests: XCTestCase {
    func testRemovesBlankAudioAndSilenceMarkers() {
        XCTAssertEqual(TranscriptTextCleaner.clean("[BLANK_AUDIO]"), "")
        XCTAssertEqual(TranscriptTextCleaner.clean("  (silence)  "), "")
        XCTAssertEqual(TranscriptTextCleaner.clean("[Music] Hello world [INAUDIBLE]"), "Hello world")
    }

    func testStripsSpecialTokensAndNormalizesWhitespace() {
        let raw = "  <|en|>   This   is\n\ta   test. <|endoftext|>  "
        XCTAssertEqual(TranscriptTextCleaner.clean(raw), "This is a test.")
    }
}
