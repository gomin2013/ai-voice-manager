import XCTest
@testable import AIVoiceManagerApp

final class WAVTests: XCTestCase {
    /// A RIFF/WAVE file like Gemini's: 24 kHz mono 16-bit (byte rate 48 000), optional extra chunk before `data`.
    static func wav(seconds: Double, extraChunk: Bool = false, dataSize: UInt32? = nil) -> Data {
        func le32(_ value: UInt32) -> [UInt8] { withUnsafeBytes(of: value.littleEndian, Array.init) }
        func le16(_ value: UInt16) -> [UInt8] { withUnsafeBytes(of: value.littleEndian, Array.init) }
        let samples = [UInt8](repeating: 0, count: Int(48_000 * seconds))
        var bytes = Array("WAVE".utf8) + Array("fmt ".utf8) + le32(16) + le16(1) + le16(1) + le32(24_000)
            + le32(48_000) + le16(2) + le16(16)
        if extraChunk { bytes += Array("LIST".utf8) + le32(3) + [1, 2, 3, 0] }   // odd size → padded
        bytes += Array("data".utf8) + le32(dataSize ?? UInt32(samples.count)) + samples
        return Data(Array("RIFF".utf8) + le32(UInt32(bytes.count)) + bytes)
    }

    func testDurationComesFromTheHeader() throws {
        XCTAssertEqual(try XCTUnwrap(wavDuration(Self.wav(seconds: 1.5))), 1.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(wavDuration(Self.wav(seconds: 2, extraChunk: true))), 2, accuracy: 0.0001)
    }

    func testUnknownLengthUsesTheBytesThatAreThere() throws {
        XCTAssertEqual(try XCTUnwrap(wavDuration(Self.wav(seconds: 1, dataSize: 0xFFFF_FFFF))), 1, accuracy: 0.0001)
    }

    /// 24 kHz mono 16-bit with these samples.
    static func wav(samples: [Int16]) -> Data {
        func le32(_ value: UInt32) -> [UInt8] { withUnsafeBytes(of: value.littleEndian, Array.init) }
        func le16(_ value: UInt16) -> [UInt8] { withUnsafeBytes(of: value.littleEndian, Array.init) }
        let pcm = samples.flatMap { le16(UInt16(bitPattern: $0)) }
        let bytes = Array("WAVE".utf8) + Array("fmt ".utf8) + le32(16) + le16(1) + le16(1) + le32(24_000)
            + le32(48_000) + le16(2) + le16(16) + Array("data".utf8) + le32(UInt32(pcm.count)) + pcm
        return Data(Array("RIFF".utf8) + le32(UInt32(bytes.count)) + bytes)
    }

    func testBarsFollowTheLoudness() throws {
        // first half silent, second half a ±1000 / ±8000 square wave: quiet stubs, then a quarter, then full bars
        let quiet = [Int16](repeating: 0, count: 600), soft = (0..<300).map { $0 % 2 == 0 ? Int16(1000) : -1000 }
        let loud = (0..<300).map { $0 % 2 == 0 ? Int16(8000) : -8000 }
        let bars = try XCTUnwrap(waveHeights(Self.wav(samples: quiet + soft + loud), bars: 4))
        XCTAssertEqual(bars[0], 0.2, accuracy: 0.001)
        XCTAssertEqual(bars[1], 0.2, accuracy: 0.001)
        XCTAssertEqual(bars[2], 0.2 + 0.8 / 8, accuracy: 0.001)
        XCTAssertEqual(bars[3], 1, accuracy: 0.001)
        XCTAssertNil(waveHeights(Self.wav(samples: [1, 2]), bars: 60))   // shorter than the bars: seeded instead
    }

    func testNotAWavIsNil() {
        XCTAssertNil(wavDuration(Data("RIFF".utf8)))
        XCTAssertNil(wavDuration(Data(#"{"steps":[]}"#.utf8)))
    }
}
