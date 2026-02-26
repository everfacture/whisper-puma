import Foundation
import Cocoa

class BackendProcessManager {
    var backendProcess: Process?
    private let logger: LoggerService
    
    init(logger: LoggerService) {
        self.logger = logger
    }
    
    func start() {
        // Kill existing instances on the target port to prevent conflicts
        killExistingBackend()

        guard let scriptPath = Bundle.main.path(forResource: "main", ofType: "py") else {
            logger.error("Backend script not found in bundle!")
            return
        }
        
        backendProcess = Process()
        backendProcess?.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        
        // Use environment variables instead of bash exports
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        environment["PYTHONUNBUFFERED"] = "1"
        backendProcess?.environment = environment
        
        backendProcess?.arguments = [scriptPath]
        
        // Redirect output to the centralized log path
        let logURL = URL(fileURLWithPath: Constants.backendLogPath)
        do {
            // Ensure log file exists
            if !FileManager.default.fileExists(atPath: Constants.backendLogPath) {
                FileManager.default.createFile(atPath: Constants.backendLogPath, contents: nil)
            }
            
            let logFileHandle = try FileHandle(forWritingTo: logURL)
            logFileHandle.seekToEndOfFile()
            backendProcess?.standardOutput = logFileHandle
            backendProcess?.standardError = logFileHandle
            
            try backendProcess?.run()
            logger.success("Internal Python Backend started (Port \(Constants.backendPort)). Logging to \(Constants.backendLogPath)")
        } catch {
            logger.error("Failed to start backend: \(error.localizedDescription)")
        }
    }
    
    func stop() {
        if backendProcess?.isRunning == true {
            backendProcess?.terminate()
            logger.info("Backend process terminated.")
        }
    }
    
    private func killExistingBackend() {
        let killTask = Process()
        killTask.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        killTask.arguments = ["sh", "-c", "lsof -t -i:\(Constants.backendPort) | xargs kill -9"]
        
        do {
            try killTask.run()
            killTask.waitUntilExit()
        } catch {
            logger.warning("Optional cleanup of port \(Constants.backendPort) failed: \(error)")
        }
    }

}
