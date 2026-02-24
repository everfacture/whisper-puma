import os
import subprocess
import threading
from logger_service import LoggerService

class AudioService:
    def __init__(self, logger: LoggerService):
        self.logger = logger
        self.whisper_ready = False
        self._mlock = threading.Lock()

    def preload_models(self) -> None:
        self.logger.info("Warming up MLX Whisper model in background...")
        try:
            import mlx_whisper
            import numpy as np
            # Dummy 1-second silent audio at 16000Hz to force compilation
            dummy_audio = np.zeros(16000, dtype=np.float32)
            with self._mlock:
                mlx_whisper.transcribe(dummy_audio, path_or_hf_repo="mlx-community/distil-whisper-large-v3")
            self.whisper_ready = True
            self.logger.info("MLX Whisper warmup complete.")
        except Exception as e:
            self.logger.warning(f"Could not preload MLX Whisper: {e}")

    def transcribe_audio(self, file_path: str) -> str:
        self.logger.info(f"Transcribing {file_path}...")
        try:
            import mlx_whisper
            with self._mlock:
                result = mlx_whisper.transcribe(file_path, path_or_hf_repo="mlx-community/distil-whisper-large-v3")
            return result["text"].strip()
        except Exception as e:
            self.logger.warning(f"mlx_whisper failed: {e}, falling back to whisper-cli")
            return self._transcribe_with_cli(file_path)

    def _transcribe_with_cli(self, file_path: str) -> str:
        model_dir = os.path.expanduser("~/.local/share/whisper-models")
        model = os.environ.get("WHISPER_MODEL", "ggml-base.bin")
        model_path = os.path.join(model_dir, model)
        
        if not os.path.exists(model_path):
            self.logger.error(f"Whisper model not found at {model_path}")
            return ""

        try:
            cmd = ["whisper-cli", "-m", model_path, "-f", file_path, "-nt", "-l", "en", "-np"]
            output = subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode('utf-8')
            lines = output.strip().split("\n")
            return lines[-1].strip() if lines else ""
        except Exception as e:
            self.logger.error(f"whisper-cli failed: {e}")
            return ""
