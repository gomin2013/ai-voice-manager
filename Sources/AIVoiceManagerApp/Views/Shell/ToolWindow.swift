import AppKit
import SwiftUI

// From hosts-manager's ToolWindow.swift (keep the shared parts in sync until DevFileKit). Differences: generic over
// the panel enum so one file draws **two** rails (left: projects / providers, right: the rest), and ⌥⌘ numbers run
// left → right with no shortcut past the 10th (same as the prototype's shell.js).

/// A rail's panels: ⌥⌘ numbers follow `allCases`, offset by the rails before it.
protocol RailPanel: RawRepresentable<String>, CaseIterable, Identifiable, Hashable where AllCases == [Self] {
    /// Pinned to the bottom of the rail.
    static var bottom: [Self] { get }
    /// How many panels the rails to the left already number.
    static var shortcutOffset: Int { get }
    @MainActor var icon: Image { get }
    @MainActor var title: String { get }
}

enum LeftPanel: String, RailPanel {
    case projects, providers

    static let bottom: [LeftPanel] = [.providers]
    static let shortcutOffset = 0
    var id: String { rawValue }

    @MainActor var icon: Image {
        switch self {
        case .projects: Image(systemName: "folder")
        case .providers: Image(systemName: "powerplug")
        }
    }

    @MainActor var title: String { localized("panel." + rawValue) }
}

enum RightPanel: String, RailPanel {
    case history, voices, expressions, generate, agent, help, appearance, language, about

    static let bottom: [RightPanel] = [.appearance, .language, .about]
    static let shortcutOffset = LeftPanel.allCases.count
    var id: String { rawValue }

    @MainActor var icon: Image {
        switch self {
        case .history: Image(systemName: "clock.arrow.circlepath")
        case .voices: Image(systemName: "waveform")
        case .expressions: Image(systemName: "face.smiling")
        case .generate: FloppyIcon.image
        case .agent: Image(systemName: "sparkles")
        case .help: Image(systemName: "questionmark.circle")
        case .appearance: Image(systemName: "paintpalette")
        case .language: Image(systemName: "globe")
        case .about: Image(systemName: "info.circle")
        }
    }

    @MainActor var title: String { localized("panel." + rawValue) }
}

/// Two-tone gradients from the user's reference (Pinterest "8 color schemes"). Measured: no pair keeps white text
/// ≥ 4.5:1 end to end (one end is 1.06–1.6:1) and some ends vanish on a dark window (#251351 is 1.02:1), so a theme
/// is **ambient light only** — never under text or controls. Controls take the paired solid accent instead.
enum GradientTheme: String, CaseIterable, Identifiable {
    case none, ocean, ember, lavender, watermelon, lagoon, meadow, dusk, peach

    var id: String { rawValue }
    @MainActor var name: String { localized("gradient." + rawValue) }

    var colors: [Color] {
        let pair: (UInt32, UInt32) = switch self {
        case .none: (0, 0)
        case .ocean: (0x007CBE, 0xFFF7AE)
        case .ember: (0xE57A44, 0x251351)
        case .lavender: (0xF1FEC6, 0xA882DD)
        case .watermelon: (0xDB5375, 0xB3FFB3)
        case .lagoon: (0x02C3BD, 0x4E148C)
        case .meadow: (0x629460, 0xF4D35E)
        case .dusk: (0x414288, 0xB0DB43)
        case .peach: (0xFFC145, 0xEC368D)
        }
        return [Self.color(pair.0), Self.color(pair.1)]
    }

    /// Solid accent for controls — the palette hue closest to the gradient's stronger end.
    var accent: AccentChoice {
        switch self {
        case .none: .system
        case .ocean: .blue
        case .ember: .orange
        case .lavender: .violet
        case .watermelon: .pink
        case .lagoon: .teal
        case .meadow: .lime
        case .dusk: .indigo
        case .peach: .magenta
        }
    }

    private static func color(_ hex: UInt32) -> Color {
        Color(.sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255,
              blue: Double(hex & 0xFF) / 255)
    }
}

/// Panel (when open) + icon rail on the window edge. `panel == nil` = hidden.
struct ToolWindow<Panel: RailPanel, Content: View>: View {
    @Binding var panel: Panel?
    var edge: HorizontalEdge = .trailing
    var theme: GradientTheme = .none
    @ViewBuilder var content: (Panel) -> Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        // Every panel stays mounted (hidden, zero-width when closed): the AI Agent's conversation is view state and
        // would be lost on each switch otherwise.
        HStack(spacing: 0) {
            if edge == .leading { rail }
            window
                .frame(width: panel == nil ? 0 : 320)
                .opacity(panel == nil ? 0 : 1)
                .allowsHitTesting(panel != nil)
                .accessibilityHidden(panel == nil)
            if edge == .trailing { rail }
        }
    }

    private var rail: some View {
        VStack(spacing: 6) {
            ForEach(Panel.allCases.filter { !Panel.bottom.contains($0) }) { railButton($0) }
            Spacer()
            ForEach(Panel.bottom) { railButton($0) }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .overlay(alignment: edge == .trailing ? .leading : .trailing) { Divider() }
    }

    private func railButton(_ item: Panel) -> some View {
        let number = Panel.shortcutOffset + (Panel.allCases.firstIndex(of: item) ?? 0) + 1
        return Button { panel = panel == item ? nil : item } label: {
            item.icon
                .resizable()
                .scaledToFit()
                .frame(width: 17, height: 17)
                .frame(width: 32, height: 32)
                .foregroundStyle(panel == item ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .background(panel == item ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                            in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(PanelShortcut(number: number))
        .help(number <= 10 ? localized("hint.withShortcut", item.title, "⌥⌘\(number % 10)") : item.title)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(panel == item ? .isSelected : [])
    }

    private var window: some View {
        let shown = panel ?? Panel.allCases[0]
        return VStack(spacing: 0) {
            HStack {
                Text(shown.title).font(.app(13, .semibold))
                Spacer()
                Button { panel = nil } label: { Image(systemName: "minus") }
                    .buttonStyle(.borderless)
                    .help(localized("btn.hide"))
                    .accessibilityLabel(localized("a11y.hidePanel", shown.title))
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)
            ZStack {
                ForEach(Panel.allCases) { item in
                    VStack(spacing: 0) {
                        content(item)
                        Spacer(minLength: 0)
                    }
                    .opacity(item == shown ? 1 : 0)
                    .allowsHitTesting(item == shown)
                    .accessibilityHidden(item != shown)
                }
            }
        }
        .background(alignment: .bottomTrailing) { glow }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .glassSurface(cornerRadius: 18)
        .padding(10)
    }

    /// Ambient light in the panel's corner, like the reference. Off with Reduce Transparency.
    @ViewBuilder
    private var glow: some View {
        if theme != .none && !reduceTransparency {
            Ellipse()
                .fill(LinearGradient(colors: theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 340, height: 280)
                .blur(radius: 60)
                .opacity(0.75)
                .offset(x: 110, y: 110)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// ⌥⌘1…9, 0 for the first ten panels; the rest have none (a second ⌥⌘1 would fight the first).
private struct PanelShortcut: ViewModifier {
    let number: Int

    func body(content: Content) -> some View {
        if number <= 10 {
            content.keyboardShortcut(KeyEquivalent(Character("\(number % 10)")), modifiers: [.command, .option])
        } else {
            content
        }
    }
}

/// Generate's icon: a floppy disk (the prototype's `GEN_ICON`, 24-pt grid). SF Symbols has none, so it's a template
/// image — tinted like a symbol by `foregroundStyle`.
enum FloppyIcon {
    @MainActor static let image: Image = {
        let image = NSImage(size: NSSize(width: 24, height: 24), flipped: true) { _ in
            let path = NSBezierPath()
            path.lineWidth = 1.6
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            // Body: rounded corners except the cut top-right one
            path.move(to: NSPoint(x: 6, y: 3))
            path.line(to: NSPoint(x: 16.2, y: 3))
            path.line(to: NSPoint(x: 20, y: 6.8))
            path.line(to: NSPoint(x: 20, y: 19))
            path.appendArc(from: NSPoint(x: 20, y: 21), to: NSPoint(x: 18, y: 21), radius: 2)
            path.line(to: NSPoint(x: 6, y: 21))
            path.appendArc(from: NSPoint(x: 4, y: 21), to: NSPoint(x: 4, y: 19), radius: 2)
            path.line(to: NSPoint(x: 4, y: 5))
            path.appendArc(from: NSPoint(x: 4, y: 3), to: NSPoint(x: 6, y: 3), radius: 2)
            path.close()
            // Shutter with its slot, and the label
            path.move(to: NSPoint(x: 8, y: 3)); path.line(to: NSPoint(x: 8, y: 8))
            path.line(to: NSPoint(x: 15, y: 8)); path.line(to: NSPoint(x: 15, y: 3))
            path.move(to: NSPoint(x: 12.5, y: 4.5)); path.line(to: NSPoint(x: 12.5, y: 6.5))
            path.move(to: NSPoint(x: 7, y: 21)); path.line(to: NSPoint(x: 7, y: 15))
            path.appendArc(from: NSPoint(x: 7, y: 14), to: NSPoint(x: 8, y: 14), radius: 1)
            path.line(to: NSPoint(x: 16, y: 14))
            path.appendArc(from: NSPoint(x: 17, y: 14), to: NSPoint(x: 17, y: 15), radius: 1)
            path.line(to: NSPoint(x: 17, y: 21))
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        return Image(nsImage: image)
    }()
}
