import Testing
@testable import LocalVoiceFlowCore

struct BenchmarkTests {
    @Test func wordErrorRateCountsSubstitutionsInsertionsAndDeletions() {
        let scorer = TranscriptScorer()

        let metrics = scorer.score(
            hypothesis: "hello brave local app now",
            reference: "hello local voice app"
        )

        #expect(metrics.referenceWordCount == 4)
        #expect(metrics.wordEditDistance == 3)
        #expect(metrics.wordErrorRate == 0.75)
    }

    @Test func transcriptNormalizationIgnoresCasePunctuationAndExtraSpacing() {
        let scorer = TranscriptScorer()

        let metrics = scorer.score(
            hypothesis: "  Hello,   LocalVoiceFlow! ",
            reference: "hello local voice flow"
        )

        #expect(metrics.wordErrorRate == 0)
        #expect(metrics.characterErrorRate == 0)
    }

    @Test func benchmarkSummaryAveragesMetrics() {
        let scorer = TranscriptScorer()
        let results = [
            scorer.score(hypothesis: "hello world", reference: "hello world"),
            scorer.score(hypothesis: "hello brave world", reference: "hello world")
        ]

        let summary = BenchmarkSummary(results: results)

        #expect(summary.sampleCount == 2)
        #expect(summary.averageWordErrorRate == 0.25)
    }
}
