# GitHub Copilot Instructions — AI Voice Manager

## Project Context

**AI Voice Manager** is a free macOS app for making AI voice-overs without digging through Google AI Studio:
write a script, **preview it for free with Apple's on-device voices**, then generate the real take with the
**Gemini TTS API**. Every take (script + settings + WAV) is kept in History.

### Key Information
- **Current Phase:** Phase 2: SwiftUI static UI with mock data (`.claude/specs/phases/phase2.md`); `.prototype/` is the spec
- **Technology:** Swift 6, SwiftUI, SPM only (no `.xcodeproj`)
- **Platform:** macOS 14+, Apple silicon only
- **External Dependencies:** ZERO (Foundation, SwiftUI, AVFoundation, Security only)
- **Languages:** English + Thai (app menu switch)

---

## Product Rules (do not break)

1. **Free first, paid is always labelled.** Every engine/model shows a badge: `FREE` (on-device),
   `FREE TIER` (Gemini quota, Google may use the data), or `PAID` (billed). Never call a paid model silently.
2. **Preview before you spend.** Apple `AVSpeechSynthesizer` previews timing and wording offline, for free.
   Gemini is only called when the user presses Generate.
3. **Ollama is a script helper, not a voice.** Ollama has no text-to-speech models; use it only to rewrite,
   translate or add expression tags (`<breath>`, `<short pause>` …). Local, free, no login.
4. **Takes are plain files.** Each take = a folder with `take.json` + `take.wav` under
   `~/Library/Application Support/AI Voice Manager/Projects/<id>/Takes/`, so Finder can read it (ADR-011).
   History = edit steps per project, like Hosts Manager (ADR-008).
5. **Secrets stay in the Keychain.** The Gemini API key is never written to UserDefaults, logs, or History.

---

## Code Style & Conventions

- Follow `.swiftlint.yml` strictly (`swiftlint lint --strict` in CI). No compiler warnings.
- File ≤ 400 lines (warning), function ≤ 50 lines, line ≤ 120 chars.
- `@Observable @MainActor` stores, `async/await` for network and audio; no Combine.
- Views in `Views/`, stores in `ViewModels/`, engines and persistence in `Services/`.
- User-facing strings go through `Localizable.strings` (en + th).

## Commits

`2026 <Verb> <Thing> (<Part>).` — e.g. `2026 Added Static UI Prototype (Prototype).`
Work on `develop`, PR into `main`. Tag `vX.Y.Z` must match `Info.plist`.
