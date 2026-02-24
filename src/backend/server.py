import os
import json
from http.server import HTTPServer, BaseHTTPRequestHandler
from audio_service import AudioService
from logger_service import LoggerService

class DaemonHandler(BaseHTTPRequestHandler):
    # These must be injected onto the class or server instance beforehand
    audio_service: AudioService = None
    logger: LoggerService = None

    def do_POST(self):
        if self.path == '/transcribe':
            self._handle_transcribe()
        else:
            self.send_error(404, "Not Found")

    def _handle_transcribe(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        
        try:
            data = json.loads(post_data.decode('utf-8'))
            file_path = data.get('file')
            
            if not file_path or not os.path.exists(file_path):
                self.send_error(400, "Invalid file path")
                return

            final_text = self.audio_service.transcribe_audio(file_path)
            self._send_success_response({"status": "success", "text": final_text})
            
        except Exception as e:
            self.logger.error(f"Error handling request: {e}")
            self.send_error(500, str(e))

    def _send_success_response(self, payload: dict):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(payload).encode('utf-8'))

class ServerService:
    def __init__(self, port: int, audio_service: AudioService, logger: LoggerService):
        self.port = port
        self.audio_service = audio_service
        self.logger = logger
        
        # Inject dependencies into the HTTP Handler class
        DaemonHandler.audio_service = self.audio_service
        DaemonHandler.logger = self.logger

    def start(self):
        server_address = ('127.0.0.1', self.port)
        httpd = HTTPServer(server_address, DaemonHandler)
        self.logger.info(f"Whisper Puma Daemon running on http://127.0.0.1:{self.port}...")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
        httpd.server_close()
        self.logger.info("Daemon stopped.")
