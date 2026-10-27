import XCTest
@testable import AIVoiceManagerApp

/// Same results as the prototype's `fmtMoney` / `money()` in the browser (2026-10-23).
final class MoneyTests: XCTestCase {
    func testSharedSymbolsGetTheirCountryPrefix() {
        XCTAssertEqual(Money.format(32, currency: "TWD", language: "en"), "NT$32")
        XCTAssertEqual(Money.format(7.2, currency: "CNY", language: "en"), "CN¥7.2")
        XCTAssertEqual(Money.format(33, currency: "THB", language: "en"), "฿33")
    }

    /// Traditional Chinese writes TWD as a bare "$" and USD as "US$": next to a USD price that's ambiguous → NT$.
    func testBareDollarNextToUSDGetsItsPrefix() {
        XCTAssertEqual(Money.usdWithLocal(1.85, currency: "TWD", language: "zh-Hant"), "US$1.85 (NT$59.2)")
        XCTAssertEqual(Money.format(150, currency: "JPY", language: "ja"), "¥150", "own currency, no clash: as is")
        XCTAssertEqual(Money.format(4.4, currency: "MYR", language: "ja"), "RM\u{00A0}4.4", "letter symbols: no clash")
    }

    /// English shows 2026 even on a Mac set to the Buddhist calendar; Thai shows 2569 like the prototype.
    @MainActor
    func testDatesUseTheAppLanguagesCalendar() {
        let date = Date(timeIntervalSince1970: 1_792_800_000)   // 2026-10-23
        LanguageService.shared.current = .english
        XCTAssertTrue(date.inAppLanguage.contains("2026"), date.inAppLanguage)
        LanguageService.shared.current = .thai
        XCTAssertTrue(date.inAppLanguage.contains("2569"), date.inAppLanguage)
        LanguageService.shared.current = .english
    }

    func testLocalAmountFollowsUSD() {
        XCTAssertEqual(Money.usdWithLocal(0.0123, currency: "USD", language: "en"), "$0.0123")
        XCTAssertEqual(Money.usdWithLocal(0.0123, currency: "THB", language: "en"), "$0.0123 (฿0.406)")
    }
}
