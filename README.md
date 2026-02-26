# Whisper Puma v1.2.0

Accuracy-first, local-first dictation for macOS menu bar.

## What v1.2.0 ships

- `Fn` trigger is **hold-to-talk only** (no toggle or double-tap on Fn).
- One public model policy: **`mlx-community/whisper-large-v3-mlx`**.
- Hidden reliability fallback: **turbo rescue** (`mlx-community/whisper-large-v3-turbo`) only when final decode is empty.
- Hybrid punctuation pipeline:
  - Stage A deterministic formatting and spoken commands.
  - Stage B optional bounded local LLM polish (`qwen2.5:3b-instruct`, only for `>20` words, hard timeout `250ms`).
- Direct typing insertion first, clipboard fallback second.

## Requirements

- macOS 14+ on Apple Silicon.
- Python 3.9+ in `PATH`.
- Optional for Stage B polish: Ollama with `qwen2.5:3b-instruct`.

## Quick Start

```bash
git clone https://github.com/everfacture/whisper-puma.git
cd whisper-puma
pip install -r src/backend/requirements.txt
./scripts/build_app.sh
open build/WhisperPuma.app
```

## Permissions (required)

1. Microphone: `System Settings -> Privacy & Security -> Microphone`
2. Accessibility: `System Settings -> Privacy & Security -> Accessibility`

Without Accessibility, direct typing is blocked and Whisper Puma falls back to clipboard copy.

## Hotkey Policy

- Default trigger is `Fn`.
- When trigger is `Fn`, recording mode is locked to `Hold to Talk`.
- Toggle and Double Tap are available only for non-Fn triggers.

This avoids common macOS Fn tap side-effects (for example input/language switching) and accidental tap sessions.

## Punctuation and Commands

Deterministic command handling supports:

- `comma`, `period` / `full stop`, `question mark`, `exclamation mark`
- `new line`, `new paragraph`
- `bullet point`
- `numbered list`, `point one/two/three/four/five`

If no explicit command language is present and transcript is long enough, bounded local polish can refine punctuation.

## Latency and Accuracy Notes

- Short notes (2-6s): typically fastest.
- Medium/long notes: accuracy is prioritized via full-final decode (up to 30s path).
- Release-to-insert depends on hardware load and whether local polish is enabled.

## Troubleshooting

### Empty transcript

- Confirm microphone permission.
- Check backend log: `~/.whisper_puma_backend.log`
- If primary decode is empty, turbo rescue should run automatically.

### Text not inserted

- Confirm Accessibility permission.
- If insertion target blocks keystroke typing, app falls back to clipboard + `Cmd+V`.

### Model cache problems

- Ensure local cache exists for `mlx-community/whisper-large-v3-mlx`.
- Legacy model IDs are auto-mapped to the v1.2.0 canonical model.

## Logs

- Backend: `~/.whisper_puma_backend.log`
- History: `~/.whisper_puma_history.log`
