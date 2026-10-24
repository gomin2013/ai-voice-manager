import SwiftUI
import XCTest
@testable import AIVoiceManagerApp

/// Every language ships every English key with the same `String(format:)` placeholders and `{sf.name}` icons — a
/// wrong or missing `%@` crashes or garbles the UI. Same check as hosts-manager's TranslationTests.
@MainActor
final class TranslationTests: XCTestCase {
    private static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources/AIVoiceManagerApp/Resources")

    private func strings(_ code: String) throws -> [String: String] {
        let url = Self.resources.appendingPathComponent("\(code).lproj/Localizable.strings")
        let dict = NSDictionary(contentsOf: url) as? [String: String]
        return try XCTUnwrap(dict, "\(code) strings missing or unreadable")
    }

    /// `%@`, `%ld`, `%1$@`… and `{speaker.slash}`-style icon tokens; `%%` is a literal percent, not a placeholder.
    private func placeholders(_ text: String) -> [String] {
        let formats = text.replacing("%%", with: "").matches(of: /%(?:\d+\$)?(?:@|l?l?[dDuUxXfFeEgGcs])/)
        return (formats.map { String($0.output) } + Text.symbolRuns(text).compactMap(\.symbol)).sorted()
    }

    func testEveryLanguageHasEveryKeyWithTheSamePlaceholders() throws {
        let english = try strings("en")
        for language in LanguageService.Language.allCases where language != .english {
            let translated = try strings(language.rawValue)
            let code = language.rawValue
            XCTAssertEqual(Set(english.keys).subtracting(translated.keys).sorted(), [], "missing in \(code)")
            XCTAssertEqual(Set(translated.keys).subtracting(english.keys).sorted(), [], "extra in \(code)")
            for (key, value) in english {
                guard let other = translated[key] else { continue }
                XCTAssertEqual(placeholders(other), placeholders(value), "\(code) \(key)")
                XCTAssertFalse(other.trimmingCharacters(in: .whitespaces).isEmpty, "\(code) \(key) empty")
            }
        }
    }
}
