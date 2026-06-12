import Foundation

public struct CustomReplacement: Codable, Equatable, Sendable {
    public var phrase: String
    public var replacement: String

    public init(phrase: String, replacement: String) {
        self.phrase = phrase
        self.replacement = replacement
    }

    public static let defaults: [CustomReplacement] = [
        CustomReplacement(phrase: "local voice flow", replacement: "LocalVoiceFlow")
    ]
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
                output.append("- ")
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

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func punctuation(for token: String) -> String? {
        switch token {
        case "comma": ","
        case "period", "fullstop", "full-stop": "."
        case "questionmark", "question-mark": "?"
        case "exclamationmark", "exclamation-point", "exclamationpoint": "!"
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
        if output.isEmpty || output.hasSuffix("\n") || output.hasSuffix("- ") {
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

    public func format(_ input: String) -> String {
        var text = input
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        text = regexReplace("[ \\t]+", in: text, with: " ")
        text = regexReplace(" +\\n", in: text, with: "\n")
        text = regexReplace("\\n +", in: text, with: "\n")
        text = regexReplace(" +([,.;:!?])", in: text, with: "$1")
        text = regexReplace("([\\(\\[\\{]) +", in: text, with: "$1")
        text = regexReplace(" +([\\)\\]\\}])", in: text, with: "$1")
        text = capitalizeSentenceStarts(text)

        if let last = text.last, !".!?;:\n".contains(last) {
            text.append(".")
        }

        return text
    }

    private func regexReplace(_ pattern: String, in text: String, with replacement: String) -> String {
        text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
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
        text = regexReplace("[ \\t]+", in: text, with: " ")
        text = regexReplace(" *\\n *", in: text, with: "\n")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func regexReplace(_ pattern: String, in text: String, with replacement: String) -> String {
        text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
    }
}

public struct TextPostProcessor: Sendable {
    private let commandProcessor: DictationCommandProcessor
    private let formatter: FastTextFormatter
    private let artifactFilter: NonSpeechArtifactFilter

    public init(
        commandProcessor: DictationCommandProcessor = DictationCommandProcessor(),
        formatter: FastTextFormatter = FastTextFormatter(),
        artifactFilter: NonSpeechArtifactFilter = NonSpeechArtifactFilter()
    ) {
        self.commandProcessor = commandProcessor
        self.formatter = formatter
        self.artifactFilter = artifactFilter
    }

    public func process(_ input: String, settings: PostProcessingSettings) -> String {
        var text = artifactFilter.process(input)

        if settings.cleanupMode != .raw {
            text = commandProcessor.process(text)
            text = CustomReplacementProcessor(replacements: settings.customReplacements).process(text)
            text = UserDictionaryProcessor(entries: settings.userDictionary).process(text)
            text = formatter.format(text)
        }

        return text
    }
}
