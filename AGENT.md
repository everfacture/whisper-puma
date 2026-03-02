# AGENT.md

## Project purpose
Whisper Puma is a local-first macOS dictation app that captures speech with a global hotkey and inserts formatted text into the active app.  
It prioritizes low-latency transcription, punctuation quality, and reliable direct typing/clipboard fallback.

## Directory map
- `src/ui/` — Swift macOS app (hotkey, recording UX, insertion, settings, history)
- `src/backend/` — Python local daemon (streaming transcription + punctuation restore)
- `scripts/` — build/run scripts
- `docs/` — specs and release notes
- `build/` — local app artifacts

## Active mode and why
`SHIP` — focus is shipping reliable dictation behavior (punctuation + latency + stability) with minimal reversible changes.

## Stack decisions already made
- macOS UI: Swift/AppKit for native hotkey and input simulation reliability.
- Backend: Python + `mlx-whisper` for local Apple Silicon transcription.
- Primary model policy: `mlx-community/whisper-large-v3-mlx`; turbo used as internal fallback for reliability.
- Optional bounded local polish in UI (`qwen2.5:3b-instruct`) with strict timeout and drift safety checks.
- Local punctuation restoration service with confidence gating and fallback safeguards.

## Test command
- Backend syntax check: `python3 -m compileall src/backend`
- App build sanity check: `./scripts/build_app.sh`

## Deploy command
- Local ship artifact: `./scripts/build_app.sh`
- Run app: `open build/WhisperPuma.app`
- Noob release artifacts: `./scripts/package_release.sh` (creates `.zip` + `.dmg` in `dist/`)
- CI release path: push tag `v*` to run `.github/workflows/release.yml`

## Permission zones (repo-specific)
- Move freely: `docs/`, `README.md`, `CHANGELOG.md`, `scripts/`, `src/ui/`, `src/backend/`
- Move with tests/build: any change under `src/ui/` or `src/backend/` must run compile/build checks above
- Never touch: `.git/`, secrets, credentials, external lockfiles unless explicitly requested

## Known issues
- Primary MLX cache path may fail warmup on some machines; runtime auto-falls back to turbo.
- Punctuation model can intermittently fail inference on some segment lengths; fallback punctuation path is used.
- Fast repeated Fn taps can still cause user-visible cancellation logs despite empty-session guards.

## What “done” looks like
- Dictation captures consistently without dropped sessions.
- Inserted text is readable with stable punctuation and paragraph/list formatting.
- No regressions in build/compile checks.
- README and changelog reflect shipped behavior.
