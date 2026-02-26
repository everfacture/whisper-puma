import SwiftUI
import Cocoa

struct HistoryEntry: Identifiable {
    let id = UUID()
    let text: String
    let timestamp: Date?
}

final class HistoryStore: ObservableObject {
    @Published var entries: [HistoryEntry] = []

    private let iso = ISO8601DateFormatter()

    private var historyURL: URL {
        URL(fileURLWithPath: (NSHomeDirectory() as NSString).appendingPathComponent(".whisper_puma_history.log"))
    }

    func reload() {
        guard let raw = try? String(contentsOf: historyURL, encoding: .utf8) else {
            entries = []
            return
        }

        let lines = raw.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        var parsed: [HistoryEntry] = []

        for line in lines {
            if let entry = parseJSONLine(line) {
                parsed.append(entry)
                continue
            }

            if isSystemOrBackendLog(line) {
                continue
            }

            parsed.append(HistoryEntry(text: line, timestamp: nil))
        }

        entries = parsed.reversed()
    }

    func clearAll() {
        try? "".write(to: historyURL, atomically: true, encoding: .utf8)
        reload()
    }

    private func parseJSONLine(_ line: String) -> HistoryEntry? {
        guard line.hasPrefix("{"), let data = line.data(using: .utf8) else {
            return nil
        }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let text = json["text"] as? String,
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        let ts = (json["ts"] as? String).flatMap { iso.date(from: $0) }
        return HistoryEntry(text: text, timestamp: ts)
    }

    private func isSystemOrBackendLog(_ line: String) -> Bool {
        let isSystemPrefix = line.hasPrefix("[")
        let isTimestampedLog = line.range(of: #"^\d{1,2}/\d{1,2}/\d{4},"#, options: .regularExpression) != nil
        let isBackendTimestamp = line.range(of: #"^\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil
        return isSystemPrefix || isTimestampedLog || isBackendTimestamp
    }
}

struct HistoryView: View {
    @StateObject private var store = HistoryStore()
    @State private var query: String = ""
    private let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()
    private let absoluteFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private var filtered: [HistoryEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return store.entries }
        return store.entries.filter { $0.text.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dictation History")
                        .font(.title3.weight(.semibold))
                    Text("\(filtered.count) entries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Refresh") { store.reload() }
                Button("Clear") { store.clearAll() }
            }

            TextField("Search history", text: $query)
                .textFieldStyle(.roundedBorder)

            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Text("No history entries")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Your transcribed text will appear here.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(filtered) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                if let ts = entry.timestamp {
                                    HStack {
                                        Text(relativeFormatter.localizedString(for: ts, relativeTo: Date()))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(absoluteFormatter.string(from: ts))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Text(entry.text)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)

                                HStack {
                                    Spacer()
                                    Button("Copy") {
                                        let pb = NSPasteboard.general
                                        pb.clearContents()
                                        pb.setString(entry.text, forType: .string)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(NSColor.textBackgroundColor))
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 620, minHeight: 500)
        .onAppear { store.reload() }
    }
}

class HistoryWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Whisper Puma History"
        window.contentView = NSHostingView(rootView: HistoryView())
        self.init(window: window)
    }
}
