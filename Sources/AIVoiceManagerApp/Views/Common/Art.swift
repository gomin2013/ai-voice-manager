import AppKit
import SwiftUI

/// Voice portraits and library icons from `Art/` (cut from the prototype's sheets — .claude/docs/design/).
/// Same folder path in SwiftPM's resource bundle (`swift run`, tests) and in the .app (`build-app.sh` copies it).
@MainActor
enum Art {
    private static let bundle: Bundle = Bundle.main.bundleURL.pathExtension == "app" ? .main : .module
    private static var cache: [String: NSImage] = [:]

    static func image(_ folder: String, _ name: String) -> NSImage? {
        let key = folder + "/" + name
        if let hit = cache[key] { return hit }
        let image = bundle.url(forResource: name, withExtension: "png", subdirectory: "Art/" + folder)
            .flatMap(NSImage.init(contentsOf:))
        cache[key] = image
        return image
    }
}

/// A voice's portrait in a circle; nothing for a name outside the catalog.
struct VoicePortrait: View {
    let voice: String
    var size: CGFloat = 32

    var body: some View {
        if let image = Art.image("Voices", voice.lowercased()) {
            Image(nsImage: image).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle())
        }
    }
}

/// The scene at a glance (prototype `voiceWithStyle`): who speaks (portrait) and how (style icon on the corner).
struct VoiceWithStyle: View {
    let voice: String
    let style: String
    var size: CGFloat = 28

    var body: some View {
        VoicePortrait(voice: voice, size: size)
            .overlay(alignment: .bottomTrailing) {
                StyleIcon(style: style, size: size / 2)
                    .background(Circle().fill(.background))
                    .offset(x: size * 0.15, y: size * 0.15)
            }
            .help("\(voice) · \(style)")
            .accessibilityElement()
            .accessibilityLabel("\(voice), \(style)")
    }
}

/// A style preset's Paper Collage disc (opaque: same in light and dark); a style the user typed gets 🎭.
struct StyleIcon: View {
    let style: String
    var size: CGFloat = 28

    var body: some View {
        if let preset = StylePreset.preset(style), let image = Art.image("Styles", preset.slug) {
            Image(nsImage: image).resizable().scaledToFit().frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "face.smiling").font(.system(size: size * 0.6)).foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

/// An expression tag's Paper Collage disc (opaque: same in light and dark).
struct ExpressionIcon: View {
    let tag: ExpressionTag
    var size: CGFloat = 28

    var body: some View {
        if let image = Art.image("Expressions", tag.key) {
            Image(nsImage: image).resizable().scaledToFit().frame(width: size, height: size).accessibilityHidden(true)
        }
    }
}

/// Small coloured label: FREE TIER / PAID / MOCK / ♀ Female / ♂ Male.
/// FREE TIER / PAID for the open project (prototype `tierPill`): paid when Billing is on or the model has no free
/// tier — the model line, the scene preview and Generate all say the same thing.
struct TierPill: View {
    @Environment(EditorViewModel.self) private var vm
    @AppStorage("gemini.tier") private var tier = "free"

    var body: some View {
        let paid = !vm.model.freeTier || tier == "paid"
        Pill(text: localized(paid ? "bPaid" : "bTier"), color: paid ? .orange : .accentColor)
    }
}

struct Pill: View {
    let text: String
    var color: Color = .accentColor

    var body: some View {
        Text(text)
            .font(.app(10, .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
    }
}

/// Drag payloads between the libraries and the editor. A prefix per kind, so a voice can't land on the
/// expression slot (each drop target accepts only its own kind).
enum DragPayload: Equatable {
    case voice(String), style(String), expression(ExpressionTag)

    var string: String {
        switch self {
        case .voice(let name): "voice:" + name
        case .style(let name): "style:" + name
        case .expression(let tag): "expr:" + tag.rawValue
        }
    }

    init?(_ string: String) {
        let parts = string.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "voice" where VoiceCatalog.contains(parts[1]): self = .voice(parts[1])
        case "style": self = .style(parts[1])
        case "expr": guard let tag = ExpressionTag(rawValue: parts[1]) else { return nil }; self = .expression(tag)
        default: return nil
        }
    }
}

extension Date {
    /// "23 Oct 2026 at 13:32" in the app's language (like the prototype's `toLocaleString(Shell.lang)`), not the
    /// system locale — a Mac set to the Buddhist calendar would otherwise show 2569 BE in an English UI.
    /// The calendar has to be passed too: `.locale()` alone keeps the system's calendar.
    @MainActor var inAppLanguage: String {
        let locale = Locale(identifier: LanguageService.shared.current.rawValue)
        let style = Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale, calendar: locale.calendar)
        return formatted(style)
    }
}

extension Text {
    /// A string whose `{sf.name}` tokens are drawn as SF Symbols: icons inside translated text instead of emoji.
    init(symbols string: String) {
        self = Self.symbolRuns(string).reduce(Text(verbatim: "")) { text, run in
            guard let symbol = run.symbol else { return Text("\(text)\(Text(verbatim: run.text))") }
            return Text("\(text)\(Text(verbatim: run.text))\(Image(systemName: symbol))")
        }
    }

    /// "Drag · {speaker.slash} mutes" → ("Drag · ", "speaker.slash"), (" mutes", nil). A lone `{` stays text.
    nonisolated static func symbolRuns(_ string: String) -> [(text: String, symbol: String?)] {
        var runs: [(text: String, symbol: String?)] = []
        var rest = Substring(string)
        while let open = rest.firstIndex(of: "{"), let close = rest[open...].firstIndex(of: "}") {
            runs.append((String(rest[..<open]), String(rest[rest.index(after: open)..<close])))
            rest = rest[rest.index(after: close)...]
        }
        return runs + [(String(rest), nil)]
    }
}
