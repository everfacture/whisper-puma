import Foundation

struct Constants {
    // Backend Configuration
    static let backendPort: Int = 8111
    static let backendURL: String = "http://localhost:\(backendPort)"
    
    // Model Configuration
    static let defaultModel: String = "mlx-community/whisper-large-v3-mlx"
    
    // Paths
    static let backendLogPath: String = (NSHomeDirectory() as NSString).appendingPathComponent(".whisper_puma_backend.log")
    
    // UI HUD
    static let hudPulseDuration: Double = 0.8
    static let hudOpacity: Double = 0.95
}
