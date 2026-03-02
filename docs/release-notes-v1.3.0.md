# Whisper Puma v1.3.0 Release Notes

## Highlights

- Improved dictation reliability with automatic fallback to turbo when primary model warmup/decode fails.
- Added local punctuation restoration service with confidence and sanity gating.
- Added punctuation artifact cleanup for awkward outputs (for example `before,.` and misplaced commas).
- Better spoken-structure handling for `new line`, `new paragraph`, bullets, and list phrases.
- Added no-terminal packaging flow for end users (`.zip` + `.dmg`) and CI release automation.

## Changes by Area

### Reliability and Latency

- Empty/no-audio sessions are discarded before transcript finalization.
- Backend decode path auto-switches to turbo when primary cache decode is unavailable.
- Startup behavior now better matches real-world first-run constraints.

### Formatting and Punctuation

- New backend punctuation service (`speechbox`) with:
  - word overlap and sequence sanity checks
  - confidence thresholds (`log_prob` + per-word)
  - safe fallback to deterministic punctuation on model mismatch/failure
- UI formatting pipeline now includes:
  - command-phrase normalization
  - literal command mention detection (prevents destructive rewrites in phrases like “when I say new paragraph”)
  - punctuation artifact cleanup pass

### Packaging and Distribution

- New script: `scripts/package_release.sh`
  - builds bundled app with embedded Python runtime
  - outputs:
    - `dist/WhisperPuma-<version>-macOS.zip`
    - `dist/WhisperPuma-<version>-macOS.dmg`
- New GitHub Actions workflow: `.github/workflows/release.yml`
  - runs on tag push (`v*`)
  - builds macOS artifacts and publishes them to Releases

## Platform Support

- Supported: macOS 14+ on Apple Silicon (`arm64`: M1/M2/M3/M4)
- Not supported in prebuilt release: Windows, Linux, Intel macOS builds

## Validation Performed

- Backend compile check: `python3 -m compileall src/backend`
- App build: `./scripts/build_app.sh`
- Packaging smoke run: `./scripts/package_release.sh <version>`
