import SwiftUI

/// Voice Library (prototype `voicesPanel`): Voices | Styles. Drag a row onto the Current Scene or press Apply.
struct VoiceLibraryPanel: View {
    @Environment(EditorViewModel.self) private var vm
    @AppStorage("ui.voiceTab") private var tab = "voices"
    @State private var query = ""
    @State private var filter = VoiceFilter.all
    // ponytail: names joined by ","; voice names never contain one. App-wide, not per project, not in History.
    @AppStorage("voice.favorites") private var favoritesRaw = ""

    private enum VoiceFilter: Hashable { case all, gender(Gender), favorites }

    private var favorites: Set<String> { Set(favoritesRaw.split(separator: ",").map(String.init)) }

    private func toggleFavorite(_ name: String) {
        favoritesRaw = favorites.symmetricDifference([name]).sorted().joined(separator: ",")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(localized("panel.voices"), selection: $tab) {
                Text(localized("tabVoices")).tag("voices")
                Text(localized("tabStyles")).tag("styles")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 14)
            if tab == "styles" { styles } else { voices }
        }
    }

    // MARK: Voices

    private var voices: some View {
        let favorites = favorites
        let matches = VoiceCatalog.all.filter { voice in
            let kept = switch filter {
            case .all: true
            case .gender(let gender): voice.gender == gender
            case .favorites: favorites.contains(voice.name)
            }
            return kept && (query.isEmpty
                || [voice.name, voice.description, localized(voice.gender == .female ? "female" : "male")]
                    .contains { $0.localizedCaseInsensitiveContains(query) })
        }
        let female = VoiceCatalog.all.filter { $0.gender == .female }.count
        let male = VoiceCatalog.all.count - female
        return VStack(alignment: .leading, spacing: 8) {
            Group {
                TextField(localized("vSearch"), text: $query).textFieldStyle(.roundedBorder)
                Picker(localized("gender"), selection: $filter) {
                    Text(localized("all") + " \(VoiceCatalog.all.count)").tag(VoiceFilter.all)
                    Text(localized("male") + " \(male)").tag(VoiceFilter.gender(.male))
                    Text(localized("female") + " \(female)").tag(VoiceFilter.gender(.female))
                    // ♥ only: a 4th worded segment outgrows the 320 pt panel (Thai) and pushes every panel under the rail
                    Text("♥ \(favorites.count)").help(localized("fav")).accessibilityLabel(localized("fav"))
                        .tag(VoiceFilter.favorites)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                HStack(spacing: 6) {
                    Text(localized("gVoices") + " · \(matches.count)").font(.app(11.5)).foregroundStyle(.secondary)
                    Pill(text: localized("bTier"))
                }
            }
            .padding(.horizontal, 14)
            if matches.isEmpty {
                Text(localized(filter == .favorites && favorites.isEmpty ? "favEmpty" : "noMatch"))
                    .foregroundStyle(.secondary).padding(.horizontal, 14)
            }
            List(matches) { voice in
                VoiceRow(voice: voice, favorite: (favorites.contains(voice.name), { toggleFavorite(voice.name) }))
            }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
        }
    }

    // MARK: Styles

    private var styles: some View {
        let current = if case .script(let scene) = vm.selectedItem { scene.style } else { "" }
        return VStack(alignment: .leading, spacing: 8) {
            Text(localized("styleLibHint")).font(.app(11.5)).foregroundStyle(.secondary).padding(.horizontal, 14)
            List(StylePreset.all) { preset in
                LibraryRow(payload: .style(preset.name), hint: localized("dragStyle"),
                           icon: StyleIcon(style: preset.name, size: 40),
                           title: HStack { Text(preset.name).bold(); if preset.name == current { InUse() } },
                           subtitle: localized("style." + preset.slug),
                           applyTitle: localized("apply"), applyHint: localized("applyScene"),
                           apply: { vm.useStyle(preset.name) })
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

private struct VoiceRow: View {
    let voice: Voice
    let favorite: (isOn: Bool, toggle: () -> Void)
    @Environment(EditorViewModel.self) private var vm

    var body: some View {
        let draft = vm.draft
        let here = if case .script(let scene) = vm.selectedItem {
            draft.speaker(scene.speaker).voice == voice.name
        } else { false }
        let inProject = draft.items.contains { item in
            if case .script(let scene) = item { draft.speaker(scene.speaker).voice == voice.name } else { false }
        }
        LibraryRow(payload: .voice(voice.name), hint: localized("dragVoice"),
                   icon: VoicePortrait(voice: voice.name, size: 36),
                   title: HStack { Text(voice.name).bold(); GenderPill(gender: voice.gender); if here { InUse() } },
                   subtitle: voice.description + (inProject && !here ? " · " + localized("inProject") : ""),
                   applyTitle: localized("apply"), applyHint: localized("applyScene"),
                   apply: { vm.useVoice(voice.name) }, favorite: favorite)
    }
}

/// Expression Library (prototype `expressionsPanel`): drag onto the timeline (inserts) or the Current Scene
/// (changes); Apply changes the selected expression, or inserts one after a selected line.
struct ExpressionLibraryPanel: View {
    @Environment(EditorViewModel.self) private var vm

    var body: some View {
        let selected = if case .expr(let scene) = vm.selectedItem { scene.tag } else { ExpressionTag?.none }
        VStack(alignment: .leading, spacing: 8) {
            Text(localized("exprLibHint")).font(.app(11.5)).foregroundStyle(.secondary).padding(.horizontal, 14)
            List(ExpressionTag.allCases, id: \.self) { tag in
                LibraryRow(payload: .expression(tag), hint: localized("dragExpr") + " · " + tag.rawValue,
                           icon: ExpressionIcon(tag: tag, size: 40),
                           title: HStack { Text("<\(vm.label(tag))>").bold(); if tag == selected { InUse() } },
                           subtitle: localized("exd." + tag.key),
                           applyTitle: localized(selected == nil ? "insert" : "apply"),
                           applyHint: localized(selected == nil ? "insertExprTip" : "applyExprTip"),
                           apply: { vm.applyExpression(tag) })
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

/// Icon · title / subtitle · Apply — draggable as `payload`.
private struct LibraryRow<Icon: View, Title: View>: View {
    let payload: DragPayload
    let hint: String
    let icon: Icon
    let title: Title
    let subtitle: String
    let applyTitle: String
    let applyHint: String
    let apply: () -> Void
    var favorite: (isOn: Bool, toggle: () -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                title
                Text(subtitle).font(.app(11.5)).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 4)
            if let favorite {
                let hint = localized(favorite.isOn ? "favRemove" : "favAdd")
                Button(action: favorite.toggle) {
                    Image(systemName: favorite.isOn ? "heart.fill" : "heart")   // like Google's TTS playground
                        .foregroundStyle(favorite.isOn ? AnyShapeStyle(.pink) : AnyShapeStyle(.secondary))
                }
                .buttonStyle(.borderless).help(hint).accessibilityLabel(hint)
                .accessibilityAddTraits(favorite.isOn ? .isSelected : [])
            }
            Button(applyTitle, action: apply).controlSize(.small).help(applyHint)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .draggable(payload.string)
        .help(hint)
    }
}

private struct InUse: View {
    var body: some View { Text("✓ " + localized("inUse")).font(.app(11, .semibold)).foregroundStyle(.tint) }
}
