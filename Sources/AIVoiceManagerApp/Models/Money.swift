import Foundation

/// Prices are USD (Google bills in USD); the local amount is a hint at `CurrencyRates` (prototype `money()`).
enum Money {
    /// `$0.0123` or `$0.0123 (฿0.406)` — 3 significant digits, so tiny per-take amounts stay readable.
    static func usdWithLocal(_ usd: Double, currency: String, language: String) -> String {
        let dollars = format(usd, currency: "USD", language: language)
        guard currency != "USD", let rate = CurrencyRates.perUSD[currency] else { return dollars }
        return "\(dollars) (\(format(usd * rate, currency: currency, language: language)))"
    }

    /// Short symbol (฿, not THB) unless another listed currency shares it ($ = USD / TWD, ¥ = JPY / CNY) → NT$, CN¥.
    /// "US$" and "$" share it too (Traditional Chinese): a still-bare standard symbol takes the English one (NT$).
    static func format(_ value: Double, currency: String, language: String) -> String {
        let mine = bare(narrowSymbol(currency, language))
        let clash = CurrencyRates.perUSD.keys.contains { $0 != currency && bare(narrowSymbol($0, language)) == mine }
        let style = style(currency, language, clash ? .standard : .narrow).precision(.significantDigits(1...3))
        let text = value.formatted(style)
        let standard = symbol(currency, language, .standard)
        guard clash, !standard.contains(where: \.isLetter) else { return text }
        return text.replacingOccurrences(of: standard, with: symbol(currency, "en", .standard))
    }

    private static func style(_ code: String, _ language: String,
                              _ presentation: CurrencyFormatStyleConfiguration.Presentation)
        -> FloatingPointFormatStyle<Double>.Currency {
        .currency(code: code).presentation(presentation).locale(Locale(identifier: language))
    }

    private static func narrowSymbol(_ code: String, _ language: String) -> String {
        symbol(code, language, .narrow)
    }

    private static func symbol(_ code: String, _ language: String,
                               _ presentation: CurrencyFormatStyleConfiguration.Presentation) -> String {
        0.0.formatted(style(code, language, presentation))
            .filter { !$0.isNumber && $0 != "." && $0 != "," && !$0.isWhitespace }
    }

    /// "US$" → "$", "CN¥" → "¥"; an all-letter symbol (RM, Rp, 元) stays itself, so it never clashes by accident.
    private static func bare(_ symbol: String) -> String {
        symbol.allSatisfy(\.isLetter) ? symbol : symbol.filter { !$0.isLetter }
    }
}
