import Testing
@testable import LocalVoiceFlowCore

struct TextProcessingTests {
    @Test func commandProcessorReplacesDictationCommands() {
        let processor = DictationCommandProcessor()

        let result = processor.process("first line new line bullet point ship it period")

        #expect(result == "first line\n- ship it.")
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

    @Test func customReplacementProcessorAppliesCaseInsensitiveWholePhraseRules() {
        let processor = CustomReplacementProcessor(replacements: [
            CustomReplacement(phrase: "polly chads", replacement: "PolyChads")
        ])

        #expect(processor.process("ship Polly Chads today") == "ship PolyChads today")
    }

    @Test func finalTranscriptBuilderDeduplicatesChunkOverlap() {
        var builder = FinalTranscriptBuilder()

        builder.appendStableText("hello world this")
        builder.appendStableText("world this is local")

        #expect(builder.finalText() == "hello world this is local")
    }
}
