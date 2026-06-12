import Foundation

public struct TranscriptScore: Equatable, Sendable {
    public var hypothesis: String
    public var reference: String
    public var normalizedHypothesis: String
    public var normalizedReference: String
    public var referenceWordCount: Int
    public var wordEditDistance: Int
    public var characterEditDistance: Int
    public var wordErrorRate: Double
    public var characterErrorRate: Double

    public init(
        hypothesis: String,
        reference: String,
        normalizedHypothesis: String,
        normalizedReference: String,
        referenceWordCount: Int,
        wordEditDistance: Int,
        characterEditDistance: Int,
        wordErrorRate: Double,
        characterErrorRate: Double
    ) {
        self.hypothesis = hypothesis
        self.reference = reference
        self.normalizedHypothesis = normalizedHypothesis
        self.normalizedReference = normalizedReference
        self.referenceWordCount = referenceWordCount
        self.wordEditDistance = wordEditDistance
        self.characterEditDistance = characterEditDistance
        self.wordErrorRate = wordErrorRate
        self.characterErrorRate = characterErrorRate
    }
}

public struct BenchmarkSummary: Equatable, Sendable {
    public var sampleCount: Int
    public var averageWordErrorRate: Double
    public var averageCharacterErrorRate: Double

    public init(results: [TranscriptScore]) {
        sampleCount = results.count
        guard !results.isEmpty else {
            averageWordErrorRate = 0
            averageCharacterErrorRate = 0
            return
        }

        averageWordErrorRate = results.map(\.wordErrorRate).reduce(0, +) / Double(results.count)
        averageCharacterErrorRate = results.map(\.characterErrorRate).reduce(0, +) / Double(results.count)
    }
}

public struct TranscriptScorer: Sendable {
    public init() {}

    public func score(hypothesis: String, reference: String) -> TranscriptScore {
        let normalizedHypothesis = normalize(hypothesis)
        let normalizedReference = normalize(reference)
        let hypothesisWords = words(in: normalizedHypothesis)
        let referenceWords = words(in: normalizedReference)
        let wordDistance = editDistance(hypothesisWords, referenceWords)
        let characterDistance = editDistance(Array(normalizedHypothesis), Array(normalizedReference))
        let wer = referenceWords.isEmpty ? (hypothesisWords.isEmpty ? 0 : 1) : Double(wordDistance) / Double(referenceWords.count)
        let cer = normalizedReference.isEmpty ? (normalizedHypothesis.isEmpty ? 0 : 1) : Double(characterDistance) / Double(normalizedReference.count)

        return TranscriptScore(
            hypothesis: hypothesis,
            reference: reference,
            normalizedHypothesis: normalizedHypothesis,
            normalizedReference: normalizedReference,
            referenceWordCount: referenceWords.count,
            wordEditDistance: wordDistance,
            characterEditDistance: characterDistance,
            wordErrorRate: wer,
            characterErrorRate: cer
        )
    }

    public func normalize(_ text: String) -> String {
        var normalized = text.lowercased()
        normalized = normalized.replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: #"local\s+voice\s+flow"#, with: "localvoiceflow", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func words(in text: String) -> [String] {
        text.split { $0.isWhitespace }.map(String.init)
    }

    private func editDistance<Element: Equatable>(_ hypothesis: [Element], _ reference: [Element]) -> Int {
        if reference.isEmpty { return hypothesis.count }
        if hypothesis.isEmpty { return reference.count }

        var previous = Array(0...reference.count)
        var current = Array(repeating: 0, count: reference.count + 1)

        for hIndex in 1...hypothesis.count {
            current[0] = hIndex
            for rIndex in 1...reference.count {
                if hypothesis[hIndex - 1] == reference[rIndex - 1] {
                    current[rIndex] = previous[rIndex - 1]
                } else {
                    current[rIndex] = min(
                        previous[rIndex] + 1,
                        current[rIndex - 1] + 1,
                        previous[rIndex - 1] + 1
                    )
                }
            }
            swap(&previous, &current)
        }

        return previous[reference.count]
    }
}
