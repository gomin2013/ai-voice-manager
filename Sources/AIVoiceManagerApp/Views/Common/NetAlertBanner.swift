import SwiftUI

/// The internet alert under the project name — MUI's "standard" Alert (prototype `.alert`): tinted background,
/// coloured icon, dark text, ✕ where it can be closed.
struct NetAlertBanner: View {
    @Environment(ConnectionMonitor.self) private var net

    var body: some View {
        if let alert = net.alert {
            let style = Self.style(alert)
            HStack(spacing: 9) {
                Image(systemName: style.icon).foregroundStyle(style.accent).font(.system(size: 15))
                Text(text(alert)).font(.app(12.5)).foregroundStyle(style.text)
                Spacer(minLength: 0)
                if alert != .offline {
                    Button { net.dismiss() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(style.text.opacity(0.7))
                        .help(localized("close"))
                        .accessibilityLabel(localized("close"))
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(style.background, in: RoundedRectangle(cornerRadius: 7))
            .accessibilityElement(children: .combine)
            .transition(.opacity)
        }
    }

    private func text(_ alert: ConnectionMonitor.Alert) -> String {
        switch alert {
        case .offline: localized("netOffline")
        case .restored: localized("netRestored")
        case .slow: localized("netSlow", net.lastMS > 0
            ? (net.lastMS / 1000).formatted(.number.precision(.fractionLength(1))) + " s" : "> 8 s")
        case .fast: localized("netFast")
        }
    }

    private struct Style {
        let icon: String
        let accent: Color
        let text: Color
        let background: Color
    }

    /// MUI's standard-alert palette, light | dark.
    private static func style(_ alert: ConnectionMonitor.Alert) -> Style {
        switch alert {
        case .offline: Style(icon: "exclamationmark.circle", accent: .hex(0xD32F2F),
                             text: .pair(0x5F2120, 0xF4C7C7), background: .pair(0xFDEDED, 0x160B0B))
        case .slow: Style(icon: "exclamationmark.triangle", accent: .hex(0xED6C02),
                          text: .pair(0x663C00, 0xFFE2B7), background: .pair(0xFFF4E5, 0x191207))
        case .fast: Style(icon: "info.circle", accent: .hex(0x0288D1),
                          text: .pair(0x014361, 0xB8E7FB), background: .pair(0xE5F6FD, 0x071318))
        case .restored: Style(icon: "checkmark.circle", accent: .hex(0x2E7D32),
                              text: .pair(0x1E4620, 0xCCE8CD), background: .pair(0xEDF7ED, 0x0C130D))
        }
    }
}

private extension Color {
    static func hex(_ value: Int) -> Color {
        Color(red: Double(value >> 16 & 0xFF) / 255, green: Double(value >> 8 & 0xFF) / 255,
              blue: Double(value & 0xFF) / 255)
    }

    /// One colour in Light, another in Dark.
    static func pair(_ light: Int, _ dark: Int) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            NSColor(hex(appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light))
        })
    }
}
