import os
import re
import threading
from collections import Counter
from difflib import SequenceMatcher
from typing import List, Optional

import numpy as np

from logger_service import LoggerService


class PunctuationService:
    def __init__(self, logger: LoggerService):
        self.logger = logger
        self.enabled = os.getenv("PUMA_PUNCTUATION_ENABLED", "1").lower() not in {"0", "false", "no", "off"}
        self.model_id = os.getenv("PUMA_PUNCTUATION_MODEL", "openai/whisper-tiny.en")
        self.num_beams = max(1, int(os.getenv("PUMA_PUNCTUATION_BEAMS", "1")))
        self.min_words = max(1, int(os.getenv("PUMA_PUNCTUATION_MIN_WORDS", "8")))
        self.max_audio_seconds = max(5.0, float(os.getenv("PUMA_PUNCTUATION_MAX_AUDIO_SECONDS", "75")))
        self.min_log_prob = float(os.getenv("PUMA_PUNCTUATION_MIN_LOG_PROB", "-80"))
        self.min_log_prob_per_word = float(os.getenv("PUMA_PUNCTUATION_MIN_LOG_PROB_PER_WORD", "-2.0"))

        self._restorer = None
        self._device = "cpu"
        self._model_loaded = False
        self._model_failed = False
        self._lock = threading.Lock()

        if not self.enabled:
            self.logger.info("Local punctuation model disabled via PUMA_PUNCTUATION_ENABLED=0.")

    def _resolve_device(self) -> str:
        try:
            import torch

            if torch.cuda.is_available():
                return "cuda"
            if hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
                return "mps"
        except Exception:
            pass
        return "cpu"

    def _load_model(self) -> None:
        if not self.enabled or self._model_loaded or self._model_failed:
            return

        with self._lock:
            if not self.enabled or self._model_loaded or self._model_failed:
                return

            try:
                from speechbox import PunctuationRestorer

                device = self._resolve_device()
                restorer = PunctuationRestorer.from_pretrained(self.model_id)
                restorer.to(device)

                self._restorer = restorer
                self._device = device
                self._model_loaded = True
                self.logger.info(
                    f"Local punctuation model ready ({self.model_id}) on {device} with beams={self.num_beams}."
                )
            except Exception as e:
                self._model_failed = True
                self.logger.warning(
                    "Could not load local punctuation model. "
                    "Install backend extras: pip install -r src/backend/requirements.txt. "
                    f"Error: {e}"
                )

    def preload_model(self) -> None:
        self._load_model()

    def _normalize_words(self, text: str) -> List[str]:
        reduced = re.sub(r"[^a-z0-9']+", " ", (text or "").lower()).strip()
        if not reduced:
            return []
        return reduced.split()

    def _passes_sanity_checks(self, source: str, candidate: str) -> bool:
        source_words = self._normalize_words(source)
        candidate_words = self._normalize_words(candidate)
        if not source_words or not candidate_words:
            return False

        max_len_delta = max(2, int(len(source_words) * 0.20))
        if abs(len(candidate_words) - len(source_words)) > max_len_delta:
            return False

        if len(candidate_words) < int(len(source_words) * 0.85):
            return False

        overlap = sum((Counter(source_words) & Counter(candidate_words)).values())
        coverage = overlap / max(1, len(source_words))
        if coverage < 0.90:
            return False

        source_flat = " ".join(source_words)
        candidate_flat = " ".join(candidate_words)
        seq_ratio = SequenceMatcher(None, source_flat, candidate_flat).ratio()
        return seq_ratio >= 0.85

    def restore(self, audio: np.ndarray, sampling_rate: int, transcript: str) -> Optional[str]:
        if not self.enabled:
            return None

        normalized = " ".join((transcript or "").split()).strip()
        if not normalized:
            return None

        words = normalized.split()
        if len(words) < self.min_words:
            return None

        if audio is None or getattr(audio, "size", 0) == 0:
            return None

        safe_rate = max(1, int(sampling_rate))
        duration_seconds = float(audio.shape[0]) / float(safe_rate)
        if duration_seconds > self.max_audio_seconds:
            self.logger.info(
                f"Skipping local punctuation model (duration {duration_seconds:.1f}s > {self.max_audio_seconds:.1f}s)."
            )
            return None

        if not self._model_loaded and not self._model_failed:
            self._load_model()

        if not self._model_loaded or self._restorer is None:
            return None

        audio_f32 = np.asarray(audio, dtype=np.float32)
        if audio_f32.ndim > 1:
            audio_f32 = audio_f32.reshape(-1)

        try:
            with self._lock:
                restored, log_prob = self._restorer(
                    audio_f32,
                    normalized,
                    sampling_rate=safe_rate,
                    num_beams=self.num_beams,
                )
        except Exception as e:
            self.logger.warning(f"Local punctuation inference failed, using fallback punctuation. Error: {e}")
            return None

        restored_text = " ".join((restored or "").split()).strip()
        if not restored_text:
            return None

        log_prob_value = float(log_prob)
        log_prob_per_word = log_prob_value / float(max(1, len(words)))
        if log_prob_value < self.min_log_prob or log_prob_per_word < self.min_log_prob_per_word:
            self.logger.warning(
                "Local punctuation output rejected by confidence threshold "
                f"(log_prob={log_prob_value:.3f}, per_word={log_prob_per_word:.3f})."
            )
            return None

        if not self._passes_sanity_checks(normalized, restored_text):
            self.logger.warning("Local punctuation output failed sanity checks, using fallback punctuation.")
            return None

        self.logger.info(
            f"Local punctuation restored ({len(words)} words, log_prob={log_prob_value:.3f}, per_word={log_prob_per_word:.3f}, device={self._device})."
        )
        return restored_text
