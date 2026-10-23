import XCTest
@testable import AIVoiceManagerApp

final class CatalogTests: XCTestCase {
    private let images = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".prototype/img")

    func testThirtyVoicesFourteenFemale() {
        XCTAssertEqual(VoiceCatalog.all.count, 30)
        XCTAssertEqual(VoiceCatalog.all.filter { $0.gender == .female }.count, 14)
        XCTAssertEqual(VoiceCatalog.all.first?.name, "Zephyr")
        XCTAssertEqual(VoiceCatalog.all.last?.description, "Warm")
    }

    /// Names → the prototype's image files, so the same art loads in the app (Phase 2 › 5 Assets).
    func testEveryNameHasItsPrototypeImage() {
        for voice in VoiceCatalog.all {
            let file = images.appendingPathComponent("voices/\(voice.name.lowercased()).png").path
            XCTAssertTrue(FileManager.default.fileExists(atPath: file), file)
        }
        for tag in ExpressionTag.allCases {
            let file = images.appendingPathComponent("expressions/\(tag.key).png").path
            XCTAssertTrue(FileManager.default.fileExists(atPath: file), file)
        }
        for style in StylePreset.all {
            let file = images.appendingPathComponent("styles/\(style.slug).png").path
            XCTAssertTrue(FileManager.default.fileExists(atPath: file), file)
        }
    }

    func testCurrencyFollowsLanguage() {
        XCTAssertEqual(CurrencyRates.currency(forLanguage: "th"), "THB")
        XCTAssertEqual(CurrencyRates.currency(forLanguage: "zh-Hant"), "TWD")
        XCTAssertEqual(CurrencyRates.currency(forLanguage: "fr"), "USD")
    }
}
