# Whisper Puma v2 Implementation Plan

Evolving the current shell script wrapper into a fully local, AI-assisted macOS dictation tool that rivals Wispr Flow.

## User Review Required

> [!CAUTION]
> This plan proposes creating a native macOS app using Swift for the UI and global keyboard hooks (`fn` key). Since you are running on a Linux system (as per your OS fingerprint), we cannot compile or test a native macOS Swift app locally in this environment. 
> 
> **Question**: Do you want me to write the Swift code and Go/Python backend for you to compile on your Mac later, or should we stick to a pure Python/Shell implementation that we can at least partially test here?

---

## Proposed Changes

We will refactor the `whisper-puma` project directory to adhere strictly to the **Clean Root Pattern** defined in `code_craft.md`.

### Project Structure (Clean Root Pattern)

#### [NEW] `projects/whisper-puma/src/ui/`
- `PumaMenuBarApp.swift`: A minimal macOS menu bar app that registers the global `fn` key shortcut (single tap and double tap) using the `NSEvent` global monitor. It will trigger the backend process and handle pasting the clipboard into the active application.

#### [NEW] `projects/whisper-puma/src/backend/`
- `main.py` or `main.go`: The orchestration daemon.
  - Interfaces with **Silero VAD** for zero-latency audio capture.
  - Passes audio to `whisper.cpp` (using the `distil-whisper-large-v3` model).
  - Sends the raw transcript to a local `ollama` instance running **Llama 3.2 3B** with a systemic prompt for grammar and formatting.
  - Copies the final formatted text to the macOS clipboard and appends to `~/.whisper_puma_history.log`.

#### [MODIFY] `projects/whisper-puma/README.md`
- Rewrite the README to match the exact 10-point hero document structure required by `code_craft.md` (Logo, Badges, Value Prop, Install Command, Architecture Diagram, etc.).

#### [NEW] `projects/whisper-puma/CHANGELOG.md`
- Initialize the changelog for v2.0.

#### [NEW] `projects/whisper-puma/CONTRIBUTING.md`
- Standard contribution guidelines.

#### [NEW] `projects/whisper-puma/LICENSE`
- Add an MIT license.

---

## Verification Plan

### Automated Tests
- We will write unit tests for the backend orchestrator (mocking the audio input and LLM responses to verify the formatting logic and fallback clipboard logic).

### Manual Verification
- Because the core UI requires macOS (Swift/AppKit), manual verification of the `fn` key hook and UI pasting will have to be performed by the User on their Mac.
- We will provide explicit `xcodebuild` or `swift build` instructions for compilation.
