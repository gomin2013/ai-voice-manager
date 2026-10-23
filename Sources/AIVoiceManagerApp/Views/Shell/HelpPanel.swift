import SwiftUI

/// Help topics in workflow order (the prototype's `help:` list): projects → providers → model → timeline → scene →
/// history → libraries → generate → AI. Same layout as hosts-manager's HelpList.
struct HelpPanel: View {
    static let items: [(icon: String, key: String)] = [
        ("folder", "h.projects"),
        ("powerplug", "h.providers"),
        ("cpu", "h.model"),
        ("list.bullet", "h.timeline"),
        ("text.cursor", "h.scene"),
        ("clock.arrow.circlepath", "h.history"),
        ("waveform", "h.voices"),
        ("face.smiling", "h.exprs"),
        ("square.and.arrow.down", "h.gen"),
        ("sparkles", "h.ai")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Self.items, id: \.key) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: item.icon)
                            .frame(width: 18)
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(localized(item.key + ".t")).font(.callout.bold())
                            Text(symbols: localized(item.key + ".d"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
    }
}
