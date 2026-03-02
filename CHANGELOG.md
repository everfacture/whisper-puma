# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-02-01
### Added
- Local punctuation restoration service (`src/backend/punctuation_service.py`) with sanity checks and confidence thresholds to prevent low-quality punctuation outputs.
- Automatic punctuation cleanup pass to normalize awkward punctuation artifacts (for example `before,.` and misplaced commas in short phrases).
- Release packaging script (`scripts/package_release.sh`) to generate no-terminal install artifacts (`.zip` and `.dmg`).

### Changed
- Stream decode startup now auto-falls back to turbo when the primary MLX cache path is unavailable, improving first-run reliability.
- Spoken formatting command handling now includes command-phrase normalization and literal-mention detection, so phrases like “when I say new paragraph” are preserved as content.
- Build system can now bundle a local Python runtime into the app (`WHISPER_PUMA_BUNDLE_PYTHON=1`) for noob-friendly installation.
- README now includes explicit support matrix (macOS/Apple Silicon requirements and unsupported platforms).

### Fixed
- Empty/no-audio hotkey sessions are now discarded before transcript submission, reducing false “no speech/cancelled” errors.
- Long-form formatting stability improved for paragraph/list rendering and punctuation post-processing consistency.
- Install command in `README.md` updated to `python3 -m pip` for environments without `pip` on PATH.

## [1.2.0] - 2026-02-26
### Added
- Hybrid punctuation pipeline: deterministic spoken-command formatting plus bounded local LLM polish (`qwen2.5:3b-instruct`, `>20` words, `250ms` timeout).
- Long-form accuracy-first finalize behavior retained with full-final decode up to 30 seconds.
- Structured history entries (JSONL with timestamps) and refreshed history window layout.

### Changed
- Fn trigger policy is now hard-locked to **Hold to Talk**.
- One-model public policy: `mlx-community/whisper-large-v3-mlx`.
- Settings UI refreshed for production readability and to remove ambiguous model selection.

### Fixed
- Model alias canonicalization to avoid repo mismatch (`whisper-large-v3*` legacy IDs now map to canonical `large-v3-mlx`).
- Double-tap mode for non-Fn triggers now has deterministic stop behavior (second tap within threshold stops active recording).
- Accidental short Fn taps no longer create unintended recording sessions (hold activation delay).

### Migration Notes
- Existing saved model IDs are auto-mapped to `mlx-community/whisper-large-v3-mlx`.
- Turbo model remains available internally as hidden rescue only when primary final decode is empty.

## [1.0.9] - 2026-02-24
### Added
- **Architecture & Stability**: Restructured repository into `scripts/`, `build/`, and `logs/` folders.

- **Puma Pulse HUD**: Real-time native visual feedback during recording.
- **Native Hotkey Recorder**: Global hotkey customization in the Settings window.
- **Centralized Constants**: Switched to `Constants.swift` for unified app configuration.

### Changed
- **The Great Pivot**: Standardized on `mlx-community/whisper-large-v3-turbo` for high-speed, accurate British English transcription.
- **Offline Perfection**: Implemented absolute-path model loading to bypass all cloud checks.
- **Greedy Decoding**: Enforced `beam_size=1` for maximum stability and no hallucinations.
- **Native Process Management**: Swift backend orchestration now uses native `Process` execution instead of shell wrappers.

### Fixed
- Resolved "Empty Backend" issue caused by `mlx-whisper` API misuse.
- Fixed infinite word-repetition loops with optimized decoding parameters.
- Cleaned up root directory from build artifacts and logs.

### Technical
- Updated `.gitignore` for professional macOS/Xcode/Python development.
- Purged legacy Ollama/Llama dependencies.

## [0.9.0] - 2026-02-24

### Added
- **Native macOS Menu Bar App**: A standalone Swift application (`PumaMenuBarApp`) that handles global `fn` key hooks and audio capture.
- **Python Backend Daemon**: A persistent HTTP backend that orchestrates the STT pipeline using MLX.
- **MLX Whisper Support**: Integrated `mlx-whisper` for high-performance transcription on Apple Silicon.
- **Ultra-Accurate Model**: Added support for `distil-whisper-large-v3` with optimized local caching.
- **Multi-Layer Pasting**: Robust text injection via `CGEvent` and AppleScript fallbacks.
- **Thought Log**: Automatic persistent history of dictations saved to `~/.whisper_puma_history.log`.

### Fixed
- Resolved `URLSession` timeout issues for large model downloads.
- Improved app reactivation logic to ensure text is pasted into the correct application.
- Optimized backend warmup process to reduce first-transcription latency.

### Removed
- Removed legacy Ollama dependencies in favor of direct high-speed MLX transcription.
