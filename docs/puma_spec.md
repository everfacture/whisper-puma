# Whisper Puma v1.2.0 Specification

## Product Direction

Whisper Puma v1.2.0 is an accuracy-first, local-first dictation app for macOS with a stable `Fn` hold workflow and fast insertion.

## Locked Decisions

1. `Fn` trigger is hold-to-talk only.
2. Public model policy is one model: `mlx-community/whisper-large-v3-mlx`.
3. Hidden reliability fallback is `mlx-community/whisper-large-v3-turbo` only when primary final decode is empty.
4. Insertion strategy is direct typing first, clipboard fallback.
5. Formatting pipeline is local hybrid: deterministic rules, then bounded local LLM polish.

## Runtime Flow

1. User holds trigger key.
2. UI opens stream session over WebSocket (`/stream`).
3. UI sends PCM16 chunks while recording.
4. Backend produces rolling partials for live feedback.
5. On release, backend finalizes transcript and returns final text.
6. UI runs deterministic formatting.
7. Optional bounded polish runs for long transcripts only (`>20` words, `250ms` timeout).
8. Text is inserted with direct typing; fallback uses clipboard paste and clipboard restore.
9. Transcript is written to local history (`~/.whisper_puma_history.log`).

## Accuracy and Latency Strategy

- Partial decode is used for responsiveness only.
- Final output prioritizes full-final decode for normal-length clips (up to 30 seconds).
- Reconcile and fallback passes exist for edge cases.
- Turbo rescue is only invoked on empty primary final result.

## Hotkey Behavior

- If trigger key is `Fn` (`keyCode 63`), effective mode is forced to `Hold to Talk`.
- Non-Fn keys can use Hold/Toggle/Double Tap.
- Double Tap on non-Fn keys supports deterministic stop on second tap within threshold.
- Very short accidental sessions are discarded.

## Formatting Pipeline

### Stage A (always on)

- Spoken punctuation commands (`comma`, `period`, `new line`, etc.)
- Spoken list commands (`bullet point`, `numbered list`, `point one/two/...`)
- Disfluency and spacing cleanup
- Sentence boundary normalization

### Stage B (bounded local polish)

- Model: `qwen2.5:3b-instruct` via local Ollama
- Trigger: transcript length `>20` words
- Timeout: `250ms` hard limit
- Failure mode: fall back to Stage A output unchanged
- Command-priority guard: explicit spoken commands bypass LLM overwrite

## Known Limitations (Current)

- Punctuation for long disfluent speech remains best-effort and may need future tuning.
- Proper noun/entity recall can degrade with noisy background audio.
- The 250ms polish guard favors latency predictability over deep rewriting quality.

## Observability

- Backend log: `~/.whisper_puma_backend.log`
- History log: `~/.whisper_puma_history.log`
- Settings latency badge displays last / p50 / p95 release-to-insert samples.

## Release Notes Source of Truth

- Product behavior: `README.md`
- Change summary: `CHANGELOG.md`
