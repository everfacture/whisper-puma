# 🐆 Whisper Puma v1.0.9

A beautiful, native macOS application for unlimited, **100% local** voice dictation. Whisper Puma is optimized for the Apple Silicon era, bringing state-of-the-art transcription to your menu bar with zero latency and absolute privacy.

> [!IMPORTANT]
> **v1.0.9 "Code Hygiene"**: This release focuses on "Native Excellence"—adopting standards for clean, optimal, and efficient code. We've restructured the project, eliminated hardcoded strings, and professionalized our build automation.


## ✨ Features

- **🎙️ Global Dictation** — Trigger high-quality transcription anywhere in macOS with a single keypress.
- **⚡ MLX Framework** — Powered by Apple's machine learning framework for blazing-fast Metal-accelerated inference.
- **🎯 "Turbo" Accuracy** — Uses the `whisper-large-v3-turbo` model for the best balance of accuracy (handles British accents) and speed.
- **🔐 100% Local-First** — Enforces offline mode. No audio or text ever leaves your machine—no cloud, no API keys, no tracking.

- **📟 Puma Pulse HUD** — Real-time visual feedback via a sleek, native HUD that pulses as you speak.
- **⌨️ Custom Hotkey Recorder** — Fully customizable global triggers via a native Swift hotkey recorder.
- **✂️ Smash-Proof Deduplication** — Intelligent algorithms that detect and eliminate recurring duplication errors.
- **🌓 Native Design** — Modern, glassmorphic Settings window with dark mode support.

## 📋 Prerequisites & Requirements

- **macOS 14.0** (Sonoma) or later.
- **Apple Silicon (M1, M2, M3, M4)** — Required for MLX performance.
- **Python 3.9+** installed and available in your `PATH`.
- **ffmpeg** installed (for audio processing).

## 🚀 Quick Start

1. **Clone & Enter:**
   ```bash
   git clone https://github.com/everfacture/whisper-puma.git
   cd whisper-puma
   ```

2. **Backend Setup:**
   ```bash
   pip install -r src/backend/requirements.txt
   ```

3. **Build the App:**
   ```bash
   ./scripts/build_app.sh
   ```

4. **Launch & Model Sync:**
   ```bash
   open build/WhisperPuma.app
   ```
   > [!IMPORTANT]
   > **First Run**: The very first time you record, the app will automatically download the **Whisper Large-v3-Turbo** model (~1.5GB). This only happens once. After the download is complete, the app enters **Permanent Offline Mode**.
   >
   > **Permissions**: macOS will request **Microphone** and **Accessibility** access. You MUST grant these for global hotkeys and text insertion to work.


## 🗺️ Roadmap & Future Improvements

### 🐆 Short Term (v1.1)
- **4-bit Quantization**: Support for quantized MLX models for even lower memory footprint and faster startups.
- **Smart Punctuation**: Enhanced NLP logic for better sentence structuring in long dictations.
- **Tray Animations**: Smooth, high-refresh rate animations for the menu bar icon.

### 🧠 Medium Term (v1.x)
- **Context-Aware Formatting**: Auto-switch styles based on the active app (e.g., Markdown for Obsidian, Swift-friendly for Xcode).
- **Voice Commands**: "New paragraph", "Delete last sentence", and "Capitalize that" commands.
- **LLM Refinement**: Optional local Llama-3 integration for instant "Professional Polish".

### 🌐 Long Term
- **Multi-Language Mastery**: Seamless switching between 99+ languages with zero config.
- **Windows Puma**: Bringing the same local-first performance to Windows via ONNX/DirectML.

## 👨‍💻 Architecture & Hygiene

- **Repository Structure**: Following industry standards with dedicated `scripts/`, `build/`, and `logs/` directories.
- **Native Excellence**: Optimized Swift process management and centralized `Constants.swift` to avoid magic strings and paths.
- **100% Offline Enforcement**: Logic-level bypasses for Hugging Face Hub connectivity checks.

---
*Voice is the new keyboard. 🐆*
