# Static UI Prototype

`index.html` (the app) + `shell.css` / `shell.js` (window, rails and tool-window panels, identical in every Gomin Apps
prototype until DevFileKit). No build step. Plan: `.claude/specs/phases/`.

Layout = Hosts Manager / Git Exclude Manager, plus a tool window on the left:

| Left | Main | Right |
|---|---|---|
| **Recent Projects** (top): names only, searchable · New / Open Project… · **AI Providers** (bottom of the left rail, like Appearance on the right; opens by itself until Google is connected): getting-started checklist, Google key (Save / Test / Remove, tier), Ollama status + model, Apple (not used yet) | Project name with Export Project and Generate → on the same row · **Model** under the name (chosen at New Project, Change says what changes) · **every warning** under the name too (no Google key, model can't read Thai), each with its fix button · **Script Timeline** (scenes: Script lines and Expressions like `<breath>`; drag to reorder, 🔇 mute) · **Current Scene** (Script: **voice** box (drop from Voice Library; the portrait wears the scene's style icon on its corner, timeline rows too), **style** box (drop from Styles or type), text, **its own player** + Gemini preview of this scene · Expression: the current one + drop zone) | **History** (same as Hosts Manager: Pinned + the last 30 steps, newest first, ↩ / double-click goes back as a new step; its own per project) · **Voice Library** · **Expression Library** (sketch icons from one ChatGPT sheet — 5 cut from it, the two pauses interim SVGs; `.claude/docs/design/expression-icons.md`) · **Generate** (whole project only: player, one summary line, Generate, results; the model is set under the project name only) · AI Agent · Help / Appearance · Language · About |

## Run

```bash
cd .prototype && python3 -m http.server 8080   # then open http://localhost:8080
```

## What is real, what is mock

| Part | Status |
|---|---|
| **Apple · Quick preview** | **Real**: the button in the scene text's top-right corner opens a popover (not a modal, you keep writing) that reads this scene with the Mac's own voices (Web Speech here, `AVSpeechSynthesizer` in the app; Thai = Kanya), voice + speed remembered, tags skipped. Free and instant, not the final voice |
| **Previews** | Final voice = Gemini TTS only. Two separate players: the scene's own (Current Scene, greyed out until Generate preview) and the project's (Generate). Each keeps its own state; starting one stops the other. Both are **mock**: no API call, the player runs the clock without sound and says MOCK |
| **Voice Library** | Two tabs. **Voices**: the **real list** of 30 Gemini TTS voices with ♀/♂ tags (Google Cloud Chirp 3: HD list, 14 female · 16 male), searchable, filter All / Male / Female. Each voice has a paper-collage portrait (`img/voices/`, cut from one ChatGPT image — prompt and cut notes in `.claude/docs/design/voice-avatars.md`), shown in the list, the timeline and the scene's voice box. Apply / drop = this scene speaks with it; max 2 voices per project (a third is refused with a message). **Styles**: 12 presets with sketch icons (`img/styles/`, one ChatGPT sheet — `.claude/docs/design/style-icons.md`; English name sent to Gemini, TH/EN description), Apply or drop onto the scene's Style box. Ollama lives in AI Providers only |
| **Ollama** | **Real** when `ollama serve` runs: AI Agent chats about the project, and the ✦ buttons under the scene text (**Polish · Add pauses**, next to the character count; TH↔EN is out until projects get languages) rewrite **this scene only** (one History step; tags in the answer become Expression scenes). Off: Add pauses uses `autoTag()` (still yours to write), the others say Ollama is off |
| **Gemini Generate** | Mock: waits 1.4 s, saves a take marked `MOCK`. Playing a mock take runs the clock without sound; Download gives `take.json` (real takes: the WAV) |
| **Request body (`curl()`)** | Real body for `POST /v1beta/interactions` (single + conversational multi-speaker). Not shown in the UI for now (`previewRaw()` kept, not wired) |
| Free / Paid badges, cost | Real prices from ai.google.dev/pricing (2026-10-22). Key billing is in AI Providers |
| **Test connection** | **Real**: lists one model at generativelanguage.googleapis.com with the key (a wrong key shows Google's HTTP error). The key itself sits in `localStorage` here; the app uses the Keychain |
| Timeline → request | **Real**: scenes merge into speech segments with tags inline, muted scenes left out. Older projects with `blocks` are split into scenes on load |
| Projects | Save automatically (`localStorage`). Export Project → one `.avmproject.json`; Open Project… (Recent Projects) brings it in on another Mac, checked field by field |

## Try

1. Pick a scene → **Generate preview** with no key → **AI Providers** opens on the left → any `AIza…` → Save → Generate preview → Ready → ▶ Play (MOCK) → **Generate →** → the take appears in **Results**
2. **Voice Library** → search `warm` → drag **Sulafat** onto the Current Scene's voice box (or press **Apply**) → the scene and History follow
3. **New Project** → choose a model first → the project opens with it under the name · **Change** on a Thai project → Flash-Lite warns it can't read Thai
4. **Recent Projects** → search `git` → open **Git Exclude Manager — two voices** → Speaker 2 row appears
5. Edit a scene, **＋ Expression**, drag it up, 🔇 mute a line → the muted line is left out of the take → **History** lists each step → double-click **When Opened** (or ↩) to go back; switch project and back: each keeps its own
6. **Export Project** → Recent Projects → **Open Project…** the downloaded file → it opens as a new project
7. Delete a take → **Undo** in the toast · ⌘↵ = Generate · ⌥⌘1…9, 0 = rails
