import AppKit
import SwiftUI
import XCTest
@testable import AIVoiceManagerApp

/// `Text(symbols:)` draws `{sf.name}` tokens in translated strings as SF Symbols (no emoji in the UI).
final class SymbolTextTests: XCTestCase {
    func testTokensSplitIntoTextAndSymbol() {
        let runs = Text.symbolRuns("Drag · {speaker.slash} mutes a scene")
        XCTAssertEqual(runs.map(\.text), ["Drag · ", " mutes a scene"])
        XCTAssertEqual(runs.map(\.symbol), ["speaker.slash", nil])
        XCTAssertEqual(Text.symbolRuns("no icon { here").map(\.text), ["no icon { here"])
    }

    /// A typo in a token would draw nothing: every token in en + th must be a real SF Symbol on macOS 14.
    func testEveryTokenInTheStringsIsAnSFSymbol() throws {
        for lang in ["en", "th"] {
            let url = try XCTUnwrap(Bundle.module.url(forResource: "Localizable", withExtension: "strings",
                                                      subdirectory: "\(lang).lproj"))
            let table = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
            for (key, value) in table {
                for symbol in Text.symbolRuns(value).compactMap(\.symbol) {
                    XCTAssertNotNil(NSImage(systemSymbolName: symbol, accessibilityDescription: nil), "\(lang) \(key)")
                }
            }
        }
    }
}
