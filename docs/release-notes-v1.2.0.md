# Whisper Puma v1.2.0 Release Notes

## Highlights

- Accuracy-first release model is now fixed to `mlx-community/whisper-large-v3-mlx`.
- `Fn` is now hold-to-talk only for stable, predictable behavior on macOS.
- Hybrid local formatting pipeline added:
  - deterministic punctuation/list command handling
  - optional bounded local polish (`qwen2.5:3b-instruct`, `250ms` guard)
- Insertion is direct typing first, clipboard fallback second.
- Settings and History windows are redesigned for cleaner readability.

## Changes by Area

### Hotkey and Recording

- Fn trigger forcibly uses Hold to Talk.
- Non-Fn Double Tap mode now supports deterministic stop on second tap.
- Short accidental tap sessions are filtered out.

### Transcription Model Policy

- Public model list now contains one release model: `mlx-community/whisper-large-v3-mlx`.
- Legacy model IDs are normalized to this canonical model.
- Hidden turbo rescue is retained for reliability when final primary decode is empty.

### Formatting

- Spoken commands for punctuation and list structure are handled in deterministic pass.
- Long transcripts can receive bounded local polish when command-priority guard allows.

### UX

- Settings UI now clearly communicates fixed model policy and Fn constraints.
- History UI now supports cleaner card layout, search, and timestamped entries.

## Known Limitations

- Long, disfluent speech punctuation remains best-effort and may still need manual edits.
- Entity-heavy dictation with noisy background audio can still drop or alter names.

## Validation Performed

- Backend compile check: `python3 -m compileall src/backend`
- App build: `./scripts/build_app.sh`
