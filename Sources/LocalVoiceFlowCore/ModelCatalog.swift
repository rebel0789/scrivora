import Foundation

public struct ModelCatalog: Sendable {
    public var models: [ASRModelInfo]
    public var llmModels: [LLMModelInfo]

    public init(models: [ASRModelInfo], llmModels: [LLMModelInfo]) {
        self.models = models
        self.llmModels = llmModels
    }

    public func recommendedModel(for mode: ASRUserMode) -> ASRModelInfo? {
        let preferredID: String = switch mode {
        case .instant: "fluidaudio-parakeet-v2"
        case .balanced: "fluidaudio-parakeet-v3"
        case .accurate: "whispercpp-large-v3-turbo-q5"
        case .highestQuality: "whispercpp-large-v3-q5"
        case .experimental: "sherpa-onnx-experimental"
        }
        return model(id: preferredID) ?? models.first { $0.mode == mode }
    }

    public func model(id: String) -> ASRModelInfo? {
        models.first { $0.id == id }
    }

    public func bestAvailableASRModel(
        preferredMode: ASRUserMode = .balanced,
        availableIDs: Set<String>
    ) -> ASRModelInfo? {
        let preferredIDs = [
            recommendedModel(for: .balanced)?.id,
            recommendedModel(for: preferredMode)?.id,
            recommendedModel(for: .accurate)?.id,
            recommendedModel(for: .highestQuality)?.id,
            recommendedModel(for: .instant)?.id
        ].compactMap { $0 }

        for id in preferredIDs where availableIDs.contains(id) {
            return model(id: id)
        }

        return models
            .filter { availableIDs.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.mode.fallbackRank != rhs.mode.fallbackRank {
                    return lhs.mode.fallbackRank < rhs.mode.fallbackRank
                }
                return lhs.estimatedMemoryMB < rhs.estimatedMemoryMB
            }
            .first
    }

    public static let `default` = ModelCatalog(
        models: [
            ASRModelInfo(
                id: "fluidaudio-parakeet-v3",
                mode: .balanced,
                displayName: "Parakeet V3",
                backend: .fluidAudio,
                engineIdentifier: "parakeet-tdt-0.6b-v3",
                localFilename: "parakeet-tdt-0.6b-v3",
                downloadURL: nil,
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
                downloadURL: nil,
                estimatedSizeMB: 461,
                estimatedMemoryMB: 900,
                speedLabel: "Very fast on Apple Silicon",
                qualityLabel: "Best English recall",
                license: "CC-BY-4.0"
            ),
            ASRModelInfo(
                id: "whispercpp-large-v3-turbo-q5",
                mode: .accurate,
                displayName: "Whisper Large v3 Turbo",
                backend: .whisperCpp,
                engineIdentifier: "large-v3-turbo-q5_0",
                localFilename: "ggml-large-v3-turbo-q5_0.bin",
                downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin?download=true"),
                downloadSHA256: "394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2",
                estimatedSizeMB: 548,
                estimatedMemoryMB: 1500,
                speedLabel: "Fast on Apple Silicon",
                qualityLabel: "High multilingual",
                license: "MIT"
            ),
            ASRModelInfo(
                id: "whispercpp-small-q5",
                mode: .balanced,
                displayName: "Whisper Small Multilingual",
                backend: .whisperCpp,
                engineIdentifier: "small-q5_1",
                localFilename: "ggml-small-q5_1.bin",
                downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q5_1.bin?download=true"),
                downloadSHA256: "ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb",
                estimatedSizeMB: 181,
                estimatedMemoryMB: 760,
                speedLabel: "Fast",
                qualityLabel: "Good multilingual",
                license: "MIT"
            ),
            ASRModelInfo(
                id: "whispercpp-medium-q5",
                mode: .highestQuality,
                displayName: "Whisper Medium",
                backend: .whisperCpp,
                engineIdentifier: "medium-q5_0",
                localFilename: "ggml-medium-q5_0.bin",
                downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium-q5_0.bin?download=true"),
                downloadSHA256: "19fea4b380c3a618ec4723c3eef2eb785ffba0d0538cf43f8f235e7b3b34220f",
                estimatedSizeMB: 514,
                estimatedMemoryMB: 1450,
                speedLabel: "Medium",
                qualityLabel: "Very high multilingual",
                license: "MIT"
            ),
            ASRModelInfo(
                id: "whispercpp-large-v3-q5",
                mode: .highestQuality,
                displayName: "Whisper Large v3",
                backend: .whisperCpp,
                engineIdentifier: "large-v3-q5_0",
                localFilename: "ggml-large-v3-q5_0.bin",
                downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-q5_0.bin?download=true"),
                downloadSHA256: "d75795ecff3f83b5faa89d1900604ad8c780abd5739fae406de19f23ecd98ad1",
                estimatedSizeMB: 1031,
                estimatedMemoryMB: 2800,
                speedLabel: "Slowest",
                qualityLabel: "Best multilingual",
                license: "MIT"
            ),
            ASRModelInfo(
                id: "whispercpp-tiny-en-q5",
                mode: .instant,
                displayName: "Whisper Tiny English",
                backend: .whisperCpp,
                engineIdentifier: "tiny.en-q5_1",
                localFilename: "ggml-tiny.en-q5_1.bin",
                downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en-q5_1.bin?download=true"),
                downloadSHA256: "c77c5766f1cef09b6b7d47f21b546cbddd4157886b3b5d6d4f709e91e66c7c2b",
                estimatedSizeMB: 31,
                estimatedMemoryMB: 220,
                speedLabel: "Fastest",
                qualityLabel: "Draft",
                license: "MIT"
            ),
            ASRModelInfo(
                id: "whispercpp-base-en-q5",
                mode: .balanced,
                displayName: "Whisper Base English",
                backend: .whisperCpp,
                engineIdentifier: "base.en-q5_1",
                localFilename: "ggml-base.en-q5_1.bin",
                downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en-q5_1.bin?download=true"),
                downloadSHA256: "4baf70dd0d7c4247ba2b81fafd9c01005ac77c2f9ef064e00dcf195d0e2fdd2f",
                estimatedSizeMB: 57,
                estimatedMemoryMB: 360,
                speedLabel: "Fast",
                qualityLabel: "Good English",
                license: "MIT"
            ),
            ASRModelInfo(
                id: "whispercpp-small-en-q5",
                mode: .accurate,
                displayName: "Whisper Small English",
                backend: .whisperCpp,
                engineIdentifier: "small.en-q5_1",
                localFilename: "ggml-small.en-q5_1.bin",
                downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en-q5_1.bin?download=true"),
                downloadSHA256: "bfdff4894dcb76bbf647d56263ea2a96645423f1669176f4844a1bf8e478ad30",
                estimatedSizeMB: 181,
                estimatedMemoryMB: 700,
                speedLabel: "Medium",
                qualityLabel: "Strong English",
                license: "MIT"
            ),
            ASRModelInfo(
                id: "whisperkit-large-v3-turbo",
                mode: .highestQuality,
                displayName: "WhisperKit Large Turbo",
                backend: .whisperKit,
                engineIdentifier: "large-v3-v20240930_turbo",
                localFilename: "openai_whisper-large-v3-v20240930_turbo",
                downloadURL: nil,
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

private extension ASRUserMode {
    var fallbackRank: Int {
        switch self {
        case .balanced: 0
        case .accurate: 1
        case .highestQuality: 2
        case .instant: 3
        case .experimental: 4
        }
    }
}
