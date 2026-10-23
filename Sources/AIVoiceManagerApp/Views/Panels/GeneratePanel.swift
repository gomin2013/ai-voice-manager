import SwiftUI

/// Generate (prototype `generatePanel`): the whole project only — player, one summary line (scenes · length · tier ·
/// cost in USD ≈ local), Generate (⌘↵), Results. Paid → confirm first (never call a paid model silently).
struct GeneratePanel: View {
    @Environment(EditorViewModel.self) private var vm
    @Environment(Playback.self) private var playback
    @Environment(ConnectionMonitor.self) private var net
    @AppStorage("gemini.tier") private var tier = "free"
    @AppStorage("app.currency") private var currency = "auto"
    @State private var activeTake: String?
    @State private var confirmPaid = false

    private var isPaid: Bool { !vm.model.freeTier || tier == "paid" }

    var body: some View {
        let seconds = estimateSeconds(plainText(of: vm.draft))
        let take = vm.project.takes.first { $0.id == activeTake } ?? vm.project.takes.first
        VStack(alignment: .leading, spacing: 10) {
            PlayerBar(source: .take(take?.id ?? ""), duration: take?.duration ?? seconds,
                      seed: take?.id.hashValue ?? 7, audio: take.flatMap(vm.audio(of:)).map { .file($0) },
                      heights: take.flatMap(vm.waveform(of:)))
                .disabled(take == nil)
            HStack(spacing: 6) {
                Text(localized("summary", "\(vm.items.filter { !$0.isMuted }.count)", time(seconds)))
                TierPill()
                Text(isPaid ? localized("costPaid", cost) : localized("costFree"))
            }
            .font(.app(12))
            Button(action: start) {
                Text(vm.isGenerating ? localized("generating") : localized("generate") + "  ⌘↵")
                    .frame(maxWidth: .infinity)
            }
            .glassButton(prominent: true)
            .disabled(vm.isGenerating || !net.isOnline)
            .help(net.isOnline ? "" : localized("netNeeds"))
            Text(localized("results").uppercased() + " · \(vm.project.takes.count)")
                .font(.app(11, .semibold)).foregroundStyle(.secondary)
            if vm.project.takes.isEmpty {
                Text(localized("noTakes")).foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(vm.project.takes) { take in
                        row(take, isActive: take.id == (activeTake ?? vm.project.takes.first?.id))
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .onChange(of: vm.generateRequested) {
            if vm.generateRequested { vm.generateRequested = false; start() }
        }
        .alert(localized("paidTitle"), isPresented: $confirmPaid) {
            Button(localized("cancel"), role: .cancel) {}
            Button(localized("generate")) { Task { await vm.generate() } }
        } message: {
            Text(vm.model.name + " · " + localized("costPaid", cost))
        }
    }

    /// Never a paid model silently: Billing on (or a paid-only model) asks first.
    private func start() {
        guard net.isOnline else { vm.notice = EditorViewModel.Notice(text: localized("netOffline")); return }
        if isPaid { confirmPaid = true } else { Task { await vm.generate() } }
    }

    private var cost: String {
        let code = currency == "auto" ? CurrencyRates.currency(forLanguage: LanguageService.shared.current.rawValue)
                                      : currency
        return Money.usdWithLocal(ModelCatalog.costUSD(of: vm.draft), currency: code,
                                  language: LanguageService.shared.current.rawValue)
    }

    private func time(_ seconds: Double) -> String {
        Duration.seconds(seconds.rounded()).formatted(.time(pattern: .minuteSecond))
    }

    private func row(_ take: Take, isActive: Bool) -> some View {
        let playing = playback.isPlaying(.take(take.id))
        return HStack(spacing: 8) {
            Button {
                activeTake = take.id
                playback.toggle(.take(take.id), duration: take.duration, audio: vm.audio(of: take).map { .file($0) })
            } label: {
                Image(systemName: playing ? "stop.fill" : "play.fill")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(localized(playing ? "stop" : "play"))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(time(take.duration) + " · " + ModelCatalog.model(take.draft.model).name
                        .replacingOccurrences(of: "Gemini ", with: ""))
                    if take.mock { Pill(text: localized("bMock"), color: .secondary) }
                }
                Text(take.created.inAppLanguage)
                    .font(.app(11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            icon("arrow.counterclockwise", localized("restoreTake")) { vm.restoreTake(take.id) }
            icon("arrow.down.to.line", localized("download")) { download(take) }
                .disabled(vm.audio(of: take) == nil)   // a mock take has no WAV
            icon("xmark", localized("remove")) { vm.deleteTake(take.id) }
        }
        .padding(6)
        .background(isActive ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture { activeTake = take.id }
    }

    /// Download: a copy of the take's WAV, named after the project and the take.
    private func download(_ take: Take) {
        guard let source = vm.audio(of: take) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = vm.fileStem + "-\(take.id).wav"
        panel.allowedContentTypes = [.wav]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            try FileManager.default.copyItem(at: source, to: url)
        } catch {
            vm.notice = EditorViewModel.Notice(text: localized("saveFailed", url.lastPathComponent))
        }
    }

    private func icon(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol) }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help(label)
            .accessibilityLabel(label)
    }
}
