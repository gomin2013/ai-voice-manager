import XCTest
@testable import AIVoiceManagerApp

/// Each language reads its own strings, never `Bundle.main` (which macOS resolves by the system's language list:
/// Japanese on a Thai Mac stayed Thai in v1.0.1).
@MainActor
final class LanguageServiceTests: XCTestCase {
    func testEveryLanguageReadsItsOwnStrings() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "LanguageServiceTests"))
        defer { defaults.removePersistentDomain(forName: "LanguageServiceTests") }
        let service = LanguageService(defaults: defaults)

        for language in LanguageService.Language.allCases {
            service.current = language
            XCTAssertTrue(service.bundle.bundlePath.hasSuffix("/\(language.rawValue).lproj"), service.bundle.bundlePath)
        }
        service.current = .thai
        let thai = service.localized("fav")
        service.current = .japanese
        XCTAssertNotEqual(service.localized("fav"), thai)
    }
}
