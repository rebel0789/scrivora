import Testing
@testable import LocalVoiceFlowCore

struct AudioPipelineTests {
    @Test func ringBufferKeepsNewestSamplesWhenCapacityIsExceeded() {
        let buffer = AudioRingBuffer(capacity: 5)

        buffer.append([1, 2, 3])
        buffer.append([4, 5, 6, 7])

        #expect(buffer.snapshot() == [3, 4, 5, 6, 7])
    }

    @Test func voiceActivityDetectorUsesFrameEnergy() {
        let detector = VoiceActivityDetector(energyThreshold: 0.02)

        #expect(detector.isSpeech([0.001, -0.001, 0.002]) == false)
        #expect(detector.isSpeech([0.01, 0.08, -0.07, 0.02]) == true)
    }

    @Test func silenceDetectorEndsAfterConfiguredSpeechGap() {
        var detector = SilenceDetector(requiredSilentFrames: 3)

        #expect(detector.observe(isSpeech: true) == false)
        #expect(detector.observe(isSpeech: false) == false)
        #expect(detector.observe(isSpeech: false) == false)
        #expect(detector.observe(isSpeech: false) == true)
    }

    @Test func chunkSchedulerEmitsOverlappingRollingChunks() {
        var scheduler = ChunkScheduler(
            sampleRate: 10,
            chunkLengthSeconds: 1.0,
            overlapSeconds: 0.2
        )

        #expect(scheduler.append(Array(repeating: 0.1, count: 9)).isEmpty)
        let first = scheduler.append([0.1])
        #expect(first.count == 1)
        #expect(first[0].samples.count == 10)
        #expect(first[0].startSample == 0)

        let second = scheduler.append(Array(repeating: 0.2, count: 8))
        #expect(second.count == 1)
        #expect(second[0].startSample == 8)
        #expect(Array(second[0].samples.prefix(2)) == [0.1, 0.1])
    }
}
