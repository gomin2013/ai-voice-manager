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
    static func format(_ value: Double, currency: String, language: String) -> String {
        let clash = CurrencyRates.perUSD.keys.contains {
            $0 != currency && narrowSymbol($0, language) == narrowSymbol(currency, language)
        }
        let style = style(currency, language, clash ? .standard : .narrow)
        return value.formatted(style.precision(.significantDigits(1...3)))
    }

    private static func style(_ code: String, _ language: String,
                              _ presentation: CurrencyFormatStyleConfiguration.Presentation)
        -> FloatingPointFormatStyle<Double>.Currency {
        .currency(code: code).presentation(presentation).locale(Locale(identifier: language))
    }

    private static func narrowSymbol(_ code: String, _ language: String) -> String {
        0.0.formatted(style(code, language, .narrow))
            .filter { !$0.isNumber && $0 != "." && $0 != "," && !$0.isWhitespace }
    }
}
