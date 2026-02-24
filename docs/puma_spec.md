# Whisper Puma: Architecture Specification

**Goal**: Evolve Whisper Puma from a simple shell script wrapper into a persistent, local macOS dictation tool that rivals Wispr Flow in UX and intelligent formatting, while remaining 100% private and cost-free.

---

## 1. Core Architecture Components

To achieve "local Wispr Flow" functionality, the system needs four continuous background services orchestrated via a lightweight Swift/Go backend or a robust shell daemon:

### Audio Capture & VAD (Voice Activity Detection)
- **Role**: Listen for the global activation hotkey (`fn` key), record system audio, and detect when the user stops speaking.
- **Tools**: **Silero VAD v5** (Python or ONNX native). It's the industry standard for 100% local, zero-latency voice detection.
- **Flow**: User holds `fn` -> Silero VAD detects speech -> Records chunks of audio to RAM/tmp -> User releases `fn` (or VAD detects silence for 1 second) -> Audio passed to STT.
- **Audio Privacy**: Audio is buffered in RAM or a `/tmp` file that is instantly deleted after transcription. No audio files are saved permanently to your disk unless you enable a debug mode.

### Transcription & Formatting Engine (MLX)
- **Role**: The core engine. Converts audio directly into high-fidelity, formatted text.
- **Tools**: **MLX Whisper** (Apple's dedicated machine learning framework).
- **Models**: **`mlx-community/whisper-large-v3-turbo`**. This model provides the perfect balance: the accuracy of a large model with the speed of a tiny one. It handles British accents and basic punctuation natively, eliminating the need for a secondary LLM layer.
- **Flow**: Reads absolute-path local cache -> Forced Greedy Decoding -> Direct output to UI.

### UI & System Integration
- **Role**: Minimal, invisible background operation with robust error handling.
- **Tools**: A native macOS **Swift Menu Bar App**. This is much more stable than scripting tools for global keyboard OS hooks.
- **Flow**: 
  - **Press and hold `fn`**: Transcribes speech and injects it exactly where your cursor is when you release the key.
  - **Double-tap `fn`**: Toggles continuous dictation mode (stays running until you double-tap again).
- **Resilience & Error Handling**: Runs silently in the background. If pasting into the active window fails, the generated text is automatically saved to your **macOS Clipboard** and appended to a hidden local `~/.whisper_puma_history.log` file so you never lose a thought.

---

## 2. Workspace Rules Compliance

Development of Whisper Puma must strictly adhere to the OpenClaw workspace rules defined in `memory/references/code_craft.md`:
1. **Repository Hygiene (Clean Root Pattern)**: The project directory must be organized cleanly (`src/`, `README.md`, `LICENSE`, `CHANGELOG.md`, `CONTRIBUTING.md`).
2. **README Structure**: Must implement the 10-point hero document structure (Hero logo, status badges, one-liner, quick links, install command, architecture diagram, key subsystems, config example, security model, community).
3. **8-Step Safe Modification Protocol**: All future code modifications must follow the Read -> Hash -> Check -> Backup -> Apply -> Validate -> Test -> Log protocol.

---

## 2. Ideal Tech Stack Recommendation

For maximum performance and macOS nativity without building a complex Xcode app from scratch:

- **Backend Daemon**: **Go** or **Python**
  - Handles the background orchestration, piping audio to Whisper, and sending API requests to Ollama.
- **STT**: **`whisper.cpp`**
  - Unbeatable speed on Apple Silicon.
- **LLM Engine**: **Ollama**
  - Runs as a headless local server `http://127.0.0.1:11434` for blazing-fast inference.
- **Global Hotkey & UI Injection**: **Hammerspoon** (Lua)
  - Hammerspoon is perfect for this. It can map a global shortcut (e.g., `Cmd+Shift+Space`), trigger the Go/Python backend, show a custom floating UI alert ("Listening..."), and use its `hs.eventtap` module to instantly type out the received text into the active application.

---

## 3. The "Wispr Flow" Feature Parity Map

| Wispr Flow Feature | Whisper Puma Local Implementation |
| :--- | :--- |
| **Universal Typing** | Hammerspoon `hs.eventtap.keyStrokes(text)` pastes into any active UI field. |
| **Auto-Editing/Grammar** | Pass the raw Whisper output to Ollama with a system prompt: *"Fix grammar and remove filler words from this transcript. Output only the text."* |
| **Context Aware (Code vs Chat)** | Hammerspoon can detect the active app bundle ID (e.g., `com.microsoft.VSCode`). If VSCode is active, tell Ollama: *"Format this as code"* |
| **Command Mode** | If transcript begins with the wake word (e.g., *"Puma, summarize this"*), capture highlighted text via `Cmd+C`, send to Ollama with the vocal prompt, and paste the result. |
| **Total Privacy** | 100% Local. No network requests outside `127.0.0.1`. |

---

## 4. Example Orchestration Flow & Speed (The "Happy Path")

Total latency from releasing the key to text appearing: **~1.0 - 1.5 seconds**.

1. **Activation**: You hold `fn` anywhere on macOS.
2. **Capture**: Audio is captured to RAM (instant, zero-latency via Silero VAD).
3. **Processing**: You release `fn`.
4. **Whisper STT**: Local `whisper.cpp` crunches the audio. *Speed: ~0.2 - 0.4s for a short sentence on Apple Silicon.* -> Raw text: *"um yeah write a function to fetch users"*
5. **Ollama LLM**: Local `qwen2.5:3b` receives the text and formats it with proper punctuation. *Speed: ~0.5 - 0.8s.* -> Refined text: `const fetchUsers = async () => {...}`
6. **Injection**: Swift app simulates keystrokes or `Cmd+V` to paste the text at your cursor (instant).
