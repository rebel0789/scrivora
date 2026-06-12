import Foundation

public struct CustomReplacement: Codable, Equatable, Sendable {
    public var phrase: String
    public var replacement: String

    public init(phrase: String, replacement: String) {
        self.phrase = phrase
        self.replacement = replacement
    }

    public static let defaults: [CustomReplacement] = [
        CustomReplacement(phrase: "local voice flow", replacement: "LocalVoiceFlow"),
        CustomReplacement(phrase: "scrivora", replacement: "Scrivora"),
        CustomReplacement(phrase: "u i", replacement: "UI"),
        CustomReplacement(phrase: "ui", replacement: "UI"),
        CustomReplacement(phrase: "u a", replacement: "UI"),
        CustomReplacement(phrase: "ua", replacement: "UI"),
        CustomReplacement(phrase: "text edit", replacement: "TextEdit"),
        CustomReplacement(phrase: "v s code", replacement: "VS Code")
    ]

    public static func mergingDefaults(with replacements: [CustomReplacement]) -> [CustomReplacement] {
        let replacementKeys = Set(replacements.map { normalizedPhrase($0.phrase) })
        let missingDefaults = defaults.filter { !replacementKeys.contains(normalizedPhrase($0.phrase)) }
        return missingDefaults + replacements
    }

    private static func normalizedPhrase(_ phrase: String) -> String {
        phrase.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

public struct UserDictionaryEntry: Codable, Equatable, Sendable {
    public var spokenForm: String
    public var writtenForm: String

    public init(spokenForm: String, writtenForm: String) {
        self.spokenForm = spokenForm
        self.writtenForm = writtenForm
    }
}

public struct DictationCommandProcessor: Sendable {
    public init() {}

    public func process(_ input: String) -> String {
        let rawTokens = input.split { $0.isWhitespace }.map(String.init)
        var output = ""
        var index = 0

        while index < rawTokens.count {
            let current = normalizedCommandToken(rawTokens[index])
            let next = index + 1 < rawTokens.count ? normalizedCommandToken(rawTokens[index + 1]) : ""

            if current == "new", next == "paragraph" {
                appendControl("\n\n", to: &output)
                index += 2
                continue
            }

            if current == "new", next == "line" {
                appendControl("\n", to: &output)
                index += 2
                continue
            }

            if current == "bullet", next == "point" {
                if !output.isEmpty, !output.hasSuffix("\n") {
                    output.append("\n")
                }
                output.append("• ")
                index += 2
                continue
            }

            if let punctuation = punctuation(for: "\(current)-\(next)") {
                output = output.trimmingCharacters(in: .whitespaces)
                output.append(punctuation)
                index += 2
                continue
            }

            if let punctuation = punctuation(for: current) {
                output = output.trimmingCharacters(in: .whitespaces)
                output.append(punctuation)
                index += 1
                continue
            }

            appendWord(rawTokens[index], to: &output)
            index += 1
        }

        return output.trimmingCharacters(in: .whitespaces)
    }

    private func punctuation(for token: String) -> String? {
        switch token {
        case "comma": ","
        case "period", "fullstop", "full-stop": "."
        case "questionmark", "question-mark": "?"
        case "exclamationmark", "exclamation-mark", "exclamation-point", "exclamationpoint": "!"
        case "escalationmark", "escalation-mark", "exclaimationmark", "exclaimation-mark": "!"
        case "colon": ":"
        case "semicolon": ";"
        default: nil
        }
    }

    private func normalizedCommandToken(_ token: String) -> String {
        token.lowercased()
            .trimmingCharacters(in: CharacterSet.punctuationCharacters)
            .replacingOccurrences(of: " ", with: "")
    }

    private func appendControl(_ control: String, to output: inout String) {
        output = output.trimmingCharacters(in: .whitespaces)
        output.append(control)
    }

    private func appendWord(_ word: String, to output: inout String) {
        if output.isEmpty || output.hasSuffix("\n") || output.hasSuffix("- ") || output.hasSuffix("• ") {
            output.append(word)
        } else {
            output.append(" ")
            output.append(word)
        }
    }
}

public struct CustomReplacementProcessor: Sendable {
    public var replacements: [CustomReplacement]

    public init(replacements: [CustomReplacement]) {
        self.replacements = replacements
    }

    public func process(_ input: String) -> String {
        replacements.reduce(input) { current, replacement in
            guard !replacement.phrase.isEmpty else { return current }
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: replacement.phrase) + "\\b"
            return current.replacingOccurrences(
                of: pattern,
                with: replacement.replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
    }
}

public struct UserDictionaryProcessor: Sendable {
    public var entries: [UserDictionaryEntry]

    public init(entries: [UserDictionaryEntry]) {
        self.entries = entries
    }

    public func process(_ input: String) -> String {
        entries.reduce(input) { current, entry in
            guard !entry.spokenForm.isEmpty else { return current }
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: entry.spokenForm) + "\\b"
            return current.replacingOccurrences(
                of: pattern,
                with: entry.writtenForm,
                options: [.regularExpression, .caseInsensitive]
            )
        }
    }
}

public struct FastTextFormatter: Sendable {
    public init() {}

    public func format(
        _ input: String,
        forceFinalPunctuation: Bool = true,
        capitalizeSentenceStarts shouldCapitalizeSentenceStarts: Bool = true
    ) -> String {
        var text = input
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespaces)

        text = regexReplace("[ \\t]+", in: text, with: " ")
        text = regexReplace(" +\\n", in: text, with: "\n")
        text = regexReplace("\\n +", in: text, with: "\n")
        text = regexReplace("\\n{3,}", in: text, with: "\n\n")
        text = regexReplace(" +([,.;:!?])", in: text, with: "$1")
        text = regexReplace("([\\(\\[\\{]) +", in: text, with: "$1")
        text = regexReplace(" +([\\)\\]\\}])", in: text, with: "$1")
        if shouldCapitalizeSentenceStarts {
            text = capitalizeSentenceStarts(text)
        }

        if forceFinalPunctuation, let last = text.last, !isBulletList(text), !".!?;:\n".contains(last) {
            text.append(".")
        }

        return text
    }

    private func regexReplace(_ pattern: String, in text: String, with replacement: String) -> String {
        text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
    }

    private func isBulletList(_ text: String) -> Bool {
        text.split(separator: "\n").contains { line in
            line.trimmingCharacters(in: .whitespaces).hasPrefix("• ")
        }
    }

    private func capitalizeSentenceStarts(_ text: String) -> String {
        var result = ""
        var shouldCapitalize = true

        for scalar in text.unicodeScalars {
            let character = Character(scalar)
            if shouldCapitalize, CharacterSet.letters.contains(scalar) {
                result.append(String(character).uppercased())
                shouldCapitalize = false
            } else {
                result.append(character)
            }

            if ".!?\n".unicodeScalars.contains(scalar) {
                shouldCapitalize = true
            } else if !CharacterSet.whitespacesAndNewlines.contains(scalar), !CharacterSet.punctuationCharacters.contains(scalar) {
                shouldCapitalize = false
            }
        }

        return result
    }
}

public struct NonSpeechArtifactFilter: Sendable {
    public init() {}

    public func process(_ input: String) -> String {
        var text = input
        let artifactWords = [
            "silence",
            "silent",
            "music",
            "applause",
            "laughter",
            "laughs",
            "noise",
            "inaudible",
            "blank_audio",
            "no speech"
        ]
        let artifactPattern = artifactWords
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")

        text = regexReplace("(?i)<\\|[^>]+\\|>", in: text, with: " ")
        text = regexReplace("(?i)\\[(?:\(artifactPattern))\\]", in: text, with: " ")
        text = regexReplace("(?i)\\((?:\(artifactPattern))\\)", in: text, with: " ")
        text = regexReplace("(?i)\\b(?:\(artifactPattern))\\b[.!?,;:]*", in: text, with: " ")
        text = regexReplace("[ \\t]+", in: text, with: " ")
        text = regexReplace(" *\\n *", in: text, with: "\n")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func regexReplace(_ pattern: String, in text: String, with replacement: String) -> String {
        text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
    }
}

public typealias ASRArtifactCleaner = NonSpeechArtifactFilter

public struct FillerWordFilter: Sendable {
    public init() {}

    public func process(_ input: String) -> String {
        var text = input
        let fillerPattern = "\\b(?:uh+|um+|ah+|a+h+|er+m*|hmm+|mm+)\\b[,.!?;:]*"
        text = regexReplace("(?i)\(fillerPattern)", in: text, with: " ")
        text = regexReplace("[ \\t]{2,}", in: text, with: " ")
        text = regexReplace(" *\\n *", in: text, with: "\n")
        text = regexReplace("\\s+([,.;:!?])", in: text, with: "$1")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func regexReplace(_ pattern: String, in text: String, with replacement: String) -> String {
        text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
    }
}

public struct RepetitionReducer: Sendable {
    public init() {}

    public func process(_ input: String) -> String {
        let tokens = input.split { $0.isWhitespace }.map(String.init)
        guard tokens.count > 1 else { return input.trimmingCharacters(in: .whitespacesAndNewlines) }

        var reduced: [String] = []
        for token in tokens {
            if let previous = reduced.last, normalized(previous) == normalized(token) {
                continue
            }
            reduced.append(token)
        }

        return reduceRepeatedPhrases(reduced).joined(separator: " ")
    }

    private func reduceRepeatedPhrases(_ tokens: [String]) -> [String] {
        var output: [String] = []
        var index = 0

        while index < tokens.count {
            var skipped = false
            let maxLength = min(6, (tokens.count - index) / 2)
            if maxLength > 0 {
                for length in stride(from: maxLength, through: 2, by: -1) {
                    let first = tokens[index..<(index + length)].map(normalized)
                    let second = tokens[(index + length)..<(index + length * 2)].map(normalized)
                    if first == second {
                        output.append(contentsOf: tokens[index..<(index + length)])
                        index += length * 2
                        skipped = true
                        break
                    }
                }
            }
            if !skipped {
                output.append(tokens[index])
                index += 1
            }
        }

        return output
    }

    private func normalized(_ token: String) -> String {
        token.lowercased().trimmingCharacters(in: .punctuationCharacters)
    }
}

public typealias PunctuationHeuristicFormatter = FastTextFormatter

public struct FinalTextNormalizer: Sendable {
    public init() {}

    public func process(_ input: String) -> String {
        var text = input
        text = regexReplace("[ \\t]+", in: text, with: " ")
        text = regexReplace(" *\\n *", in: text, with: "\n")
        text = regexReplace("\\n{3,}", in: text, with: "\n\n")
        text = regexReplace("([,.;:!?])([^\\s\\n])", in: text, with: "$1 $2")
        text = regexReplace(" +([,.;:!?])", in: text, with: "$1")
        return text.trimmingCharacters(in: .whitespaces)
    }

    private func regexReplace(_ pattern: String, in text: String, with replacement: String) -> String {
        text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
    }
}

public struct TextPostProcessor: Sendable {
    private let commandProcessor: DictationCommandProcessor
    private let formatter: FastTextFormatter
    private let artifactFilter: NonSpeechArtifactFilter
    private let fillerFilter: FillerWordFilter
    private let repetitionReducer: RepetitionReducer
    private let finalNormalizer: FinalTextNormalizer

    public init(
        commandProcessor: DictationCommandProcessor = DictationCommandProcessor(),
        formatter: FastTextFormatter = FastTextFormatter(),
        artifactFilter: NonSpeechArtifactFilter = NonSpeechArtifactFilter(),
        fillerFilter: FillerWordFilter = FillerWordFilter(),
        repetitionReducer: RepetitionReducer = RepetitionReducer(),
        finalNormalizer: FinalTextNormalizer = FinalTextNormalizer()
    ) {
        self.commandProcessor = commandProcessor
        self.formatter = formatter
        self.artifactFilter = artifactFilter
        self.fillerFilter = fillerFilter
        self.repetitionReducer = repetitionReducer
        self.finalNormalizer = finalNormalizer
    }

    public func process(_ input: String, settings: PostProcessingSettings) -> String {
        process(input, settings: settings, profile: settings.outputProfile == .automatic ? .general : settings.outputProfile)
    }

    public func process(
        _ input: String,
        settings: PostProcessingSettings,
        profile: DictationOutputProfile
    ) -> String {
        var text = artifactFilter.process(input)

        if settings.cleanupMode != .raw, profile != .raw {
            text = fillerFilter.process(text)
            text = repetitionReducer.process(text)
            text = commandProcessor.process(text)
            text = CustomReplacementProcessor(
                replacements: CustomReplacement.mergingDefaults(with: profileSpecificReplacements(profile) + settings.customReplacements)
            ).process(text)
            text = UserDictionaryProcessor(entries: settings.userDictionary).process(text)
            text = formatter.format(
                text,
                forceFinalPunctuation: shouldForceFinalPunctuation(profile: profile, preset: settings.preset),
                capitalizeSentenceStarts: shouldCapitalizeSentenceStarts(profile: profile)
            )
            text = finalNormalizer.process(text)
        }

        return text
    }

    private func shouldForceFinalPunctuation(
        profile: DictationOutputProfile,
        preset: PostProcessingPreset
    ) -> Bool {
        switch profile {
        case .pragmatic, .raw:
            return false
        case .automatic:
            return preset != .codeComments
        case .general, .agent, .email:
            return true
        }
    }

    private func shouldCapitalizeSentenceStarts(profile: DictationOutputProfile) -> Bool {
        switch profile {
        case .pragmatic, .raw:
            return false
        case .automatic, .general, .agent, .email:
            return true
        }
    }

    private func profileSpecificReplacements(_ profile: DictationOutputProfile) -> [CustomReplacement] {
        switch profile {
        case .pragmatic:
            return [
                CustomReplacement(phrase: "u r", replacement: "UI"),
                CustomReplacement(phrase: "ur", replacement: "UI")
            ]
        case .automatic, .general, .agent, .email, .raw:
            return []
        }
    }
}
