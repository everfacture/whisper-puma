import Foundation

class LoggerService {
    static let shared = LoggerService()
    private let logURL: URL
    
    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.logURL = home.appendingPathComponent(".whisper_puma_history.log")
        
        // Ensure log file exists
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
    }
    
    private func logToFile(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let logEntry = "\(timestamp) \(message)\n"
        
        if let data = logEntry.data(using: .utf8) {
            if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        }
    }
    
    func info(_ message: String) {
        let msg = "[INFO] \(message)"
        print(msg)
        logToFile(msg)
    }
    
    func error(_ message: String) {
        let msg = "[ERROR] ❌ \(message)"
        print(msg)
        logToFile(msg)
    }
    
    func warning(_ message: String) {
        let msg = "[WARN] ⚠️ \(message)"
        print(msg)
        logToFile(msg)
    }
    
    func success(_ message: String) {
        let msg = "[SUCCESS] ✅ \(message)"
        print(msg)
        logToFile(msg)
    }
}

