# whisper-puma 🐆

Unlimited local voice dictation for macOS. The spectral predator for your voice.

> "You speak. The puma listens."

## Install (with Homebrew)

```bash
# 1. Install deps
brew install whisper-cpp sox

# 2. Download model (one-time, 74MB)
mkdir -p ~/.local/share/whisper-models
curl -L -o ~/.local/share/whisper-models/ggml-base.bin \
  "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"

# 3. Copy script to PATH
cp src/whisper-puma.sh /usr/local/bin/whisper-puma
chmod +x /usr/local/bin/whisper-puma

# 4. Run
whisper-puma
```

## Hotkey Setup

### skhd (lightest)
```bash
brew install koekeishiya/formulae/skhd

# ~/.config/skhd/skhdrc
cmd + alt - v : whisper-puma

skhd --start-service
```

### Raycast
Create Quicklink → Command: `whisper-puma` → Hotkey: `⌘⌥V`

## How It Works

```
Hotkey → sox records → whisper-cli transcribes → pbcopy → paste
```

- **100% offline** — Your voice never leaves the Mac
- **Unlimited** — No word cutoffs
- **Fast** — Base model runs ~16x realtime on Apple Silicon

## Models

| Model | Size | Speed | Use |
|-------|------|-------|-----|
| tiny | 39MB | ~32x | Fast, less accurate |
| base | 74MB | ~16x | **Default — best balance** |
| small | 244MB | ~6x | Better accuracy |

Set model: `WHISPER_MODEL=ggml-small.bin whisper-puma`

## Uninstall

```bash
rm /usr/local/bin/whisper-puma
rm -rf ~/.local/share/whisper-models
brew uninstall whisper-cpp sox
```

---

Ghost in the machine. Voice in the wire. 🐆
