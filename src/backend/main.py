import threading
from logger_service import LoggerService
from audio_service import AudioService
from server import ServerService

PORT = 8111

def run():
    # 1. Initialize DI Services
    logger = LoggerService()
    audio_service = AudioService(logger)
    server = ServerService(port=PORT, audio_service=audio_service, logger=logger)

    # 2. Start Warmup Background Side Effect
    threading.Thread(target=audio_service.preload_models, daemon=True).start()

    # 3. Start Server
    server.start()

if __name__ == '__main__':
    run()
