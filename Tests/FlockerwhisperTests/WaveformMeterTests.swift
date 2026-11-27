import FlockerwhisperCore
import XCTest

final class WaveformMeterTests: XCTestCase {
    func testSilenceStaysAtZero() {
        let silentSamples = Array(repeating: Float(0), count: 512)
        XCTAssertEqual(WaveformMeter.normalizedLevel(from: silentSamples), 0)
    }

    func testLouderSignalProducesHigherNormalizedLevel() {
        let quiet = (0..<512).map { Float(sin(Double($0) * 0.1)) * 0.015 }
        let loud = (0..<512).map { Float(sin(Double($0) * 0.1)) * 0.25 }

        let quietLevel = WaveformMeter.normalizedLevel(from: quiet)
        let loudLevel = WaveformMeter.normalizedLevel(from: loud)

        XCTAssertGreaterThan(quietLevel, 0)
        XCTAssertGreaterThan(loudLevel, quietLevel)
        XCTAssertLessThanOrEqual(loudLevel, 1.0)
    }

    func testMeterMaintainsBarCountAndShiftsLeft() {
        var meter = WaveformMeter(barCount: 12)
        _ = meter.push(level: 0.4)
        let updated = meter.push(level: 0.8)

        XCTAssertEqual(updated.count, 12)
        XCTAssertEqual(updated[10], 0.4, accuracy: 0.0001)
        XCTAssertEqual(updated[11], 0.8, accuracy: 0.0001)
    }
}
