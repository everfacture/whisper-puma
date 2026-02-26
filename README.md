# 🐆 Whisper Puma v1.2.0

You’re talking to a local Puma—lean, attentive, and tuned to your cadence. Whisper Puma is a native macOS menubar companion that listens, formats, and types your thoughts without ever leaving the machine.

## Why It Feels Natural

- **Hold, don’t toggle**—`Fn` is the default trigger and always behaves like a hold-to-talk switch so keep your flow and avoid accidental language toggles.
- **One trusted model**—`mlx-community/whisper-large-v3-mlx` is the release model; turbo only wakes up as a hidden rescue when MLX fails to decode anything useful.
- **Punctuation that listens**—spoken commands (`comma`, `new paragraph`, `list point one`, etc.) get handled immediately; long transcripts run through a bounded local polish (`qwen2.5:3b-instruct`, 250 ms limit) without rewriting your voice.
- **Direct typing first**—the Puma prowls straight into the focused app; if that fails, it gently drops the text via clipboard + `Cmd+V` and restores your clipboard contents.
- **History with a heartbeat**—every transcript is saved in `~/.whisper_puma_history.log` so you can revisit or copy anything that was pasted (clean JSONL with timestamps, styled UI inside Settings).

## Quick Start

```bash
git clone https://github.com/everfacture/whisper-puma.git
cd whisper-puma
pip install -r src/backend/requirements.txt
./scripts/build_app.sh
open build/WhisperPuma.app
```

## Required Permissions

1. **Microphone** — `System Settings → Privacy & Security → Microphone`
2. **Accessibility** — `System Settings → Privacy & Security → Accessibility`

Without Accessibility, the app copies to your clipboard and leaves pasting to you.

## Puma Roadmap

- **Next sprint**: polish spoken list handling, tighten long-form punctuation, and add latency telemetry notifications in Settings.
- **Upcoming**: smarter context-aware style hints (email vs. notes vs. code) and more expressive HUD cues so you always know what the Puma is doing.
- **Dream sprint**: multi-language agility (still local-first) plus an offline broadcast mode that keeps your writing synced across devices you trust.

## Architecture & Flow

 - Backend process captures PCM chunks via the WebSocket stream, roams through MLX for full-final transcriptions, and falls back to turbo rescue only on empty results.
 - Settings UI maintains the Puma aesthetic (icon, dark/light clarity, Roe button) with the live latency badge you can snag for checks.
 - History view is a warm log of your voice thoughts, searchable and copy-ready whenever you need to revisit an idea.

## Troubleshooting

- **Empty words**: confirm microphone permission, then check `~/.whisper_puma_backend.log`. The hidden turbo fallback should kick in automatically if the primary decode gives nothing.
- **Text won’t paste**: ensure Accessibility is granted; otherwise, use clipboard mode and paste manually.
- **Hotkey feels off**: Fn is purposefully hold-only. If you switch to another trigger, double-tap mode lets you stop/pause cleanly.

## Logs

- Backend: `~/.whisper_puma_backend.log`
- History: `~/.whisper_puma_history.log`
