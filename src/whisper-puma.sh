#!/bin/bash
# whisper-puma — Local voice dictation for macOS
# Unlimited, free, private. The spectral predator for your voice.

set -e

MODEL_DIR="${HOME}/.local/share/whisper-models"
MODEL="${WHISPER_MODEL:-ggml-base.bin}"
MAX_DURATION="${WHISPER_DURATION:-60}"

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

mkdir -p "$MODEL_DIR"

# Download model if needed
if [[ ! -f "$MODEL_DIR/$MODEL" ]]; then
    echo -e "${YELLOW}📥 Downloading $MODEL...${NC}"
    curl -L --progress-bar "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$MODEL" -o "$MODEL_DIR/$MODEL"
    echo -e "${GREEN}✓ Model ready${NC}"
fi

# Record audio
echo -e "${YELLOW}🎤 Recording... (Ctrl+C to stop)${NC}"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

if command -v rec &>/dev/null; then
    rec -r 16000 -c 1 -b 16 "$TMPDIR/rec.wav" silence 1 0.1 3% 1 3.0 3% 2>/dev/null || true
else
    echo -e "${RED}❌ Install sox: brew install sox${NC}"
    exit 1
fi

[[ -s "$TMPDIR/rec.wav" ]] || { echo -e "${RED}❌ No audio${NC}"; exit 1; }

# Transcribe
echo -e "${YELLOW}🧠 Transcribing...${NC}"
TRANSCRIPT=$(whisper-cli -m "$MODEL_DIR/$MODEL" -f "$TMPDIR/rec.wav" -nt -l en -np 2>/dev/null | tail -n 1)

if [[ -n "$TRANSCRIPT" ]]; then
    echo -e "${GREEN}✓${NC} $TRANSCRIPT"
    echo -n "$TRANSCRIPT" | pbcopy
    echo -e "${GREEN}📋 Copied${NC}"
else
    echo -e "${YELLOW}⚠️ No speech detected${NC}"
fi
