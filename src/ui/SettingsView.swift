import SwiftUI
import Cocoa

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var showingKeyCapture = false
    @State private var availableModels: [String] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Whisper Puma Settings")
                .font(.headline)
            
            Divider()
            
            Group {
                Text("Hotkeys & Triggers").font(.subheadline).bold()
                
                HStack {
                    Text("Trigger Key:")
                    Spacer()
                    Button(action: {
                        showingKeyCapture = true
                    }) {
                        Text(keyName(for: settings.triggerKeyCode))
                            .frame(minWidth: 100)
                    }
                }
                
                HStack {
                    Text("Quick Presets:")
                    Spacer()
                    Button("Fn") { settings.triggerKeyCode = 63 }
                    Button("Right ⌘") { settings.triggerKeyCode = 54 }
                    Button("Right ⌥") { settings.triggerKeyCode = 61 }
                }
                .controlSize(.small)

                
                Picker("Recording Mode:", selection: $settings.recordingMode) {
                    ForEach(RecordingMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
            }
            
            Divider()
            
            Group {
                Text("Transcription").font(.subheadline).bold()
                
                // Model Selection removed (v1.0.7 Pivot)
                // App now uses whisper-large-v3-turbo by default for maximum speed & accuracy.


            }
            
            Spacer()
            
            HStack {
                Spacer()
                Text("v1.0.0-beta")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
        .onAppear {
            NetworkService.shared.fetchAvailableModels { models in
                DispatchQueue.main.async {
                    self.availableModels = models
                }
            }
        }

        .overlay(
            Group {
                if showingKeyCapture {
                    ZStack {
                        Color(NSColor.windowBackgroundColor).opacity(0.9)
                        VStack {
                            Text("Press any key to set as trigger...")
                                .font(.title3)
                            Text("(Esc to cancel)")
                                .font(.caption)
                        }
                    }
                    .onAppear {
                        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
                            if event.type == .keyDown && event.keyCode == 53 { // Esc
                                showingKeyCapture = false
                                return nil
                            }
                            
                            // For flagsChanged, we only trigger if it's a modifier key we recognize
                            // 63 is Fn, 54-62 are various cmds/opts
                            let code = Int(event.keyCode)
                            let modifiers: [Int] = [63, 54, 55, 56, 57, 58, 59, 60, 61, 62]
                            
                            if event.type == .keyDown || (event.type == .flagsChanged && modifiers.contains(code)) {
                                settings.triggerKeyCode = code
                                showingKeyCapture = false
                            }
                            return nil
                        }
                    }

                }
            }
        )
    }
    
    private func keyName(for code: Int) -> String {
        switch code {
        case 63: return "Fn"
        case 54: return "Right Command"
        case 61: return "Right Option"
        case 62: return "Right Control"
        default: return "Key Code: \(code)"
        }
    }
}

class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 350),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.title = "Whisper Puma Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        self.init(window: window)
    }
}
