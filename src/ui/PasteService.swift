import Cocoa

class PasteService {
    private struct FormattingResult {
        let text: String
        let commandPriority: Bool
    }

    private let logger: LoggerService
    private let settings = AppSettings.shared
    private let asyncPolishService = AsyncPolishService.shared

    init(logger: LoggerService) {
        self.logger = logger
    }

    func processAndPaste(_ text: String, targetApp: NSRunningApplication?, completion: ((String) -> Void)? = nil) {
        let deterministic = settings.spokenCommandsEnabled
            ? applyDeterministicFormatting(text)
            : FormattingResult(text: text.trimmingCharacters(in: .whitespacesAndNewlines), commandPriority: false)

        guard !deterministic.text.isEmpty else {
            completion?("")
            return
        }

        let shouldRunBoundedPolish =
            settings.asyncPolishEnabled
            && !deterministic.commandPriority
            && deterministic.text.split(whereSeparator: \.isWhitespace).count > 20

        if shouldRunBoundedPolish {
            asyncPolishService.polish(deterministic.text, timeoutMs: 250) { [weak self] polished in
                guard let self = self else {
                    completion?(deterministic.text)
                    return
                }
                let finalText = self.selectFinalText(base: deterministic.text, polished: polished)
                DispatchQueue.main.async {
                    self.insertAndPersist(finalText, targetApp: targetApp)
                    completion?(finalText)
                }
            }
            return
        }

        insertAndPersist(deterministic.text, targetApp: targetApp)
        completion?(deterministic.text)
    }

    private func selectFinalText(base: String, polished: String?) -> String {
        guard let polished = polished?.trimmingCharacters(in: .whitespacesAndNewlines), !polished.isEmpty else {
            return base
        }
        return polished
    }

    private func insertAndPersist(_ text: String, targetApp: NSRunningApplication?) {
        saveToHistory(text)
        switch settings.insertionMode {
        case .clipboardOnly:
            clipboardPastePreservingClipboard(text, targetApp: targetApp)
        case .directThenClipboard:
            if !typeDirectly(text, targetApp: targetApp) {
                clipboardPastePreservingClipboard(text, targetApp: targetApp)
            }
        }
    }

    private func saveToHistory(_ text: String) {
        let historyURL = URL(fileURLWithPath: (NSHomeDirectory() as NSString).appendingPathComponent(".whisper_puma_history.log"))
        let payload: [String: String] = [
            "ts": ISO8601DateFormatter().string(from: Date()),
            "text": text,
        ]
        guard
            let json = try? JSONSerialization.data(withJSONObject: payload),
            let line = String(data: json, encoding: .utf8),
            let data = (line + "\n").data(using: .utf8)
        else {
            return
        }

        if FileManager.default.fileExists(atPath: historyURL.path) {
            if let fileHandle = try? FileHandle(forWritingTo: historyURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: historyURL)
        }
    }

    private func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    private func typeDirectly(_ text: String, targetApp: NSRunningApplication?) -> Bool {
        guard hasAccessibilityPermission() else {
            logger.warning("Accessibility permission missing; cannot type directly.")
            return false
        }

        let appToFocus = targetApp ?? NSWorkspace.shared.frontmostApplication
        appToFocus?.activate(options: [])
        Thread.sleep(forTimeInterval: 0.05)

        if let intended = appToFocus?.processIdentifier,
           let actual = NSWorkspace.shared.frontmostApplication?.processIdentifier,
           intended != actual {
            logger.warning("Direct typing aborted due to focus mismatch; using clipboard fallback.")
            return false
        }

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }

        for scalar in text.unicodeScalars {
            var value = UInt16(scalar.value)
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                return false
            }

            keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &value)
            keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &value)

            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }

        logger.success("✅ Inserted text via direct typing.")
        return true
    }

    private func clipboardPastePreservingClipboard(_ text: String, targetApp: NSRunningApplication?) {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard hasAccessibilityPermission() else {
            logger.warning("Accessibility missing: copied transcript to clipboard. Paste manually with Cmd+V.")
            return
        }

        let appToFocus = targetApp ?? NSWorkspace.shared.frontmostApplication
        appToFocus?.activate(options: [])
        Thread.sleep(forTimeInterval: 0.05)

        let vKeyCode: CGKeyCode = 0x09
        let src = CGEventSource(stateID: .hidSystemState)

        if let keyDown = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true),
           let keyUp = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false) {
            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            logger.success("✅ Completed paste simulation via clipboard fallback.")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            pasteboard.clearContents()
            if let previous = previous {
                pasteboard.setString(previous, forType: .string)
            }
        }
    }

    private func applyDeterministicFormatting(_ text: String) -> FormattingResult {
        let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else {
            return FormattingResult(text: "", commandPriority: false)
        }

        let commandPriority = containsExplicitCommand(original)
        let hasListIntent = original.range(
            of: "\\b(let'?s\\s+make\\s+a\\s+list|here'?s\\s+a\\s+list|make\\s+a\\s+list|numbered\\s*list|bullet\\s*points?)\\b",
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        var out = text

        let regexReplacements: [(String, String)] = [
            ("\\b(full\\s*stop|period)\\b", "."),
            ("\\bdot\\b", "."),
            ("\\bcomma\\b", ","),
            ("\\bquestion\\s*mark\\b", "?"),
            ("\\bexclamation\\s*mark\\b", "!"),
            ("\\bsemicolon\\b", ";"),
            ("\\bcolon\\b", ":"),
            ("\\bnew\\s*paragraph\\b", "\n\n"),
            ("\\bnew\\s*line\\b", "\n"),
            ("\\bbullet\\s*points?\\b", "\n• "),
            ("\\bnumbered\\s*list\\b", "\n1. "),
            ("\\b(point|number)\\s*one\\b", "\n1. "),
            ("\\b(point|number)\\s*two\\b", "\n2. "),
            ("\\b(point|number)\\s*three\\b", "\n3. "),
            ("\\b(point|number)\\s*four\\b", "\n4. "),
            ("\\b(point|number)\\s*five\\b", "\n5. "),
            ("\\b(let'?s\\s+make\\s+a\\s+list|here'?s\\s+a\\s+list|make\\s+a\\s+list)\\b", "\n")
        ]

        for (pattern, replacement) in regexReplacements {
            out = out.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }

        if hasListIntent {
            let numberedMarkers: [(String, String)] = [
                ("(^|[\\n\\.,;:])\\s*one\\b", "$1\n1. "),
                ("(^|[\\n\\.,;:])\\s*two\\b", "$1\n2. "),
                ("(^|[\\n\\.,;:])\\s*three\\b", "$1\n3. "),
                ("(^|[\\n\\.,;:])\\s*four\\b", "$1\n4. "),
                ("(^|[\\n\\.,;:])\\s*five\\b", "$1\n5. "),
            ]
            for (pattern, replacement) in numberedMarkers {
                out = out.replacingOccurrences(of: pattern, with: replacement, options: [.regularExpression, .caseInsensitive])
            }
        }

        // Collapse filler disfluencies that often reduce readability.
        out = out.replacingOccurrences(of: "\\b(um+|uh+)\\b", with: "", options: [.regularExpression, .caseInsensitive])
        out = out.replacingOccurrences(of: "\\s*\\n\\s*", with: "\n", options: [.regularExpression])
        out = out.replacingOccurrences(of: "\\s*•\\s*", with: "\n• ", options: [.regularExpression])
        out = out.replacingOccurrences(of: "\\s*(\\d+\\.)\\s*", with: "\n$1 ", options: [.regularExpression])
        out = out.replacingOccurrences(of: "\\s+([,\\.!\\?])", with: "$1", options: [.regularExpression])
        out = out.replacingOccurrences(of: "([\\.!\\?]){2,}", with: "$1", options: [.regularExpression])
        out = out.replacingOccurrences(of: "([,;:]){2,}", with: "$1", options: [.regularExpression])
        out = out.replacingOccurrences(of: " {2,}", with: " ", options: [.regularExpression])
        out = out.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: [.regularExpression])

        out = out.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = out.first, first.isLetter {
            out.replaceSubrange(out.startIndex...out.startIndex, with: String(first).uppercased())
        }
        if let last = out.last, ![".", "!", "?"].contains(String(last)), !out.hasSuffix(":") {
            out.append(".")
        }
        return FormattingResult(text: out, commandPriority: commandPriority)
    }

    private func containsExplicitCommand(_ text: String) -> Bool {
        let pattern = "\\b(comma|period|full\\s*stop|question\\s*mark|exclamation\\s*mark|semicolon|colon|new\\s*line|new\\s*paragraph|bullet\\s*points?|numbered\\s*list|(point|number)\\s*(one|two|three|four|five)|let'?s\\s+make\\s+a\\s+list|make\\s+a\\s+list)\\b"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
