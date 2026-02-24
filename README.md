# 🐆 Whisper Puma v0.9

A beautiful, native macOS menu bar application for unlimited, 100% local voice dictation. Powered by `mlx-whisper` for blazing-fast performance on Apple Silicon.

## ✨ Features

- **🎙️ Global Dictation** — One-tap high-quality transcription from any application.
- **⚡ Supercharged by MLX** — Uses Apple's MLX framework for state-of-the-art performance on Metal.
- **🎯 Elite Accuracy** — Defaults to `distil-whisper-large-v3` for professional-grade accuracy and accent handling.
- **🔐 100% Private & Offline** — No audio or text ever leaves your machine. No cloud, no API keys, no tracking.
- **⌨️ Seamless Insertion** — Automatically types transcribed text directly into your active window.
- **🌓 Native UI** — Lightweight system-integrated menu bar app with dark mode support.
- **📜 Thought Log** — Automatically saves a local history of your dictations in `~/.whisper_puma_history.log`.

## 🚀 Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/everfacture/whisper-puma.git
   cd whisper-puma
   ```

2. **Install Backend Dependencies:**
   ```bash
   pip install -r src/backend/requirements.txt
   ```

3. **Build & Run the App:**
   ```bash
   ./src/ui/build_app.sh
   open src/ui/WhisperPuma.app
   ```

4. **Permissions:**
   Grant Microphone and Accessibility permissions when prompted. The app uses the **Function (fn)** key by default.

## 🏗️ Architecture

Whisper Puma uses a decoupled architecture to ensure the UI remains responsive while the heavy lifting happens in the background.

- **Frontend (Swift 6)**: A native AppKit application that handles global hotkeys, high-fidelity audio recording, and UI feedback.
- **Backend (Python 3.12/MLX)**: A local HTTP daemon that manages the `distil-whisper-large-v3` model and processes audio buffers via the Metal GPU.
- **Pasting Engine**: A multi-layered system using `CGEvent` and AppleScript to ensure reliable text injection across different macOS sandboxes.

## 📋 Requirements

- **macOS 14.0** (Sonoma) or later.
- **Apple Silicon (M1, M2, M3, M4)** — Required for MLX performance.
- Python 3.9+ installed.

## 🔐 Privacy & Security

- **Local Processing**: Audio transcription happens entirely on your GPU.
- **No Analytics**: We don't collect, track, or phone home. Ever.
- **Secure Handling**: Audio buffers are written to ephemeral storage (`/tmp/`) and overwritten immediately.

## 🎉 Roadmap

Whisper Puma is evolving. Here is what's coming next:

- **⚙️ Settings Menu**: In-app UI for changing models and adjusting audio settings.
- **⌨️ Key Customization**: Capability to remap the global trigger from `fn` to any preferred hotkey.
- **🏎️ Performance +**: Support for 4-bit and 8-bit quantized models for even faster processing on base M1 chips.
- **🪟 Windows Support**: Exploring a companion app for Windows using `whisper.cpp` or `faster-whisper`.
- **✍️ Advanced Formatting**: Optional local LLM integration for punctuation and grammar correction via Ollama.

## 👨‍💻 About

Created with ❤️ to bring unrestricted, professional dictation to everyone.

*Voice is the new keyboard. 🐆*

