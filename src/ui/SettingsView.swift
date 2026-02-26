import SwiftUI
import Cocoa

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var showingKeyCapture = false
    @State private var latencyText: String = "No samples yet"
    @State private var keyCaptureMonitor: Any?

    private var availableRecordingModes: [RecordingMode] {
        settings.triggerKeyCode == AppSettings.fnKeyCode ? [.hold] : RecordingMode.allCases
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Whisper Puma Settings")
                    .font(.title3.weight(.semibold))

                GroupBox("Hotkeys & Triggers") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Trigger Key")
                            Spacer()
                            Button(action: { showingKeyCapture = true }) {
                                Text(keyName(for: settings.triggerKeyCode))
                                    .frame(minWidth: 150)
                            }
                        }

                        HStack(spacing: 8) {
                            Text("Quick Presets")
                            Spacer()
                            Button("Fn") { settings.triggerKeyCode = 63 }
                            Button("Right ⌘") { settings.triggerKeyCode = 54 }
                            Button("Right ⌥") { settings.triggerKeyCode = 61 }
                        }
                        .controlSize(.small)

                        Picker("Recording Mode", selection: $settings.recordingMode) {
                            ForEach(availableRecordingModes, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .disabled(settings.triggerKeyCode == AppSettings.fnKeyCode)

                        if settings.triggerKeyCode == AppSettings.fnKeyCode {
                            Text("Fn is locked to Hold to Talk to avoid macOS Fn tap side-effects and accidental start/stop taps.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 6)
                }

                GroupBox("Transcription") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Model")
                            Spacer()
                            Text("Large v3 (Accurate)")
                                .fontWeight(.semibold)
                        }
                        Text("Public model policy is fixed to `mlx-community/whisper-large-v3-mlx`. Turbo is used only as hidden rescue when final decode is empty.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack {
                            Text("Language")
                            Spacer()
                            Picker("Language", selection: $settings.languageCode) {
                                Text("English").tag("en")
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }

                        Toggle("Enable spoken punctuation commands", isOn: $settings.spokenCommandsEnabled)
                        Toggle("Enable bounded local polish (>20 words, 250ms timeout)", isOn: $settings.asyncPolishEnabled)

                        Picker("Insertion", selection: $settings.insertionMode) {
                            ForEach(InsertionMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                    }
                    .padding(.top, 6)
                }

                GroupBox("Latency") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Show live indicator while decoding", isOn: $settings.latencyOverlayEnabled)
                        Text(latencyText)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 6)
                }

                HStack {
                    Spacer()
                    Text("v1.2.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(18)
        }
        .frame(minWidth: 640, minHeight: 620)
        .onAppear {
            refreshLatencyLabel()
        }
        .overlay(keyCaptureOverlay)
    }

    @ViewBuilder
    private var keyCaptureOverlay: some View {
        if showingKeyCapture {
            ZStack {
                Color(NSColor.windowBackgroundColor).opacity(0.92)
                VStack(spacing: 8) {
                    Text("Press any key to set as trigger...")
                        .font(.title3)
                    Text("(Esc to cancel)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onAppear {
                keyCaptureMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
                    if event.type == .keyDown && event.keyCode == 53 {
                        closeKeyCapture()
                        return nil
                    }

                    let code = Int(event.keyCode)
                    let modifiers: [Int] = [63, 54, 55, 56, 57, 58, 59, 60, 61, 62]
                    if event.type == .keyDown || (event.type == .flagsChanged && modifiers.contains(code)) {
                        settings.triggerKeyCode = code
                        closeKeyCapture()
                        return nil
                    }
                    return event
                }
            }
        }
    }

    private func closeKeyCapture() {
        showingKeyCapture = false
        if let monitor = keyCaptureMonitor {
            NSEvent.removeMonitor(monitor)
            keyCaptureMonitor = nil
        }
    }

    private func refreshLatencyLabel() {
        let stats = LatencyMetrics.shared.summary()
        if let last = stats.last, let p50 = stats.p50, let p95 = stats.p95 {
            latencyText = String(format: "last: %.0fms  p50: %.0fms  p95: %.0fms", last, p50, p95)
        } else {
            latencyText = "No samples yet"
        }
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
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Whisper Puma Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        self.init(window: window)
    }
}
