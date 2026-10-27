import SwiftUI

/// Voice Library (prototype `voicesPanel`): Voices | Styles. Drag a row onto the Current Scene or press Apply.
struct VoiceLibraryPanel: View {
    @Environment(EditorViewModel.self) private var vm
    @AppStorage("ui.voiceTab") private var tab = "voices"
    @State private var query = ""
    @State private var filter = VoiceFilter.all
    @State private var language = ""
    @State private var pitch = ""
    // ponytail: names joined by ","; voice names never contain one. App-wide, not per project, not in History.
    @AppStorage("voice.favorites") private var favoritesRaw = ""

    private enum VoiceFilter: Hashable { case all, gender(Gender), favorites, inUse }

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
        let favorites = favorites, directory = VoiceDirectory.shared, ui = LanguageService.shared.current.rawValue
        let draft = vm.draft
        let used = Set(draft.items.compactMap { item in
            if case .script(let scene) = item { draft.speaker(scene.speaker).voice } else { nil }
        })
        let matches = directory.voices.filter { voice in
            let kept = switch filter {
            case .all: true
            case .gender(let gender): voice.gender == gender
            case .favorites: favorites.contains(voice.value)
            case .inUse: used.contains(voice.value)
            }
            let fields = [voice.name, voice.description, voice.persona, voice.accent, voice.language,
                          Self.languageName(voice.language, in: ui)]
            return kept && (language.isEmpty || voice.language == language) && (pitch.isEmpty || voice.pitch == pitch)
                && (query.isEmpty || fields.contains { $0.localizedCaseInsensitiveContains(query) })
        }
        return VStack(alignment: .leading, spacing: 8) {
            Group {
                TextField(localized("vSearch"), text: $query).textFieldStyle(.roundedBorder)
                Picker(localized("gender"), selection: $filter) {
                    // Counts live in the line below: 2,089 doesn't fit a 320 pt segment
                    Text(localized("all")).tag(VoiceFilter.all)
                    // Icons, not words (♂ ♀ as in GenderPill): five worded segments outgrow the 320 pt panel
                    Text(verbatim: "♂").help(localized("male")).accessibilityLabel(localized("male"))
                        .tag(VoiceFilter.gender(.male))
                    Text(verbatim: "♀").help(localized("female")).accessibilityLabel(localized("female"))
                        .tag(VoiceFilter.gender(.female))
                    Text(verbatim: "♥ \(favorites.count)")   // text, not Image: a segment drops an inline SF Symbol
                        .help(localized("fav")).accessibilityLabel(localized("fav")).tag(VoiceFilter.favorites)
                    Text(verbatim: "✓ \(used.count)")
                        .help(localized("inUse")).accessibilityLabel(localized("inUse")).tag(VoiceFilter.inUse)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                HStack(spacing: 6) {   // Language | Pitch
                    Picker(localized("language"), selection: $language) {
                        Text(localized("language") + ": " + localized("all")).tag("")
                        ForEach(Self.languages(directory.voices, in: ui), id: \.code) { Text($0.name).tag($0.code) }
                    }
                    .labelsHidden()
                    Picker(localized("pitch"), selection: $pitch) {
                        Text(localized("pitch") + ": " + localized("all")).tag("")
                        ForEach(["low", "medium", "high"], id: \.self) { Text(localized("pitch." + $0)).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                HStack(spacing: 6) {
                    Text(localized("gVoices") + " · \(matches.count)").font(.app(11.5)).foregroundStyle(.secondary)
                    Pill(text: localized("bTier"))
                    Spacer(minLength: 4)
                    if directory.isRefreshing {
                        ProgressView().controlSize(.mini)
                    } else if vm.hasGeminiKey {
                        Button { Task { await directory.refresh(key: vm.loadKey() ?? "") } } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .help(localized("vRefresh"))
                        .accessibilityLabel(localized("vRefresh"))
                    }
                }
            }
            .controlSize(.small)
            .padding(.horizontal, 14)
            if matches.isEmpty {
                Text(localized(filter == .favorites && favorites.isEmpty ? "favEmpty" : "noMatch"))
                    .foregroundStyle(.secondary).padding(.horizontal, 14)
            }
            List(matches) { voice in
                VoiceRow(voice: voice, language: Self.languageName(voice.language, in: ui),
                         favorite: (favorites.contains(voice.value), { toggleFavorite(voice.value) }))
            }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
        }
    }

    private static func languages(_ voices: [Voice], in ui: String) -> [(code: String, name: String)] {
        Set(voices.map(\.language)).filter { !$0.isEmpty }
            .map { (code: $0, name: languageName($0, in: ui)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// "Japanese (Japan)" for ja-JP in an English UI, "ญี่ปุ่น (ญี่ปุ่น)" in Thai.
    static func languageName(_ code: String, in ui: String) -> String {
        code.isEmpty ? "" : Locale(identifier: ui).localizedString(forIdentifier: code) ?? code
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
    let language: String
    let favorite: (isOn: Bool, toggle: () -> Void)
    @Environment(EditorViewModel.self) private var vm

    var body: some View {
        let draft = vm.draft
        let here = if case .script(let scene) = vm.selectedItem {
            draft.speaker(scene.speaker).voice == voice.value
        } else { false }
        let inProject = draft.items.contains { item in
            if case .script(let scene) = item { draft.speaker(scene.speaker).voice == voice.value } else { false }
        }
        let pitch = voice.pitch.isEmpty ? "" : localized("pitch." + voice.pitch)
        let details = [voice.isBuiltin ? voice.description : "", language, voice.accent, pitch].filter { !$0.isEmpty }
        LibraryRow(payload: .voice(voice.value), hint: localized("dragVoice"),
                   icon: VoicePortrait(voice: voice.value, size: 36),
                   title: HStack { Text(voice.name).bold(); GenderPill(gender: voice.gender); if here { InUse() } },
                   subtitle: details.joined(separator: " · ")
                       + (inProject && !here ? " · " + localized("inProject") : ""),
                   applyTitle: localized("apply"), applyHint: localized("applyScene"),
                   apply: { vm.useVoice(voice.value) }, favorite: favorite)
            .help(voice.isBuiltin ? "" : voice.description)
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
