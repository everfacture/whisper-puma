# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

