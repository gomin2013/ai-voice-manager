import AVFoundation
import Foundation
import Observation

/// One player at a time (ADR-009): the scene's own preview or a take in Generate — starting one stops the other.
/// Real audio plays through AVAudioPlayer; a mock take (demo data, no WAV) just runs the clock and says MOCK.
@MainActor
@Observable
final class Playback {
    enum Source: Equatable { case scene(String), take(String) }
    enum Audio { case data(Data), file(URL) }

    private(set) var source: Source?
    private(set) var elapsed: Double = 0
    private(set) var duration: Double = 0
    @ObservationIgnored private var clock: Task<Void, Never>?
    @ObservationIgnored private var player: AVAudioPlayer?

    func isPlaying(_ source: Source) -> Bool { self.source == source }

    func toggle(_ source: Source, duration: Double, audio: Audio? = nil) {
        if isPlaying(source) { stop() } else { play(source, duration: duration, audio: audio) }
    }

    func play(_ source: Source, duration: Double, audio: Audio? = nil) {
        stop()
        QuickPreview.shared.stop()
        if let audio {
            player = switch audio {
            case .data(let data): try? AVAudioPlayer(data: data)
            case .file(let url): try? AVAudioPlayer(contentsOf: url)
            }
            guard let player, player.play() else { self.player = nil; return }
        }
        self.source = source
        self.duration = max(player?.duration ?? duration, 1)
        clock = Task { [weak self] in
            while let self, !Task.isCancelled, elapsed < self.duration {
                try? await Task.sleep(for: .milliseconds(100))
                if let player {
                    guard player.isPlaying else { break }
                    elapsed = player.currentTime
                } else {
                    elapsed = min(elapsed + 0.1, self.duration)
                }
            }
            if !Task.isCancelled { self?.stop() }
        }
    }

    func stop() {
        clock?.cancel()
        clock = nil
        player?.stop()
        player = nil
        source = nil
        elapsed = 0
    }
}

/// Quick preview (ADR-004): the Mac's own voices read this scene — free, instant, never the final voice.
/// On-device only, so it's real in Phase 2.
@MainActor
@Observable
final class QuickPreview: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = QuickPreview()

    private(set) var isSpeaking = false
    @ObservationIgnored private let synth = AVSpeechSynthesizer()

    override private init() {
        super.init()
        synth.delegate = self
    }

    /// Voices for the text's language (Thai → Kanya …).
    func voices(for text: String) -> [AVSpeechSynthesisVoice] {
        let language = containsThai(text) ? "th" : "en"
        return AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(language) }
    }

    func speak(_ text: String, voice: AVSpeechSynthesisVoice?, rate: Float) {
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text.replacing(/<[^>]+>/, with: " "))   // tags are for Gemini
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * rate
        isSpeaking = true
        synth.speak(utterance)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
