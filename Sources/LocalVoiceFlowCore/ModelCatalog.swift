import Foundation

public struct ModelCatalog: Sendable {
    public var models: [ASRModelInfo]
    public var llmModels: [LLMModelInfo]

    public init(models: [ASRModelInfo], llmModels: [LLMModelInfo]) {
        self.models = models
        self.llmModels = llmModels
    }

    public func recommendedModel(for mode: ASRUserMode) -> ASRModelInfo? {
        models.first { $0.mode == mode }
    }

    public func model(id: String) -> ASRModelInfo? {
        models.first { $0.id == id }
    }

    public static let `default` = ModelCatalog(
        models: [
            ASRModelInfo(
                id: "whispercpp-tiny-en-q5",
                mode: .instant,
                displayName: "Instant",
                backend: .whisperCpp,
                engineIdentifier: "tiny.en-q5_1",
                localFilename: "ggml-tiny.en-q5_1.bin",
                downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en-q5_1.bin?download=true"),
                estimatedSizeMB: 31,
                estimatedMemoryMB: 220,
                speedLabel: "Fastest",
                qualityLabel: "Draft",
                license: "MIT"
            ),
            ASRModelInfo(
                id: "whispercpp-base-en-q5",
                mode: .balanced,
                displayName: "Balanced",
                backend: .whisperCpp,
                engineIdentifier: "base.en-q5_1",
                localFilename: "ggml-base.en-q5_1.bin",
                downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en-q5_1.bin?download=true"),
                estimatedSizeMB: 57,
                estimatedMemoryMB: 360,
                speedLabel: "Fast",
                qualityLabel: "Good English",
                license: "MIT"
            ),
            ASRModelInfo(
                id: "whispercpp-small-en-q5",
                mode: .accurate,
                displayName: "Accurate",
                backend: .whisperCpp,
                engineIdentifier: "small.en-q5_1",
                localFilename: "ggml-small.en-q5_1.bin",
                downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en-q5_1.bin?download=true"),
                estimatedSizeMB: 181,
                estimatedMemoryMB: 700,
                speedLabel: "Medium",
                qualityLabel: "Strong English",
                license: "MIT"
            ),
            ASRModelInfo(
                id: "fluidaudio-parakeet-v3",
                mode: .balanced,
                displayName: "Parakeet V3",
                backend: .fluidAudio,
                engineIdentifier: "parakeet-tdt-0.6b-v3",
                localFilename: "parakeet-tdt-0.6b-v3",
                downloadURL: URL(string: "https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml"),
                estimatedSizeMB: 461,
                estimatedMemoryMB: 900,
                speedLabel: "Very fast on Apple Silicon",
                qualityLabel: "Strong multilingual",
                license: "CC-BY-4.0"
            ),
            ASRModelInfo(
                id: "fluidaudio-parakeet-v2",
                mode: .instant,
                displayName: "Parakeet V2 English",
                backend: .fluidAudio,
                engineIdentifier: "parakeet-tdt-0.6b-v2",
                localFilename: "parakeet-tdt-0.6b-v2",
                downloadURL: URL(string: "https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v2-coreml"),
                estimatedSizeMB: 461,
                estimatedMemoryMB: 900,
                speedLabel: "Very fast on Apple Silicon",
                qualityLabel: "Best English recall",
                license: "CC-BY-4.0"
            ),
            ASRModelInfo(
                id: "whisperkit-large-v3-turbo",
                mode: .highestQuality,
                displayName: "Highest Quality",
                backend: .whisperKit,
                engineIdentifier: "large-v3-v20240930_turbo",
                localFilename: "openai_whisper-large-v3-v20240930_turbo",
                downloadURL: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml"),
                estimatedSizeMB: 1600,
                estimatedMemoryMB: 2800,
                speedLabel: "Fast on Apple Silicon",
                qualityLabel: "Best",
                license: "MIT"
            ),
            ASRModelInfo(
                id: "sherpa-onnx-experimental",
                mode: .experimental,
                displayName: "Experimental Streaming",
                backend: .sherpaOnnx,
                engineIdentifier: "zipformer-streaming",
                localFilename: "sherpa-onnx-streaming",
                downloadURL: nil,
                estimatedSizeMB: 150,
                estimatedMemoryMB: 500,
                speedLabel: "Unknown",
                qualityLabel: "Benchmark required",
                license: "Apache-2.0"
            )
        ],
        llmModels: [
            LLMModelInfo(
                id: "qwen3-0.6b-q4",
                displayName: "Qwen3 0.6B Cleanup",
                engineIdentifier: "Qwen/Qwen3-0.6B-GGUF:Q4_K_M",
                localFilename: "qwen3-0.6b-q4.gguf",
                estimatedSizeMB: 450,
                estimatedMemoryMB: 900,
                license: "Apache-2.0"
            ),
            LLMModelInfo(
                id: "gemma-3-1b-it-q4",
                displayName: "Gemma 3 1B IT",
                engineIdentifier: "ggml-org/gemma-3-1b-it-GGUF",
                localFilename: "gemma-3-1b-it-q4.gguf",
                estimatedSizeMB: 700,
                estimatedMemoryMB: 1200,
                license: "Gemma Terms"
            ),
            LLMModelInfo(
                id: "phi-4-mini-instruct-q4",
                displayName: "Phi-4 Mini Instruct",
                engineIdentifier: "microsoft/Phi-4-mini-instruct",
                localFilename: "phi-4-mini-instruct-q4.gguf",
                estimatedSizeMB: 2400,
                estimatedMemoryMB: 4200,
                license: "MIT"
            )
        ]
    )
}
