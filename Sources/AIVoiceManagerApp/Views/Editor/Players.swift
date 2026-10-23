import AVFoundation
import SwiftUI

/// ▶ waveform 0:00 / 0:07 MOCK — the scene's and the take's player look the same; `Playback` keeps one playing.
struct MockPlayer: View {
    let source: Playback.Source
    let duration: Double
    let seed: Int
    @Environment(Playback.self) private var playback
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let playing = playback.isPlaying(source)
        HStack(spacing: 10) {
            Button { playback.toggle(source, duration: duration) } label: {
                Image(systemName: playing ? "stop.fill" : "play.fill")
            }
            .buttonStyle(.borderless)
            .help(localized(playing ? "stop" : "play"))
            .accessibilityLabel(localized(playing ? "stop" : "play"))
            WaveBars(seed: seed, progress: playing ? playback.elapsed / playback.duration : 0)
            Text(time(playing ? playback.elapsed : 0) + " / " + time(duration))
                .font(.data(11)).foregroundStyle(.secondary)
            Pill(text: localized("bMock"), color: .secondary)
        }
        .padding(8)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
        .opacity(isEnabled ? 1 : 0.5)
    }

    private func time(_ seconds: Double) -> String {
        Duration.seconds(seconds.rounded()).formatted(.time(pattern: .minuteSecond))
    }
}

/// 60 bars from a fixed seed (the prototype's `waveBars`), filled up to `progress`.
struct WaveBars: View {
    let seed: Int
    let progress: Double

    var body: some View {
        let heights = Self.heights(seed: seed)
        // Canvas: the bars spread over whatever width there is (a fixed bar width set the column's minimum)
        Canvas { context, size in
            let step = size.width / CGFloat(heights.count)
            for (index, height) in heights.enumerated() {
                let barHeight = 4 + (size.height - 4) * height
                let bar = CGRect(x: CGFloat(index) * step, y: (size.height - barHeight) / 2,
                                 width: max(1, step * 0.5), height: barHeight)
                let played = Double(index) / Double(heights.count) < progress
                context.fill(Path(roundedRect: bar, cornerRadius: 1),
                             with: played ? .style(.tint) : .style(.tertiary))
            }
        }
        .frame(minWidth: 60, maxWidth: .infinity, minHeight: 26, maxHeight: 26)
        .accessibilityHidden(true)
    }

    static func heights(seed: Int) -> [Double] {
        var value = UInt64(truncatingIfNeeded: seed) % 233_280
        return (0..<60).map { _ in
            value = (value * 9301 + 49297) % 233_280
            return 0.2 + 0.8 * Double(value) / 233_280
        }
    }
}

/// Quick preview popover (ADR-004/010): Mac voices for the text's language, speed, Play / Stop. Not a sheet, so
/// writing continues; closing it stops the speech.
struct QuickPreviewPopover: View {
    let text: String
    @AppStorage("quick.voice") private var voiceID = ""
    @AppStorage("quick.rate") private var rate = 1.0
    @Environment(Playback.self) private var playback
    private let speech = QuickPreview.shared

    var body: some View {
        let voices = speech.voices(for: text)
        VStack(alignment: .leading, spacing: 10) {
            Text(localized("applePrev")).font(.app(13, .semibold))
            if voices.isEmpty {
                Text(localized("appleNone")).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            } else {
                Picker(localized("aVoice"), selection: $voiceID) {
                    ForEach(voices, id: \.identifier) { Text($0.name).tag($0.identifier) }
                }
                HStack {
                    Text(localized("aRate"))
                    Slider(value: $rate, in: 0.5...1.5)
                    Text(rate.formatted(.number.precision(.fractionLength(1))) + "×").font(.data(11))
                }
                Button(speech.isSpeaking ? localized("aStop") : localized("aPlay")) {
                    if speech.isSpeaking {
                        speech.stop()
                    } else {
                        playback.stop()
                        let voice = voices.first { $0.identifier == voiceID } ?? voices.first
                        speech.speak(text, voice: voice, rate: Float(rate))
                    }
                }
                .glassButton(prominent: true)
            }
            Text(localized("appleNote")).font(.app(11.5)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 300)
        .onDisappear { speech.stop() }
    }
}
