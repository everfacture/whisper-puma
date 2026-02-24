import Foundation
import Cocoa

class BackendProcessManager {
    var backendProcess: Process?
    private let logger: LoggerService
    
    init(logger: LoggerService) {
        self.logger = logger
    }
    
    func start() {
        // Kill existing instances on port 8111 to prevent conflicts
        killExistingBackend()

        guard let scriptPath = Bundle.main.path(forResource: "main", ofType: "py") else {
            logger.error("Backend script not found in bundle at path!")
            return
        }
        
        backendProcess = Process()
        backendProcess?.executableURL = URL(fileURLWithPath: "/bin/bash")
        
        let logPath = (NSHomeDirectory() as NSString).appendingPathComponent(".whisper_puma_backend.log")
        let command = "export PYTHONDONTWRITEBYTECODE=1 && python3 -u \"\(scriptPath)\" > \"\(logPath)\" 2>&1"
        backendProcess?.arguments = ["-l", "-c", command]
        
        do {
            try backendProcess?.run()
            logger.success("Internal Python Backend started. Logging to \(logPath)")
        } catch {
            logger.error("Failed to start backend: \(error)")
        }
    }
    
    func stop() {
        backendProcess?.terminate()
    }
    
    private func killExistingBackend() {
        let killTask = Process()
        killTask.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        killTask.arguments = ["sh", "-c", "lsof -t -i:8111 | xargs kill -9"]
        try? killTask.run()
        killTask.waitUntilExit()
    }
}
