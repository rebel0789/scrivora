import Foundation
import FluidAudio
import LocalVoiceFlowCore

actor FluidAudioBatchASREngine: ASREngine {
    private let finalSilencePaddingSeconds: Double
    private var loadedModel: ASRModelInfo?
    private var manager: AsrManager?

    init(finalSilencePaddingSeconds: Double = 0.5) {
        self.finalSilencePaddingSeconds = finalSilencePaddingSeconds
    }

    var isLoaded: Bool {
        loadedModel != nil && manager != nil
    }

    var modelInfo: ASRModelInfo? {
        loadedModel
    }

    func loadModel(_ model: ASRModelInfo) async throws {
        if loadedModel?.id == model.id, manager != nil {
            return
        }

        let version = try FluidAudioModelSupport.version(for: model)
        let directory = AsrModels.defaultCacheDirectory(for: version)
        guard AsrModels.modelsExist(at: directory, version: version) else {
            throw LocalVoiceFlowError.modelUnavailable(
                "\(model.displayName) is not downloaded. Download it in Settings before selecting it."
            )
        }

        let models = try await AsrModels.load(from: directory, version: version)
        let asrManager = AsrManager(config: .default)
        try await asrManager.loadModels(models)

        manager = asrManager
        loadedModel = model
    }

    func warmup() async throws {
        guard manager != nil else { throw LocalVoiceFlowError.modelNotLoaded }
    }

    func transcribe(chunk: AudioChunk) async throws -> ASRPartialResult {
        ASRPartialResult(text: "", chunkID: chunk.id, isStable: false)
    }

    func transcribeFinal(buffer: AudioBuffer) async throws -> LocalVoiceFlowCore.ASRResult {
        guard let model = loadedModel, let manager else {
            throw LocalVoiceFlowError.modelNotLoaded
        }
        guard buffer.sampleRate == 16_000 else {
            throw LocalVoiceFlowError.invalidAudio("FluidAudio expects 16 kHz audio, got \(buffer.sampleRate) Hz.")
        }
        guard !buffer.samples.isEmpty else {
            throw LocalVoiceFlowError.invalidAudio("No captured samples.")
        }

        var decoderState = try TdtDecoderState(decoderLayers: await manager.decoderLayerCount)
        let samples = paddedFinalSamples(buffer.samples, sampleRate: buffer.sampleRate)
        let stopwatch = Stopwatch()

        do {
            let result = try await manager.transcribe(samples, decoderState: &decoderState)
            return LocalVoiceFlowCore.ASRResult(
                text: result.text.trimmingCharacters(in: .whitespacesAndNewlines),
                latency: stopwatch.elapsedSeconds(),
                modelID: model.id
            )
        } catch {
            throw LocalVoiceFlowError.transcriptionFailed("FluidAudio failed: \(error.localizedDescription)")
        }
    }

    func unload() async {
        await manager?.cleanup()
        manager = nil
        loadedModel = nil
    }

    private func paddedFinalSamples(_ samples: [Float], sampleRate: Int) -> [Float] {
        let paddingCount = max(0, Int(Double(sampleRate) * finalSilencePaddingSeconds))
        guard paddingCount > 0 else { return samples }
        return samples + Array(repeating: 0, count: paddingCount)
    }
}
