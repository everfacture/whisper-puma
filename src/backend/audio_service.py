import os
import subprocess
import threading
import glob
from logger_service import LoggerService

class AudioService:
    def __init__(self, logger: LoggerService):
        self.logger = logger
        self.whisper_ready = False
        self._mlock = threading.Lock()
        # 🎯 THE GREAT PIVOT (v1.0.8): Hardcoded, 100% local, stable.
        self.repo_id = "mlx-community/whisper-large-v3-turbo"
        self.model_path = self._get_local_model_path()

    def _get_local_model_path(self) -> str:
        """Finds the absolute path to the cached model to bypass cloud checks."""
        cache_base = os.path.expanduser("~/.cache/huggingface/hub")
        folder_pattern = f"models--{self.repo_id.replace('/', '--')}"
        search_path = os.path.join(cache_base, folder_pattern, "snapshots", "*")
        
        matches = glob.glob(search_path)
        if matches:
            # Return the latest snapshot path
            latest = sorted(matches)[-1]
            self.logger.info(f"Local model found at: {latest}")
            return latest
        
        self.logger.warning(f"No local cache found for {self.repo_id}. Will attempt download on first run.")
        return self.repo_id

    def preload_models(self) -> None:
        self.logger.info("Warming up MLX Whisper model in background...")
        try:
            import mlx_whisper
            import numpy as np
            # Dummy silence to force compilation
            dummy_audio = np.zeros(16000, dtype=np.float32)
            
            with self._mlock:
                # Use the absolute path if we found one
                mlx_whisper.transcribe(dummy_audio, path_or_hf_repo=self.model_path)
            
            self.whisper_ready = True
            self.logger.info("MLX Whisper warmup complete.")
        except Exception as e:
            self.logger.error(f"Could not preload MLX Whisper: {e}")

    def transcribe_audio(self, file_path: str) -> str:
        try:
            import mlx_whisper
            
            self.logger.info(f"Transcribing (v1.0.8) with {self.repo_id}...")
            
            # 🔥 STABILITY FIX: Use correct mlx_whisper.transcribe signature.
            # No 'model=' or 'local_files_only=' here - they aren't supported by high-level API.
            # We pass self.model_path (absolute path) to bypass cloud checks.
            with self._mlock:
                result = mlx_whisper.transcribe(
                    file_path, 
                    path_or_hf_repo=self.model_path,
                    temperature=0.0,  # Force greedy for stability
                    condition_on_previous_text=False # Prevent failure loops
                )
            
            text = result["text"].strip()
            if not text:
                return ""

            # ✂️ SMASH-PROOF DEDUPLICATION
            l = len(text)
            if l >= 10 and l % 2 == 0:
                half = l // 2
                if text[:half] == text[half:]:
                    self.logger.info("Deduplication: Caught exact string doubling.")
                    return text[:half].strip()
            
            words = text.split()
            if len(words) >= 4 and len(words) % 2 == 0:
                half_w = len(words) // 2
                if words[:half_w] == words[half_w:]:
                    self.logger.info("Deduplication: Caught perfect word-level repeat.")
                    return " ".join(words[:half_w])

            return text

        except Exception as e:
            self.logger.error(f"mlx_whisper (v1.0.8) failed: {e}")
            return ""

    def get_available_models(self):
        return ["whisper-large-v3-turbo"]
