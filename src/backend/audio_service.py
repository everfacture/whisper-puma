import base64
import glob
import os
import threading
import time
from dataclasses import dataclass
from typing import Dict

import numpy as np

from logger_service import LoggerService


@dataclass
class StreamSession:
    session_id: str
    sample_rate: int
    language: str
    model_repo: str
    model_path: str
    started_at: float
    audio: np.ndarray
    committed_text: str
    next_decode_start: int
    last_partial_decode_at: float
    last_decode_total_samples: int


class AudioService:
    def __init__(self, logger: LoggerService):
        self.logger = logger
        self.whisper_ready = False
        self._mlock = threading.Lock()
        self._sessions: Dict[str, StreamSession] = {}
        self._sessions_lock = threading.Lock()

        self.primary_repo_id = "mlx-community/whisper-large-v3-mlx"
        self.turbo_repo_id = "mlx-community/whisper-large-v3-turbo"
        self.default_repo_id = self.primary_repo_id
        self.primary_model_path = self._resolve_model_path(self.primary_repo_id, canonicalize=False)
        self.turbo_model_path = self._resolve_model_path(self.turbo_repo_id, canonicalize=False)
        self.default_model_path = self.primary_model_path
        self.model_sample_rate = 16000

        # Rolling decode profile
        self.window_ms = 800
        self.overlap_ms = 120
        self.vad_rms_threshold = 0.008
        self.vad_rms_relaxed = 0.003
        self.skip_tail_below_ms = 120
        self.max_tail_decode_ms = 2200
        self.full_finalize_max_seconds = 30.0

    def _canonical_repo_id(self, repo_id: str) -> str:
        if not repo_id:
            return self.primary_repo_id
        aliases = {
            "whisper-large-v3-turbo": "mlx-community/whisper-large-v3-mlx",
            "whisper-large-v3": "mlx-community/whisper-large-v3-mlx",
            "whisper-large-v3-mlx": "mlx-community/whisper-large-v3-mlx",
            "distil-whisper-large-v3": "mlx-community/whisper-large-v3-mlx",
            "mlx-community/whisper-large-v3": "mlx-community/whisper-large-v3-mlx",
            "mlx-community/whisper-large-v3-turbo": "mlx-community/whisper-large-v3-mlx",
            "mlx-community/distil-whisper-large-v3": "mlx-community/whisper-large-v3-mlx",
        }
        normalized = aliases.get(repo_id, repo_id)
        if normalized != self.primary_repo_id:
            return self.primary_repo_id
        return normalized

    def _resample_audio(self, audio: np.ndarray, from_rate: int, to_rate: int) -> np.ndarray:
        if audio.size == 0 or from_rate <= 0 or to_rate <= 0 or from_rate == to_rate:
            return audio

        duration = audio.shape[0] / float(from_rate)
        if duration <= 0:
            return audio

        out_len = max(1, int(round(duration * to_rate)))
        src_idx = np.linspace(0.0, audio.shape[0] - 1, num=audio.shape[0], dtype=np.float32)
        dst_idx = np.linspace(0.0, audio.shape[0] - 1, num=out_len, dtype=np.float32)
        return np.interp(dst_idx, src_idx, audio).astype(np.float32)

    def _resolve_model_path(self, repo_id: str, canonicalize: bool = True) -> str:
        if canonicalize:
            repo_id = self._canonical_repo_id(repo_id)
        cache_base = os.path.expanduser("~/.cache/huggingface/hub")
        folder_pattern = f"models--{repo_id.replace('/', '--')}"
        search_path = os.path.join(cache_base, folder_pattern, "snapshots", "*")

        matches = glob.glob(search_path)
        if matches:
            latest = sorted(matches)[-1]
            self.logger.info(f"Local model found for {repo_id} at: {latest}")
            return latest

        self.logger.warning(f"No local cache found for {repo_id}. Will attempt download on first run.")
        return repo_id

    def preload_models(self) -> None:
        self.logger.info("Warming up MLX Whisper model in background...")
        try:
            import mlx_whisper

            dummy_audio = np.zeros(16000, dtype=np.float32)
            with self._mlock:
                mlx_whisper.transcribe(
                    dummy_audio,
                    path_or_hf_repo=self.primary_model_path,
                    temperature=0.0,
                    condition_on_previous_text=False,
                    language="en",
                )
            self.whisper_ready = True
            self.logger.info("MLX Whisper warmup complete.")
        except Exception as e:
            self.logger.error(f"Could not preload MLX Whisper: {e}")

    def _has_speech(self, audio: np.ndarray, threshold: float) -> bool:
        if audio.size == 0:
            return False
        rms = float(np.sqrt(np.mean(np.square(audio))))
        return rms >= threshold

    def _merge_text(self, base: str, incoming: str) -> str:
        base = (base or "").strip()
        incoming = (incoming or "").strip()
        if not incoming:
            return base
        if not base:
            return incoming
        if incoming in base:
            return base

        base_words = base.split()
        in_words = incoming.split()
        max_overlap = min(len(base_words), len(in_words), 12)

        for n in range(max_overlap, 0, -1):
            if base_words[-n:] == in_words[:n]:
                merged = base_words + in_words[n:]
                return " ".join(merged).strip()

        return f"{base} {incoming}".strip()

    def _fast_punctuate(self, text: str) -> str:
        t = " ".join((text or "").split()).strip()
        if not t:
            return t
        if t[0].isalpha():
            t = t[0].upper() + t[1:]
        if t[-1] not in ".!?":
            t += "."
        return t

    def _decode_np_audio(self, audio: np.ndarray, language: str, model_path: str) -> str:
        import mlx_whisper

        with self._mlock:
            result = mlx_whisper.transcribe(
                audio,
                path_or_hf_repo=model_path,
                temperature=0.0,
                condition_on_previous_text=False,
                language=language or "en",
            )
        return result.get("text", "").strip()

    def transcribe_audio(self, file_path: str) -> str:
        try:
            import mlx_whisper

            self.logger.info(f"Transcribing (legacy HTTP) with {self.primary_repo_id}...")
            with self._mlock:
                result = mlx_whisper.transcribe(
                    file_path,
                    path_or_hf_repo=self.primary_model_path,
                    temperature=0.0,
                    condition_on_previous_text=False,
                    language="en",
                )

            text = result["text"].strip()
            if not text:
                return ""

            # Deduplicate exact doubling pattern.
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
            self.logger.error(f"mlx_whisper failed: {e}")
            return ""

    def create_stream_session(self, session_id: str, sample_rate: int, language: str = "en", model_repo: str = "") -> None:
        input_sr = max(1, int(sample_rate))
        repo = self._canonical_repo_id(model_repo or self.default_repo_id)
        model_path = self._resolve_model_path(repo)
        self.logger.info(
            f"Stream session started ({session_id}) input_sr={input_sr} model_sr={self.model_sample_rate} repo={repo}"
        )
        with self._sessions_lock:
            self._sessions[session_id] = StreamSession(
                session_id=session_id,
                sample_rate=input_sr,
                language=language or "en",
                model_repo=repo,
                model_path=model_path,
                started_at=time.time(),
                audio=np.array([], dtype=np.float32),
                committed_text="",
                next_decode_start=0,
                last_partial_decode_at=0.0,
                last_decode_total_samples=0,
            )

    def append_chunk_and_maybe_decode(self, session_id: str, pcm16_bytes: bytes) -> str:
        with self._sessions_lock:
            session = self._sessions.get(session_id)
            if session is None:
                return ""

        if not pcm16_bytes:
            return session.committed_text

        audio_i16 = np.frombuffer(pcm16_bytes, dtype=np.int16)
        if audio_i16.size == 0:
            return session.committed_text

        chunk = (audio_i16.astype(np.float32) / 32768.0).clip(-1.0, 1.0)

        with self._sessions_lock:
            input_sr = session.sample_rate
            language = session.language
            model_path = session.model_path
            last_partial_decode_at = session.last_partial_decode_at
            last_decode_total_samples = session.last_decode_total_samples

        if input_sr != self.model_sample_rate:
            chunk = self._resample_audio(chunk, input_sr, self.model_sample_rate)

        with self._sessions_lock:
            session.audio = np.concatenate([session.audio, chunk])
            window_samples = int(self.model_sample_rate * (self.window_ms / 1000.0))
            step_samples = int(self.model_sample_rate * ((self.window_ms - self.overlap_ms) / 1000.0))
            start = session.next_decode_start
            total = session.audio.shape[0]

        if step_samples <= 0 or window_samples <= 0:
            return session.committed_text

        updated_text = None

        # Decode at most one partial window per call to avoid backlog/catch-up latency.
        if (total - start >= window_samples) and ((time.time() - last_partial_decode_at) >= 0.65):
            # Always decode the newest window so the model stays near-real-time.
            decode_start = max(start, total - window_samples)
            segment = session.audio[decode_start:decode_start + window_samples]
            if self._has_speech(segment, self.vad_rms_threshold):
                try:
                    t0 = time.time()
                    decoded = self._decode_np_audio(segment, language, model_path)
                    self.logger.info(
                        f"stream partial decoded ({session_id}) len={segment.shape[0]} took_ms={int((time.time()-t0)*1000)}"
                    )
                except Exception as e:
                    self.logger.error(f"stream partial decode failed ({session_id}): {e}")
                    decoded = ""

                with self._sessions_lock:
                    live = self._sessions.get(session_id)
                    if live is None:
                        return ""
                    # Build a stable committed hypothesis while recording.
                    live.committed_text = self._merge_text(live.committed_text, decoded)
                    live.last_partial_decode_at = time.time()
                    live.last_decode_total_samples = total
                    updated_text = live.committed_text

            # Keep only a short overlap as undecoded tail.
            overlap_tail = int(self.model_sample_rate * (self.overlap_ms / 1000.0))
            start = max(0, total - overlap_tail)

        with self._sessions_lock:
            live = self._sessions.get(session_id)
            if live is None:
                return ""
            live.next_decode_start = start
            return updated_text if updated_text is not None else live.committed_text

    def finalize_stream_session(self, session_id: str) -> Dict[str, object]:
        with self._sessions_lock:
            session = self._sessions.get(session_id)
            if session is None:
                return {"text": "", "latency_ms": 0}

            audio = session.audio.copy()
            language = session.language
            model_repo = session.model_repo
            model_path = session.model_path
            committed = session.committed_text
            tail_start = session.next_decode_start
            started_at = session.started_at
            last_decode_total_samples = session.last_decode_total_samples

        duration_seconds = (audio.shape[0] / float(self.model_sample_rate)) if audio.size > 0 else 0.0
        tail = audio[tail_start:]
        final_text = committed

        # Accuracy-first finalization for normal utterances:
        # use one full-audio decode to avoid dropped middle words from window merges.
        if audio.size > 0 and duration_seconds <= self.full_finalize_max_seconds:
            try:
                t0 = time.time()
                full_text = self._decode_np_audio(audio, language, model_path)
                self.logger.info(
                    f"stream full-final decoded ({session_id}) len={audio.shape[0]} dur_s={duration_seconds:.2f} took_ms={int((time.time()-t0)*1000)}"
                )
                final_text = full_text.strip()
            except Exception as e:
                self.logger.error(f"stream full-final decode failed ({session_id}): {e}")

        # For long utterances, keep the low-latency reconcile strategy.
        if not final_text.strip():
            new_since_last_decode = max(0, audio.size - last_decode_total_samples)
            tiny_tail_samples = int(self.model_sample_rate * (self.skip_tail_below_ms / 1000.0))
            should_decode_tail = (
                audio.size > 0
                and (new_since_last_decode >= tiny_tail_samples or not final_text.strip())
            )

            if should_decode_tail:
                try:
                    max_tail_samples = int(self.model_sample_rate * (self.max_tail_decode_ms / 1000.0))
                    recent = audio[-max_tail_samples:] if audio.size > max_tail_samples else audio
                    if tail.size > 0 and self._has_speech(tail, self.vad_rms_relaxed):
                        segment = recent
                    else:
                        segment = recent
                    t0 = time.time()
                    tail_text = self._decode_np_audio(segment, language, model_path)
                    self.logger.info(
                        f"stream reconcile decoded ({session_id}) len={segment.shape[0]} took_ms={int((time.time()-t0)*1000)}"
                    )
                    final_text = self._merge_text(final_text, tail_text)
                except Exception as e:
                    self.logger.error(f"stream reconcile decode failed ({session_id}): {e}")
            else:
                self.logger.info(
                    f"stream tail skipped ({session_id}) new_since_last_decode={new_since_last_decode}"
                )

        # Safety fallback for very short or very quiet clips.
        if not final_text.strip() and audio.size > 0:
            try:
                t0 = time.time()
                retry_text = self._decode_np_audio(audio, language, model_path)
                self.logger.info(
                    f"stream full fallback decoded ({session_id}) len={audio.shape[0]} took_ms={int((time.time()-t0)*1000)}"
                )
                final_text = retry_text.strip()
            except Exception as e:
                self.logger.error(f"stream fallback decode failed ({session_id}): {e}")

        # Hidden reliability rescue: if primary returns empty, retry once on turbo.
        if not final_text.strip() and audio.size > 0 and model_repo != self.turbo_repo_id:
            try:
                t0 = time.time()
                turbo_text = self._decode_np_audio(audio, language, self.turbo_model_path)
                self.logger.info(
                    f"stream turbo-rescue decoded ({session_id}) len={audio.shape[0]} took_ms={int((time.time()-t0)*1000)}"
                )
                final_text = turbo_text.strip()
            except Exception as e:
                self.logger.error(f"stream turbo-rescue decode failed ({session_id}): {e}")

        with self._sessions_lock:
            self._sessions.pop(session_id, None)

        latency_ms = int((time.time() - started_at) * 1000.0)
        return {"text": self._fast_punctuate(final_text.strip()), "latency_ms": latency_ms}

    def decode_base64_chunk(self, b64_payload: str) -> bytes:
        if not b64_payload:
            return b""
        try:
            return base64.b64decode(b64_payload)
        except Exception:
            return b""

    def get_available_models(self):
        return [
            "mlx-community/whisper-large-v3-mlx",
        ]
