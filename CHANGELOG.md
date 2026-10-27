# Changelog

## v1.1.0 — 2026-10-27

### Added

- **12 languages** — the app now also speaks Japanese, Korean, Vietnamese, Indonesian, Malay, Filipino, Simplified
  and Traditional Chinese, Spanish and Russian; search and switch in the Language panel.
- **AI Agent: five providers** — AI Providers has two tabs. **Voices**: Gemini TTS and Apple's Quick preview.
  **AI Agent**: Apple Foundation Models or Ollama on your Mac, or OpenAI, Gemini (your Google key) or Claude with
  your key. The chat shows a step checklist and the model's thinking, renders Markdown with Copy as it streams, and
  has Stop; ⚙ opens its settings. Polish and Add pauses use the chosen provider (not shown with Apple).
- **History › Scene** — History has two tabs of 30: **Script** (the project's steps and pins) and **Scene** (each
  scene's text versions, recorded when you pause typing, with the text it started from). Going back to a Scene row
  changes only that scene, so deleted words come back without undoing later timeline edits.

### Changed

- **History like Hosts Manager** — the pin sits in the header, Pinned / Recent sections, a Now badge, right-click
  Restore / Rename / Unpin / Pin This Version / Remove, and earlier days show their date.
- **Prices in Traditional Chinese** — the Taiwan dollar shows as NT$ next to US$, never a bare $.

### Fixed

- **Choosing a language** always uses that language's own text (Japanese on a Thai Mac used to stay Thai).

### Privacy

- With OpenAI, Gemini or Claude as the AI Agent, your question and the project's script go to that provider with
  your key; with Apple or Ollama nothing leaves your Mac. The Privacy Policy and Terms of Use say so.

### Installation

Download `AIVoiceManager-1.1.0.dmg` (and `SHA256SUMS.txt`), drag **AI Voice Manager** to **Applications** (replace
the old copy) and allow the first launch in **System Settings → Privacy & Security → Open Anyway** (or
`xattr -dr com.apple.quarantine "/Applications/AIVoiceManager.app"`). Then paste a Gemini API key from
[Google AI Studio](https://aistudio.google.com/apikey) in **AI Providers**. Requires an Apple silicon Mac with
macOS 14 or later and an internet connection; an AI Agent provider is optional.

## v1.0.1 — 2026-10-24

### Changed

- **Icons instead of emoji** — Getting started ticks, the Ollama card, the Current Scene header, the missing-key
  notice and the mute and pin hints in the timeline and Help are drawn with SF Symbols, in the app's own colours.
- **Website: the whole Gomin family in the footer** — every page now links AI Voice Manager too, in the family
  order: Gomin Apps · Hosts Manager · Git Exclude Manager · AI Voice Manager · SwiftUI Mac Skills · Profile · GitHub ·
  Sponsor.

### Installation

Download `AIVoiceManager-1.0.1.dmg` (and `SHA256SUMS.txt`), drag **AI Voice Manager** to **Applications** (replace
the old copy) and allow the first launch in **System Settings → Privacy & Security → Open Anyway** (or
`xattr -dr com.apple.quarantine "/Applications/AIVoiceManager.app"`). Then paste a Gemini API key from
[Google AI Studio](https://aistudio.google.com/apikey) in **AI Providers**. Requires an Apple silicon Mac with
macOS 14 or later and an internet connection; Ollama is optional.

## v1.0.0 — 2026-10-24

The first release: AI voice-overs written scene by scene, previewed free with the Mac's own voices and generated with
Gemini TTS on your own API key. Every take is kept.

### Added

- **Projects that keep themselves** — Recent Projects on the left; each project is a folder in
  `~/Library/Application Support/AI Voice Manager` and saves on every change. Rename with a double-click or ✎, remove
  to the Trash with Undo. **Export Project** writes one `.avmproject.zip` with every take; **Open Project…** reads it
  (or an older `.json`) on another Mac.
- **Script Timeline** — every line and every pause is a scene: drag to reorder, mute to leave it out of the take, a
  voice and a style per line, up to two voices per take (a conversation).
- **Voice Library** — 30 Gemini voices with portraits and descriptions, Male / Female filter, search and ♥ favourites;
  12 style presets on the Styles tab. Drag onto a scene or press Apply.
- **Expression Library** — breath, short and long pause, laugh, sigh, gasp and cough between lines, each repeatable up
  to ×10.
- **Listen before you pay** — **Quick preview** reads a line with the Mac's own voices, free and offline; **Generate
  preview** makes one scene with Gemini; **Generate** (⌘↵) makes the whole take, saved as a WAV with its timeline.
- **Results** — every take with its waveform: play, download the WAV, bring its timeline back, or delete to the Trash
  with Undo.
- **AI Providers** — your Gemini API key in the Keychain (Save, Test connection, Remove), Free tier or Billing on;
  with billing on the price shows in US dollars and your currency, and every paid take asks first.
- **AI Agent with Ollama** — on your Mac, no login: **Polish** and **Add pauses** rewrite one scene (one step in
  History), and the chat answers about the whole project as it streams in, with Stop.
- **Internet alerts** — the app says when the connection drops, comes back or slows down, and disables what needs it
  while you're offline.
- **History** — your last 30 edits per project and pinned states; going back is a new step, so nothing is lost.
- **The Gomin window** — Liquid Glass on macOS 26, two tool-window rails, Appearance (16 accents, 8 gradients),
  Language & Currency (English and Thai), Help and About; ⌥⌘1…0 open the panels.

### Installation

Download `AIVoiceManager-1.0.0.dmg` (and `SHA256SUMS.txt`), drag **AI Voice Manager** to **Applications** and allow
the first launch in **System Settings → Privacy & Security → Open Anyway** (or
`xattr -dr com.apple.quarantine "/Applications/AIVoiceManager.app"`). Then paste a Gemini API key from
[Google AI Studio](https://aistudio.google.com/apikey) in **AI Providers**. Requires an Apple silicon Mac with
macOS 14 or later and an internet connection; Ollama is optional.
