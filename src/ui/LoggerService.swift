import Foundation

class LoggerService {
    static let shared = LoggerService()
    
    private init() {}
    
    func info(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("\(timestamp) [INFO] \(message)")
    }
    
    func error(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("\(timestamp) [ERROR] ❌ \(message)")
    }
    
    func warning(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("\(timestamp) [WARN] ⚠️ \(message)")
    }
    
    func success(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("\(timestamp) [SUCCESS] ✅ \(message)")
    }
}
