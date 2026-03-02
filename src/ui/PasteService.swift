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
        let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let commandReady = normalizeCommandPhrases(original)
        let literalCommandMention = isLikelyLiteralCommandMention(commandReady)
        let commandPriority = settings.spokenCommandsEnabled
            && containsExplicitCommand(commandReady)
            && !literalCommandMention
        let deterministic = applyDeterministicFormatting(
            commandReady,
            commandPriority: commandPriority,
            allowStructuralCommands: !literalCommandMention
        )

        guard !deterministic.text.isEmpty else {
            completion?("")
            return
        }

        let shouldRunBoundedPolish =
            settings.asyncPolishEnabled
            && !deterministic.commandPriority
            && shouldAutoPolish(deterministic.text)

        if shouldRunBoundedPolish {
            let words = deterministic.text.split(whereSeparator: \.isWhitespace).count
            let timeoutMs = words > 45 ? 900 : (words > 24 ? 650 : 450)
            asyncPolishService.polish(deterministic.text, timeoutMs: timeoutMs) { [weak self] polished in
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
        guard isSafePolishOutput(base: base, polished: polished) else {
            logger.warning("Skipping async polish output due to content-drift safety checks.")
            return base
        }
        return polished
    }

    private func normalizedWords(_ value: String) -> [String] {
        let lowered = value.lowercased()
        let normalized = lowered.replacingOccurrences(of: "[^a-z0-9']+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private func isSafePolishOutput(base: String, polished: String) -> Bool {
        let baseWords = normalizedWords(base)
        let polishedWords = normalizedWords(polished)
        guard !baseWords.isEmpty, !polishedWords.isEmpty else { return false }

        if polishedWords.count < Int(Double(baseWords.count) * 0.85) { return false }
        if abs(polishedWords.count - baseWords.count) > max(2, Int(Double(baseWords.count) * 0.20)) { return false }

        let baseSet = Set(baseWords)
        let polishedSet = Set(polishedWords)
        let overlap = baseSet.intersection(polishedSet).count
        let coverage = Double(overlap) / Double(max(1, baseSet.count))
        return coverage >= 0.85
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

    private func shouldAutoPolish(_ text: String) -> Bool {
        let words = text.split(whereSeparator: \.isWhitespace).count
        if words < 8 { return false }
        if words > 16 { return true }

        let hasTerminalPunctuation = text.range(of: "[\\.!\\?]\\s*$", options: .regularExpression) != nil
        let hasAnyPausePunctuation = text.range(of: "[,;:]", options: .regularExpression) != nil
        return !hasTerminalPunctuation || !hasAnyPausePunctuation
    }

    private func capitalizeFirstWord(_ word: String) -> String {
        guard let first = word.first else { return word }
        return String(first).uppercased() + word.dropFirst()
    }

    private func appendTerminalPeriodIfNeeded(_ text: String) -> String {
        guard let last = text.last else { return text }
        if [".", "!", "?", ":"].contains(String(last)) {
            return text
        }
        return text + "."
    }

    private func normalizeCommandPhrases(_ text: String) -> String {
        var out = text
        let normalizationRules: [(String, String)] = [
            ("\\b(new|next)\\s*[,\\.;:•-]+\\s*(line|paragraph|para|bullet|point)\\b", "$1 $2"),
            ("\\bparagraph\\s*[,\\.;:•-]+\\s*break\\b", "paragraph break"),
            ("\\bline\\s*[,\\.;:•-]+\\s*break\\b", "line break"),
            ("\\bbullet\\s*[,\\.;:•-]+\\s*point(s?)\\b", "bullet point$1"),
            ("\\b(point|number)\\s*[,\\.;:•-]+\\s*(one|two|three|four|five)\\b", "$1 $2"),
            ("\\bnew\\s*para\\b", "new paragraph"),
            ("\\bnext\\s*para\\b", "next paragraph"),
            ("\\bnew\\s*bullet\\s*point\\b", "new bullet"),
            ("\\bnext\\s*bullet\\s*point\\b", "next bullet"),
            ("\\bbullet\\s*items?\\b", "bullet point")
        ]

        for (pattern, replacement) in normalizationRules {
            out = out.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return out.replacingOccurrences(of: "[ \\t]{2,}", with: " ", options: .regularExpression)
    }

    private func applyParagraphHeuristics(_ text: String) -> String {
        var out = text
        if out.contains("\n•") || out.range(of: "\\n\\d+\\.\\s+", options: .regularExpression) != nil {
            return out
        }

        out = out.replacingOccurrences(
            of: "([\\.!\\?])\\s+(?=(now|anyway|also|then|so|next|after that|another thing|by the way|moving on)\\b)",
            with: "$1\n\n",
            options: [.regularExpression, .caseInsensitive]
        )

        if out.range(of: "\\n\\n", options: .regularExpression) != nil {
            return out
        }

        if out.count < 220 {
            return out
        }

        let sentenceAligned = out.replacingOccurrences(of: "([\\.!\\?])\\s+", with: "$1\n", options: .regularExpression)
        let sentences = sentenceAligned
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard sentences.count >= 4 else {
            return out
        }

        var paragraphs: [String] = []
        var index = 0
        while index < sentences.count {
            let chunkEnd = min(index + 2, sentences.count)
            paragraphs.append(sentences[index..<chunkEnd].joined(separator: " "))
            index = chunkEnd
        }

        return paragraphs.joined(separator: "\n\n")
    }

    private func cleanupPunctuationArtifacts(_ text: String) -> String {
        var out = text
        out = out.replacingOccurrences(of: ",\\s*([\\.!\\?])", with: "$1", options: .regularExpression)
        out = out.replacingOccurrences(of: "([\\.!\\?])\\s*,", with: "$1", options: .regularExpression)
        out = out.replacingOccurrences(of: "\\b(and|or|but)\\s*,\\s*(yeah|well|so|like|okay|ok|right)\\b", with: "$1 $2", options: [.regularExpression, .caseInsensitive])
        out = out.replacingOccurrences(of: "\\b([a-z]+(?:ward|ful|less|ive|al|ous|y)),\\s+([a-z]{3,})\\b", with: "$1 $2", options: [.regularExpression, .caseInsensitive])
        out = out.replacingOccurrences(of: "\\s+([,\\.!\\?;:])", with: "$1", options: .regularExpression)
        out = out.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applyAutomaticPunctuation(_ text: String) -> String {
        var normalized = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }

        let words = normalized.split(separator: " ").map(String.init)
        if words.count <= 4 {
            return appendTerminalPeriodIfNeeded(capitalizeFirstWord(words.joined(separator: " ")))
        }

        let commaTriggers: Set<String> = ["which", "because", "while", "although", "however", "though"]
        let sentenceTriggers: Set<String> = ["so", "then", "anyway", "meanwhile", "afterwards", "next"]
        let softBreakWords: Set<String> = ["and", "but", "so", "then", "because", "which"]

        var output: [String] = []
        var wordsInSentence = 0

        for rawWord in words {
            let lowerWord = rawWord.lowercased().trimmingCharacters(in: CharacterSet.punctuationCharacters)
            let shouldInsertSentenceBreak = wordsInSentence >= 18 && sentenceTriggers.contains(lowerWord)
            let shouldInsertSoftBreak = wordsInSentence >= 24 && softBreakWords.contains(lowerWord)

            if (shouldInsertSentenceBreak || shouldInsertSoftBreak), let lastToken = output.last {
                if !lastToken.hasSuffix(".") && !lastToken.hasSuffix("!") && !lastToken.hasSuffix("?") {
                    output[output.count - 1] = lastToken + "."
                }
                wordsInSentence = 0
            } else if wordsInSentence >= 8 && commaTriggers.contains(lowerWord), let lastToken = output.last {
                if !lastToken.hasSuffix(",") && !lastToken.hasSuffix(".") && !lastToken.hasSuffix("!") && !lastToken.hasSuffix("?") {
                    output[output.count - 1] = lastToken + ","
                }
            }

            let token = wordsInSentence == 0 ? capitalizeFirstWord(rawWord) : rawWord
            output.append(token)
            wordsInSentence += 1
        }

        normalized = output.joined(separator: " ")
        normalized = normalized.replacingOccurrences(of: "\\s+([,\\.!\\?;:])", with: "$1", options: .regularExpression)
        normalized = appendTerminalPeriodIfNeeded(normalized)
        return cleanupPunctuationArtifacts(applyParagraphHeuristics(normalized))
    }

    private func applyDeterministicFormatting(
        _ text: String,
        commandPriority: Bool,
        allowStructuralCommands: Bool
    ) -> FormattingResult {
        let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else {
            return FormattingResult(text: "", commandPriority: false)
        }
        let commandReady = normalizeCommandPhrases(original)
        let structuralCommandPattern = "\\b(new\\s*line|next\\s*line|line\\s*break|new\\s*paragraph|next\\s*paragraph|new\\s*para|next\\s*para|paragraph\\s*break|bullet\\s*point|bullet\\s*points?|new\\s*bullet|next\\s*bullet|next\\s*point|numbered\\s*list|(point|number)\\s*(one|two|three|four|five)|name\\s+(one|two|three|four|five|\\d+)\\s+things?)\\b"
        var effectiveCommandPriority = commandPriority
        if allowStructuralCommands,
           commandReady.range(of: structuralCommandPattern, options: [.regularExpression, .caseInsensitive]) != nil {
            effectiveCommandPriority = true
        }
        let hasListIntent = allowStructuralCommands && commandReady.range(
            of: "\\b(let'?s\\s+make\\s+a\\s+list|here'?s\\s+a\\s+list|make\\s+a\\s+list|numbered\\s*list|bullet\\s*points?|new\\s*bullet|next\\s*bullet|name\\s+(one|two|three|four|five|\\d+)\\s+things?)\\b",
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        var out = commandReady

        let punctuationReplacements: [(String, String)] = [
            ("\\b(full\\s*stop|period)\\b", "."),
            ("\\bdot\\b", "."),
            ("\\bcomma\\b", ","),
            ("\\bquestion\\s*mark\\b", "?"),
            ("\\bexclamation\\s*mark\\b", "!"),
            ("\\bsemicolon\\b", ";"),
            ("\\bcolon\\b", ":")
        ]

        let structuralReplacements: [(String, String)] = [
            ("\\b(new|next)\\s*para(graph)?\\b", "\n\n"),
            ("\\bparagraph\\s*break\\b", "\n\n"),
            ("\\b(new|next)\\s*line\\b", "\n"),
            ("\\bline\\s*break\\b", "\n"),
            ("\\bbullet\\s*points?\\b", "\n• "),
            ("\\b(new|next)\\s*bullet\\b", "\n• "),
            ("\\bnext\\s*point\\b", "\n• "),
            ("\\bnumbered\\s*list\\b", "\n1. "),
            ("\\b(point|number)\\s*one\\b", "\n1. "),
            ("\\b(point|number)\\s*two\\b", "\n2. "),
            ("\\b(point|number)\\s*three\\b", "\n3. "),
            ("\\b(point|number)\\s*four\\b", "\n4. "),
            ("\\b(point|number)\\s*five\\b", "\n5. "),
            ("\\b(first|one)\\s+(would\\s+be|is)\\b", "\n1. "),
            ("\\b(second|two)\\s+(would\\s+be|is)\\b", "\n2. "),
            ("\\b(third|three)\\s+(would\\s+be|is)\\b", "\n3. "),
            ("\\b(fourth|four)\\s+(would\\s+be|is)\\b", "\n4. "),
            ("\\b(fifth|five)\\s+(would\\s+be|is)\\b", "\n5. "),
            ("\\b(let'?s\\s+make\\s+a\\s+list|here'?s\\s+a\\s+list|make\\s+a\\s+list)\\b", "\n")
        ]

        if effectiveCommandPriority {
            for (pattern, replacement) in punctuationReplacements {
                out = out.replacingOccurrences(
                    of: pattern,
                    with: replacement,
                    options: [.regularExpression, .caseInsensitive]
                )
            }

            if allowStructuralCommands {
                for (pattern, replacement) in structuralReplacements {
                    out = out.replacingOccurrences(
                        of: pattern,
                        with: replacement,
                        options: [.regularExpression, .caseInsensitive]
                    )
                }
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
                out = renumberSequentialOnes(out)
            }
        }

        // Collapse filler disfluencies that often reduce readability.
        out = out.replacingOccurrences(of: "\\b(um+|uh+)\\b", with: "", options: [.regularExpression, .caseInsensitive])
        out = out.replacingOccurrences(of: "\\s*\\n\\s*", with: "\n", options: [.regularExpression])
        out = out.replacingOccurrences(of: "\\s*•\\s*", with: "\n• ", options: [.regularExpression])
        out = out.replacingOccurrences(of: "([\\.!\\?])\\s*•", with: "$1\n• ", options: [.regularExpression])
        out = out.replacingOccurrences(of: "\\n•\\s*[,\\.;:]+\\s*", with: "\n• ", options: [.regularExpression])
        out = out.replacingOccurrences(of: ",\\s*\\n•", with: "\n•", options: [.regularExpression])
        out = out.replacingOccurrences(of: "\\bnext\\s*\\n•", with: "\n•", options: [.regularExpression, .caseInsensitive])
        out = out.replacingOccurrences(of: "\\b(next|new)\\s*(?=\\n•)", with: "", options: [.regularExpression, .caseInsensitive])
        out = out.replacingOccurrences(of: "\\s*(\\d+\\.)\\s*", with: "\n$1 ", options: [.regularExpression])
        out = out.replacingOccurrences(of: "\\s+([,\\.!\\?])", with: "$1", options: [.regularExpression])
        out = out.replacingOccurrences(of: "([\\.!\\?]){2,}", with: "$1", options: [.regularExpression])
        out = out.replacingOccurrences(of: "([,;:]){2,}", with: "$1", options: [.regularExpression])
        out = out.replacingOccurrences(of: " {2,}", with: " ", options: [.regularExpression])
        out = out.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: [.regularExpression])

        out = out.trimmingCharacters(in: .whitespacesAndNewlines)
        if effectiveCommandPriority {
            if let first = out.first, first.isLetter {
                out.replaceSubrange(out.startIndex...out.startIndex, with: String(first).uppercased())
            }
            out = appendTerminalPeriodIfNeeded(out)
        } else {
            out = applyAutomaticPunctuation(out)
        }
        return FormattingResult(text: cleanupPunctuationArtifacts(out), commandPriority: effectiveCommandPriority)
    }

    private func containsExplicitCommand(_ text: String) -> Bool {
        let pattern = "\\b(comma|period|full\\s*stop|question\\s*mark|exclamation\\s*mark|semicolon|colon|new\\s*line|next\\s*line|line\\s*break|new\\s*paragraph|next\\s*paragraph|new\\s*para|next\\s*para|paragraph\\s*break|bullet\\s*point|bullet\\s*points?|new\\s*bullet|next\\s*bullet|next\\s*point|numbered\\s*list|(point|number)\\s*(one|two|three|four|five)|let'?s\\s+make\\s+a\\s+list|make\\s+a\\s+list|name\\s+(one|two|three|four|five|\\d+)\\s+things?)\\b"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func isLikelyLiteralCommandMention(_ text: String) -> Bool {
        let literalPatterns = [
            "\\b(when|if|about|saying|say|said|mention|mentioned|word|phrase|term|context|testing?)\\b.{0,30}\\b(new\\s*(paragraph|line|para)|next\\s*(paragraph|line|para)|paragraph\\s*break|line\\s*break|bullet\\s*point|numbered\\s*list)\\b",
            "\\b(new\\s*(paragraph|line|para)|next\\s*(paragraph|line|para)|paragraph\\s*break|line\\s*break|bullet\\s*point|numbered\\s*list)\\b.{0,30}\\b(when|if|about|saying|say|context|works?|does|doesn'?t|omit|omits|keeps|remove|removed|literal)\\b"
        ]

        for pattern in literalPatterns {
            if text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }
        return false
    }

    private func renumberSequentialOnes(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let onePattern = "^\\s*1\\.\\s+"
        let oneLines = lines.filter { $0.range(of: onePattern, options: .regularExpression) != nil }.count
        guard oneLines >= 2 else { return text }

        var nextNumber = 1
        let updated = lines.map { line -> String in
            guard line.range(of: onePattern, options: .regularExpression) != nil else {
                return line
            }
            let replacement = "\(nextNumber). "
            nextNumber += 1
            return line.replacingOccurrences(of: onePattern, with: replacement, options: .regularExpression)
        }
        return updated.joined(separator: "\n")
    }
}
