import AppKit
import SwiftUI

/// Light / Dark / follow macOS. Applied by `ContentView` (always on screen) via `NSApp.appearance`.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

// Bottom of the tool-window rail (same as git-exclude-manager's SettingsPanels.swift): Appearance, Language and About
// are panels, so the window needs no toolbar buttons.

/// Appearance panel: Light / Dark / System, solid accents (shared `AccentPicker`) and gradient themes, in that
/// order; a theme also sets its paired accent. Reads the same @AppStorage keys as ContentView.
struct AppearancePanel: View {
    @AppStorage("ui.accent") private var accent = AccentChoice.system
    @AppStorage("ui.gradient") private var theme = GradientTheme.none
    @AppStorage("app.appearance") private var appearance = Appearance.system

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(localized("settings.appearance")).font(.app(13, .semibold))
                    Picker(localized("settings.appearance"), selection: $appearance) {
                        ForEach(Appearance.allCases) { option in
                            Label(localized("appearance.\(option.rawValue)"), systemImage: option.symbol).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .padding(16)
                Divider()
                AccentPicker(choice: $accent)
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text(localized("theme.gradient")).font(.app(13, .semibold))
                    let themes = Array(GradientTheme.allCases.dropFirst())
                    Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                        ForEach([0, 4], id: \.self) { start in
                            GridRow { ForEach(themes[start..<start + 4]) { swatch($0) } }
                        }
                    }
                    Button(localized("theme.noGradient")) { theme = .none }.disabled(theme == .none)
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func swatch(_ option: GradientTheme) -> some View {
        Button {
            theme = option
            accent = option.accent
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: option.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 56, height: 36)
                .overlay {
                    if option == theme { RoundedRectangle(cornerRadius: 8).strokeBorder(.primary, lineWidth: 2) }
                }
        }
        .buttonStyle(.plain)
        .help(option.name)
        .accessibilityLabel(option.name)
        .accessibilityAddTraits(option == theme ? .isSelected : [])
    }
}

/// AVM: the Language panel has a Currency tab (Language | Currency, like Voice Library's Voices | Styles).
struct LanguagePanel: View {
    @State private var tab = Tab.language

    private enum Tab: String, CaseIterable { case language = "tabLang", currency = "tabCurrency" }

    var body: some View {
        VStack(spacing: 0) {
            Picker(localized("panel.language"), selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text(localized($0.rawValue)).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding([.horizontal, .top], 16)
            if tab == .language { LanguageList() } else { CurrencyList() }
        }
    }
}

/// Language list: search by native, English or translated name (or code), then click to switch — no restart.
private struct LanguageList: View {
    @State private var query = ""

    var body: some View {
        @Bindable var language = LanguageService.shared
        let current = language.current
        let matches = LanguageService.Language.allCases.filter { $0.matches(query, uiLanguage: current) }
        VStack(alignment: .leading, spacing: 0) {
            TextField(localized("language.search"), text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(16)
            if matches.isEmpty {
                Text(localized("language.noResults", query))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                Spacer()
            } else {
                List(matches) { option in
                    LanguageRow(option: option, uiLanguage: current)
                        .onTapGesture { language.current = option }
                        .accessibilityAction { language.current = option }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

/// One language: flag, its own name, and its name in the current UI language ("ญี่ปุ่น" under 日本語 when in Thai).
private struct LanguageRow: View {
    let option: LanguageService.Language
    let uiLanguage: LanguageService.Language

    var body: some View {
        let isCurrent = option == uiLanguage
        let translated = option.name(in: uiLanguage)
        HStack(spacing: 10) {
            Text(option.flag).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(option.nativeName).fontWeight(isCurrent ? .semibold : .regular)
                if translated != option.nativeName {
                    Text(translated).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            if isCurrent { Image(systemName: "checkmark").foregroundStyle(.tint).accessibilityHidden(true) }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }
}

/// Currency for the ≈ local amount next to USD prices: "Match language" (default) or one of the family's 12.
private struct CurrencyList: View {
    @AppStorage("app.currency") private var saved = "auto"

    var body: some View {
        let language = LanguageService.shared.current.rawValue
        let matched = CurrencyRates.currency(forLanguage: language)
        List {
            row("auto", title: localized("curAuto"), flag: "🌐", detail: rate(matched, language))
            ForEach(LanguageService.Language.allCases) { option in
                let code = CurrencyRates.currency(forLanguage: option.rawValue)
                row(code, title: Locale(identifier: language).localizedString(forCurrencyCode: code) ?? code,
                    flag: option.flag, detail: rate(code, language))
            }
            Text(localized("curNote", CurrencyRates.date))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    private func rate(_ code: String, _ language: String) -> String {
        guard code != "USD", let perUSD = CurrencyRates.perUSD[code] else { return "USD" }
        return "\(code) · 1 US$ ≈ \(Money.format(perUSD, currency: code, language: language))"
    }

    private func row(_ code: String, title: String, flag: String, detail: String) -> some View {
        let isCurrent = code == saved
        return HStack(spacing: 10) {
            Text(flag).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).fontWeight(isCurrent ? .semibold : .regular)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if isCurrent { Image(systemName: "checkmark").foregroundStyle(.tint).accessibilityHidden(true) }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { saved = code }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { saved = code }
    }
}

/// About panel.
struct AboutPanel: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)
                Text(localized("app.title")).font(.title2.bold())
                Text(localized("about.version", version))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(localized("about.desc"))
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("about.family").uppercased())
                        .font(.app(11, .semibold)).foregroundStyle(.secondary)
                    ForEach(Self.family, id: \.slug) { app in
                        Link(destination: URL(string: "https://gomin2013.github.io/\(app.slug)/")!) {
                            HStack {
                                Text(app.name).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Link(destination: URL(string: "https://github.com/sponsors/gomin2013")!) {
                    Label(localized("about.support"), systemImage: "heart.fill")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    /// The other released Gomin apps (prototype shell.js `FAMILY`); each opens its page on gomin2013.github.io.
    /// SSH Config / Git Identity Manager join when they ship.
    private static let family = [("Hosts Manager", "hosts-manager"), ("Git Exclude Manager", "git-exclude-manager")]
        .map { (name: $0.0, slug: $0.1) }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
