import Foundation

public struct PartialTranscriptStabilizer: Sendable {
    private var lastText: String = ""
    private var repeatCount: Int = 0
    private let requiredRepeats: Int

    public init(requiredRepeats: Int = 2) {
        self.requiredRepeats = max(1, requiredRepeats)
    }

    public mutating func observe(_ text: String, chunkID: Int) -> ASRPartialResult {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized == lastText {
            repeatCount += 1
        } else {
            lastText = normalized
            repeatCount = 1
        }
        return ASRPartialResult(text: normalized, chunkID: chunkID, isStable: repeatCount >= requiredRepeats)
    }
}

public struct FinalTranscriptBuilder: Sendable {
    private var words: [String] = []

    public init() {}

    public mutating func appendStableText(_ text: String) {
        let incoming = tokenize(text)
        guard !incoming.isEmpty else { return }

        let overlap = longestSuffixPrefixOverlap(existing: words, incoming: incoming)
        words.append(contentsOf: incoming.dropFirst(overlap))
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

    private func longestSuffixPrefixOverlap(existing: [String], incoming: [String]) -> Int {
        guard !existing.isEmpty, !incoming.isEmpty else { return 0 }
        let maxOverlap = min(existing.count, incoming.count)
        for length in stride(from: maxOverlap, through: 1, by: -1) {
            if Array(existing.suffix(length)) == Array(incoming.prefix(length)) {
                return length
            }
        }
        return 0
    }
}

