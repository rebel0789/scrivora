import Testing
@testable import LocalVoiceFlowCore

struct TextProcessingTests {
    @Test func commandProcessorReplacesDictationCommands() {
        let processor = DictationCommandProcessor()

        let result = processor.process("first line new line bullet point ship it period")

        #expect(result == "first line\n• ship it.")
    }

    @Test func commandProcessorHandlesTwoWordPunctuationCommands() {
        let processor = DictationCommandProcessor()

        let result = processor.process("is this better question mark yes escalation mark new line done full stop")

        #expect(result == "is this better? yes!\ndone.")
    }

    @Test func fastFormatterTrimsSpacingAndCapitalizes() {
        let formatter = FastTextFormatter()

        let result = formatter.format("   hello   world , this is local voice flow   ")

        #expect(result == "Hello world, this is local voice flow.")
    }

    @Test func postProcessorRemovesWhisperNonSpeechArtifacts() {
        let processor = TextPostProcessor()

        let result = processor.process("yeah it worked [Silence] and then (music) okay", settings: .init())

        #expect(result == "Yeah it worked and then okay.")
    }

    @Test func postProcessorDropsOnlySilenceArtifactToEmptyText() {
        let processor = TextPostProcessor()

        let result = processor.process("[Silence]", settings: .init())

        #expect(result == "")
    }

    @Test func postProcessorRemovesSmallFillerWords() {
        let processor = TextPostProcessor()

        let result = processor.process(
            "Okay uh design that now and um make punctuation better ahh",
            settings: .init(),
            profile: .agent
        )

        #expect(result == "Okay design that now and make punctuation better.")
    }

    @Test func customReplacementProcessorAppliesCaseInsensitiveWholePhraseRules() {
        let processor = CustomReplacementProcessor(replacements: [
            CustomReplacement(phrase: "polly chads", replacement: "PolyChads")
        ])

        #expect(processor.process("ship Polly Chads today") == "ship PolyChads today")
    }

    @Test func finalTranscriptBuilderDeduplicatesChunkOverlap() {
        var builder = FinalTranscriptBuilder()

        builder.appendStableText("Hello world, this")
        builder.appendStableText("world this is local")

        #expect(builder.finalText() == "Hello world, this is local")
    }

    @Test func repetitionReducerRemovesRepeatedWordsAndFragments() {
        let reducer = RepetitionReducer()

        #expect(reducer.process("hello hello I want I want to send this") == "hello I want to send this")
    }

    @Test func postProcessorFormatsBulletCommands() {
        let processor = TextPostProcessor()

        let result = processor.process("bullet point first item bullet point second item", settings: .init())

        #expect(result == "• First item\n• Second item")
    }

    @Test func pragmaticProfileDoesNotForceFinalPunctuationOrCapitalization() {
        let processor = TextPostProcessor()

        let result = processor.process(
            "return user profile after refresh",
            settings: .init(),
            profile: .pragmatic
        )

        #expect(result == "return user profile after refresh")
    }

    @Test func defaultReplacementsCorrectCommonAppAndInterfaceTerms() {
        let processor = TextPostProcessor()

        let result = processor.process(
            "keep the u a responsive in text edit",
            settings: .init(),
            profile: .general
        )

        #expect(result == "Keep the UI responsive in TextEdit.")
    }

    @Test func pragmaticProfileCorrectsCommonCodingMishears() {
        let processor = TextPostProcessor()

        let result = processor.process(
            "keep the UR responsive in text edit",
            settings: .init(),
            profile: .pragmatic
        )

        #expect(result == "keep the UI responsive in TextEdit")
    }

    @Test func emailProfileKeepsReadableSentenceFormatting() {
        let processor = TextPostProcessor()

        let result = processor.process(
            "please send the invoice tomorrow morning",
            settings: .init(),
            profile: .email
        )

        #expect(result == "Please send the invoice tomorrow morning.")
    }

    @Test func partialStabilizerSeparatesStablePrefixAndLiveTail() {
        var stabilizer = PartialTranscriptStabilizer(requiredRepeats: 2, stablePrefixWordCount: 4)

        let first = stabilizer.observe("I want to send the report tomorrow", chunkID: 1)
        let second = stabilizer.observe("I want to send the report tomorrow", chunkID: 2)

        #expect(first.isStable == false)
        #expect(first.stableText == "I want to send")
        #expect(first.unstableText == "the report tomorrow")
        #expect(second.isStable == true)
        #expect(second.stableText == "I want to send the report tomorrow")
    }
}
