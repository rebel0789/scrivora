import Foundation
import Testing
@testable import LocalVoiceFlowCore

struct CorrectionLearningTests {
    @Test func learnerExtractsShortAcronymCorrection() {
        let result = CorrectionLearner().learn(
            original: "keep the UR responsive in text edit",
            corrected: "keep the UI responsive in TextEdit"
        )

        #expect(result.entries.contains(UserDictionaryEntry(spokenForm: "UR", writtenForm: "UI")))
        #expect(result.entries.contains(UserDictionaryEntry(spokenForm: "text edit", writtenForm: "TextEdit")))
    }

    @Test func learnerExtractsSpellingLikeCorrection() {
        let result = CorrectionLearner().learn(
            original: "make pnchuations better",
            corrected: "make punctuations better"
        )

        #expect(result.entries == [
            UserDictionaryEntry(spokenForm: "pnchuations", writtenForm: "punctuations")
        ])
    }

    @Test func learnerAvoidsOverBroadSentenceRewriteRules() {
        let result = CorrectionLearner().learn(
            original: "And escalation mark",
            corrected: "yes"
        )

        #expect(result.entries.isEmpty)
    }

    @Test func correctionStorePersistsRecordsAndStats() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = CorrectionStore(directory: directory)
        let record = CorrectionRecord(
            originalTranscript: "keep the UR responsive",
            correctedTranscript: "keep the UI responsive",
            targetAppName: "Cursor",
            asrModelID: "fluidaudio-parakeet-v3",
            outputProfile: "pragmatic",
            learnedEntries: [UserDictionaryEntry(spokenForm: "UR", writtenForm: "UI")]
        )

        try store.append(record)
        let records = try store.load()
        let stats = try store.stats()

        #expect(records.count == 1)
        #expect(records.first?.learnedEntries.first?.writtenForm == "UI")
        #expect(stats.correctionCount == 1)
        #expect(stats.learnedEntryCount == 1)
    }
}
