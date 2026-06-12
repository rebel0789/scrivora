import Foundation

public struct PartialTranscriptStabilizer: Sendable {
    private var lastText: String = ""
    private var stableText: String = ""
    private var repeatCount: Int = 0
    private let requiredRepeats: Int
    private let stablePrefixWordCount: Int

    public init(requiredRepeats: Int = 2, stablePrefixWordCount: Int = 8) {
        self.requiredRepeats = max(1, requiredRepeats)
        self.stablePrefixWordCount = max(1, stablePrefixWordCount)
    }

    public mutating func observe(_ text: String, chunkID: Int) -> ASRPartialResult {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized == lastText {
            repeatCount += 1
        } else {
            lastText = normalized
            repeatCount = 1
        }

        if repeatCount >= requiredRepeats {
            stableText = normalized
        } else {
            stableText = stablePrefix(in: normalized)
        }

        let unstable = unstableTail(fullText: normalized, stableText: stableText)
        return ASRPartialResult(
            text: normalized,
            stableText: stableText,
            unstableText: unstable,
            chunkID: chunkID,
            isStable: repeatCount >= requiredRepeats
        )
    }

    public mutating func reset() {
        lastText = ""
        stableText = ""
        repeatCount = 0
    }

    private func stablePrefix(in text: String) -> String {
        let words = tokenize(text)
        guard words.count > stablePrefixWordCount else { return "" }
        return words.dropLast(min(3, words.count)).joined(separator: " ")
    }

    private func unstableTail(fullText: String, stableText: String) -> String {
        guard !stableText.isEmpty else { return fullText }
        if fullText == stableText { return "" }
        guard fullText.lowercased().hasPrefix(stableText.lowercased()) else { return fullText }
        return String(fullText.dropFirst(stableText.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tokenize(_ text: String) -> [String] {
        text.split { $0.isWhitespace }.map(String.init)
    }
}

public struct ChunkDeduplicator: Sendable {
    public init() {}

    public func append(existing: [String], incoming: [String]) -> [String] {
        guard !incoming.isEmpty else { return existing }
        guard !existing.isEmpty else { return incoming }
        let overlap = longestSuffixPrefixOverlap(existing: existing, incoming: incoming)
        return existing + incoming.dropFirst(overlap)
    }

    public func longestSuffixPrefixOverlap(existing: [String], incoming: [String]) -> Int {
        guard !existing.isEmpty, !incoming.isEmpty else { return 0 }
        let maxOverlap = min(existing.count, incoming.count)
        for length in stride(from: maxOverlap, through: 1, by: -1) {
            let suffix = existing.suffix(length).map(normalized)
            let prefix = incoming.prefix(length).map(normalized)
            if suffix == prefix {
                return length
            }
        }
        return 0
    }

    private func normalized(_ token: String) -> String {
        token.lowercased().trimmingCharacters(in: .punctuationCharacters)
    }
}

public struct FinalTranscriptBuilder: Sendable {
    private var words: [String] = []
    private let deduplicator: ChunkDeduplicator

    public init(deduplicator: ChunkDeduplicator = ChunkDeduplicator()) {
        self.deduplicator = deduplicator
    }

    public mutating func appendStableText(_ text: String) {
        let incoming = tokenize(text)
        guard !incoming.isEmpty else { return }
        words = deduplicator.append(existing: words, incoming: incoming)
    }

    public func finalText() -> String {
        words.joined(separator: " ")
    }

    public mutating func reset() {
        words.removeAll()
    }

    private func tokenize(_ text: String) -> [String] {
        text.split { $0.isWhitespace }.map(String.init)
    }

}
