import Foundation

public struct CorrectionLearningResult: Equatable, Sendable {
    public var entries: [UserDictionaryEntry]

    public init(entries: [UserDictionaryEntry]) {
        self.entries = entries
    }
}

public struct CorrectionLearner: Sendable {
    public init() {}

    public func learn(original: String, corrected: String) -> CorrectionLearningResult {
        let originalTokens = tokenize(original)
        let correctedTokens = tokenize(corrected)
        guard !originalTokens.isEmpty, !correctedTokens.isEmpty else {
            return CorrectionLearningResult(entries: [])
        }

        let spans = changedSpans(original: originalTokens, corrected: correctedTokens)
        let entries = spans.compactMap(makeEntry(original:corrected:))
        return CorrectionLearningResult(entries: dedupe(entries))
    }

    private func tokenize(_ text: String) -> [String] {
        text.split { scalar in
            scalar.isWhitespace || scalar.isNewline
        }
        .map {
            String($0).trimmingCharacters(in: .punctuationCharacters)
        }
        .filter { !$0.isEmpty }
    }

    private func changedSpans(original: [String], corrected: [String]) -> [([String], [String])] {
        let m = original.count
        let n = corrected.count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }

        if m > 0, n > 0 {
            for i in 1...m {
                for j in 1...n {
                    let cost = normalized(original[i - 1]) == normalized(corrected[j - 1]) ? 0 : 1
                    dp[i][j] = min(
                        dp[i - 1][j] + 1,
                        dp[i][j - 1] + 1,
                        dp[i - 1][j - 1] + cost
                    )
                }
            }
        }

        var operations: [([String], [String])] = []
        var i = m
        var j = n
        while i > 0 || j > 0 {
            if i > 0, j > 0, normalized(original[i - 1]) == normalized(corrected[j - 1]), dp[i][j] == dp[i - 1][j - 1] {
                operations.append(([original[i - 1]], [corrected[j - 1]]))
                i -= 1
                j -= 1
            } else if i > 0, j > 0, dp[i][j] == dp[i - 1][j - 1] + 1 {
                operations.append(([original[i - 1]], [corrected[j - 1]]))
                i -= 1
                j -= 1
            } else if i > 0, dp[i][j] == dp[i - 1][j] + 1 {
                operations.append(([original[i - 1]], []))
                i -= 1
            } else if j > 0 {
                operations.append(([], [corrected[j - 1]]))
                j -= 1
            }
        }

        operations.reverse()

        var spans: [([String], [String])] = []
        var currentOriginal: [String] = []
        var currentCorrected: [String] = []

        func flush() {
            guard !currentOriginal.isEmpty || !currentCorrected.isEmpty else { return }
            spans.append((currentOriginal, currentCorrected))
            currentOriginal = []
            currentCorrected = []
        }

        for (originalPart, correctedPart) in operations {
            if originalPart.map(normalized) == correctedPart.map(normalized) {
                flush()
            } else {
                currentOriginal.append(contentsOf: originalPart)
                currentCorrected.append(contentsOf: correctedPart)
            }
        }
        flush()

        return spans
    }

    private func makeEntry(original: [String], corrected: [String]) -> UserDictionaryEntry? {
        guard !original.isEmpty, !corrected.isEmpty else { return nil }
        guard original.count <= 3, corrected.count <= 3 else { return nil }

        let spoken = original.joined(separator: " ")
        let written = corrected.joined(separator: " ")
        let normalizedSpoken = normalizedPhrase(spoken)
        let normalizedWritten = normalizedPhrase(written)
        guard normalizedSpoken != normalizedWritten else { return nil }
        guard normalizedSpoken.count >= 2, normalizedWritten.count >= 2 else { return nil }
        guard !containsBlockedLearningWord(original) else { return nil }

        let isLikelyTypo = editDistance(Array(normalizedSpoken), Array(normalizedWritten)) <= max(2, normalizedWritten.count / 2)
        let isAcronymOrBrand = containsMeaningfulCapitalization(written)
        let isCollapsedPhrase = original.count > corrected.count && written.contains(" ") == false
        let isShortAcronymMishear = normalizedSpoken.count <= 3 && normalizedWritten.count <= 3

        guard isLikelyTypo || isAcronymOrBrand || isCollapsedPhrase || isShortAcronymMishear else {
            return nil
        }

        return UserDictionaryEntry(spokenForm: spoken, writtenForm: written)
    }

    private func containsBlockedLearningWord(_ tokens: [String]) -> Bool {
        let blocked: Set<String> = [
            "a", "an", "and", "are", "as", "at", "be", "but", "for", "from",
            "i", "in", "is", "it", "no", "of", "okay", "on", "or", "so",
            "that", "the", "this", "to", "we", "with", "yes", "you"
        ]
        return tokens.contains { blocked.contains(normalized($0)) }
    }

    private func containsMeaningfulCapitalization(_ text: String) -> Bool {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return false }
        let upperCount = letters.filter { CharacterSet.uppercaseLetters.contains($0) }.count
        return upperCount >= 2 || text.range(of: "[a-z][A-Z]", options: .regularExpression) != nil
    }

    private func dedupe(_ entries: [UserDictionaryEntry]) -> [UserDictionaryEntry] {
        var seen = Set<String>()
        var result: [UserDictionaryEntry] = []
        for entry in entries {
            let key = normalizedPhrase(entry.spokenForm)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(entry)
        }
        return result
    }

    private func normalized(_ token: String) -> String {
        token.trimmingCharacters(in: .punctuationCharacters).lowercased()
    }

    private func normalizedPhrase(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func editDistance<T: Equatable>(_ lhs: [T], _ rhs: [T]) -> Int {
        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }

        var previous = Array(0...rhs.count)
        var current = Array(repeating: 0, count: rhs.count + 1)
        for i in 1...lhs.count {
            current[0] = i
            for j in 1...rhs.count {
                if lhs[i - 1] == rhs[j - 1] {
                    current[j] = previous[j - 1]
                } else {
                    current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + 1)
                }
            }
            swap(&previous, &current)
        }
        return previous[rhs.count]
    }
}
