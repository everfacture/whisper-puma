import asyncio
import json
import os
from aiohttp import web

from audio_service import AudioService
from logger_service import LoggerService


class ServerService:
    def __init__(self, port: int, audio_service: AudioService, logger: LoggerService):
        self.port = port
        self.audio_service = audio_service
        self.logger = logger

    async def _handle_models(self, request: web.Request) -> web.Response:
        models = self.audio_service.get_available_models()
        return web.json_response({"status": "success", "models": models})

    async def _handle_transcribe(self, request: web.Request) -> web.Response:
        try:
            data = await request.json()
            file_path = data.get("file")
            if not file_path or not os.path.exists(file_path):
                return web.json_response({"status": "error", "error": "Invalid file path"}, status=400)

            final_text = await asyncio.to_thread(self.audio_service.transcribe_audio, file_path)
            return web.json_response({"status": "success", "text": final_text})
        except Exception as e:
            self.logger.error(f"Error handling /transcribe request: {e}")
            return web.json_response({"status": "error", "error": str(e)}, status=500)

    async def _handle_stream(self, request: web.Request) -> web.WebSocketResponse:
        ws = web.WebSocketResponse(heartbeat=30)
        await ws.prepare(request)

        active_session_id = None
        self.logger.info("WS client connected: /stream")

        try:
            async for msg in ws:
                if msg.type == web.WSMsgType.TEXT:
                    try:
                        payload = json.loads(msg.data)
                    except Exception:
                        await ws.send_json({
                            "type": "session.error",
                            "code": "invalid_json",
                            "message": "Invalid JSON payload",
                        })
                        continue

                    mtype = payload.get("type")

                    if mtype == "session.start":
                        session_id = payload.get("session_id")
                        sample_rate = int(payload.get("sample_rate", 16000))
                        language = payload.get("language", "en")
                        model = payload.get("model", "")

                        if not session_id:
                            await ws.send_json({
                                "type": "session.error",
                                "code": "missing_session_id",
                                "message": "session_id is required",
                            })
                            continue

                        await asyncio.to_thread(
                            self.audio_service.create_stream_session,
                            session_id,
                            sample_rate,
                            language,
                            model,
                        )
                        active_session_id = session_id
                        await ws.send_json({"type": "session.started", "session_id": session_id})

                    elif mtype == "audio.chunk":
                        session_id = payload.get("session_id")
                        b64_audio = payload.get("pcm16_base64", "")

                        if not session_id:
                            continue

                        pcm = await asyncio.to_thread(self.audio_service.decode_base64_chunk, b64_audio)
                        partial_text = await asyncio.to_thread(
                            self.audio_service.append_chunk_and_maybe_decode,
                            session_id,
                            pcm,
                        )

                        if partial_text:
                            await ws.send_json({
                                "type": "transcript.partial",
                                "session_id": session_id,
                                "text": partial_text,
                                "stability": 0.7,
                            })

                    elif mtype == "session.stop":
                        session_id = payload.get("session_id") or active_session_id
                        if not session_id:
                            continue

                        result = await asyncio.to_thread(self.audio_service.finalize_stream_session, session_id)
                        await ws.send_json({
                            "type": "transcript.final",
                            "session_id": session_id,
                            "text": result.get("text", ""),
                            "latency_ms": result.get("latency_ms", 0),
                        })

                    else:
                        await ws.send_json({
                            "type": "session.error",
                            "code": "unsupported_type",
                            "message": f"Unsupported message type: {mtype}",
                        })

                elif msg.type == web.WSMsgType.ERROR:
                    self.logger.error(f"WS connection closed with exception {ws.exception()}")

        except Exception as e:
            self.logger.error(f"WS stream error: {e}")
            await ws.send_json({
                "type": "session.error",
                "code": "stream_failure",
                "message": str(e),
            })
        finally:
            self.logger.info("WS client disconnected: /stream")

        return ws

    async def _run(self):
        app = web.Application()
        app.add_routes([
            web.get("/models", self._handle_models),
            web.post("/transcribe", self._handle_transcribe),
            web.get("/stream", self._handle_stream),
        ])

        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, "127.0.0.1", self.port)
        await site.start()

        self.logger.info(f"Whisper Puma Daemon (HTTP + WS) running on http://127.0.0.1:{self.port}...")

        while True:
            await asyncio.sleep(3600)

    def start(self):
        asyncio.run(self._run())
