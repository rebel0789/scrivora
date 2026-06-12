import Foundation

public actor MockASREngine: ASREngine {
    private var loadedModel: ASRModelInfo?
    private let finalText: String

    public init(finalText: String = "LocalVoiceFlow is ready.") {
        self.finalText = finalText
    }

    public var isLoaded: Bool { loadedModel != nil }
    public var modelInfo: ASRModelInfo? { loadedModel }

    public func loadModel(_ model: ASRModelInfo) async throws {
        loadedModel = model
    }

    public func warmup() async throws {}

    public func transcribe(chunk: AudioChunk) async throws -> ASRPartialResult {
        ASRPartialResult(text: finalText, chunkID: chunk.id, isStable: true)
    }

    public func transcribeFinal(buffer: AudioBuffer) async throws -> ASRResult {
        guard let loadedModel else { throw LocalVoiceFlowError.modelNotLoaded }
        return ASRResult(text: finalText, latency: 0, modelID: loadedModel.id)
    }

    public func unload() async {
        loadedModel = nil
    }
}

public actor WhisperCppCLIEngine: ASREngine {
    private let executablePath: String
    private let modelStorage: ModelStorage
    private let modelPathOverride: String?
    private var loadedModel: ASRModelInfo?

    public init(executablePath: String, modelStorage: ModelStorage = ModelStorage(), modelPathOverride: String? = nil) {
        self.executablePath = executablePath
        self.modelStorage = modelStorage
        self.modelPathOverride = modelPathOverride
    }

    public var isLoaded: Bool { loadedModel != nil }
    public var modelInfo: ASRModelInfo? { loadedModel }

    public func loadModel(_ model: ASRModelInfo) async throws {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw LocalVoiceFlowError.modelUnavailable("Whisper executable was not found at \(executablePath).")
        }
        let modelURL = modelStorage.localURL(for: model, overridePath: modelPathOverride)
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw LocalVoiceFlowError.modelUnavailable("Model file is missing at \(modelURL.path).")
        }
        loadedModel = model
    }

    public func warmup() async throws {
        guard loadedModel != nil else { throw LocalVoiceFlowError.modelNotLoaded }
        // CLI warmup is intentionally a no-op. Production builds should use WhisperKit
        // or the whisper.cpp C API so the model stays resident between utterances.
    }

    public func transcribe(chunk: AudioChunk) async throws -> ASRPartialResult {
        ASRPartialResult(text: "", chunkID: chunk.id, isStable: false)
    }

    public func transcribeFinal(buffer: AudioBuffer) async throws -> ASRResult {
        guard let model = loadedModel else { throw LocalVoiceFlowError.modelNotLoaded }
        guard !buffer.samples.isEmpty else { throw LocalVoiceFlowError.invalidAudio("No captured samples.") }

        let stopwatch = Stopwatch()
        let wavURL = try WAVFileWriter.writeTemporaryWAV(samples: buffer.samples, sampleRate: buffer.sampleRate)
        defer { try? FileManager.default.removeItem(at: wavURL) }

        let outputBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalVoiceFlow-\(UUID().uuidString)")
        let modelURL = modelStorage.localURL(for: model, overridePath: modelPathOverride)
        let arguments = argumentsForWhisper(
            executablePath: executablePath,
            modelURL: modelURL,
            wavURL: wavURL,
            outputBase: outputBase
        )

        let processOutput = try await ProcessRunner.run(executable: executablePath, arguments: arguments)
        let textURL = outputBase.appendingPathExtension("txt")
        let text: String
        if let fileText = try? String(contentsOf: textURL, encoding: .utf8), !fileText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text = fileText
        } else {
            text = processOutput.combined
        }
        try? FileManager.default.removeItem(at: textURL)

        return ASRResult(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            latency: stopwatch.elapsedSeconds(),
            modelID: model.id
        )
    }

    public func unload() async {
        loadedModel = nil
    }

    private func argumentsForWhisper(executablePath: String, modelURL: URL, wavURL: URL, outputBase: URL) -> [String] {
        let executableName = URL(fileURLWithPath: executablePath).lastPathComponent
        if executableName == "whisper-cpp" {
            return ["-m", modelURL.path, wavURL.path, "--output-txt", "--output-file", outputBase.path, "--no-timestamps"]
        }
        return ["-m", modelURL.path, "-f", wavURL.path, "-otxt", "-of", outputBase.path, "-nt"]
    }
}

public actor WhisperCppServerEngine: ASREngine {
    private let serverExecutablePath: String
    private let modelStorage: ModelStorage
    private let modelPathOverride: String?
    private let host: String
    private let port: Int
    private var loadedModel: ASRModelInfo?
    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    public init(
        serverExecutablePath: String,
        modelStorage: ModelStorage = ModelStorage(),
        modelPathOverride: String? = nil,
        host: String = "127.0.0.1",
        port: Int = Int.random(in: 28_000...48_000)
    ) {
        self.serverExecutablePath = serverExecutablePath
        self.modelStorage = modelStorage
        self.modelPathOverride = modelPathOverride
        self.host = host
        self.port = port
    }

    public var isLoaded: Bool {
        loadedModel != nil && (process?.isRunning ?? false)
    }

    public var modelInfo: ASRModelInfo? { loadedModel }

    public func loadModel(_ model: ASRModelInfo) async throws {
        if loadedModel?.id == model.id, process?.isRunning == true {
            return
        }

        guard FileManager.default.isExecutableFile(atPath: serverExecutablePath) else {
            throw LocalVoiceFlowError.modelUnavailable("Whisper server executable was not found at \(serverExecutablePath).")
        }

        let modelURL = modelStorage.localURL(for: model, overridePath: modelPathOverride)
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw LocalVoiceFlowError.modelUnavailable("Model file is missing at \(modelURL.path).")
        }

        await unload()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: serverExecutablePath)
        process.arguments = [
            "-m", modelURL.path,
            "--host", host,
            "--port", String(port),
            "-nt"
        ]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        self.process = process
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        loadedModel = model

        try await waitUntilReady(timeoutSeconds: 30)
    }

    public func warmup() async throws {
        guard loadedModel != nil, process?.isRunning == true else {
            throw LocalVoiceFlowError.modelNotLoaded
        }
    }

    public func transcribe(chunk: AudioChunk) async throws -> ASRPartialResult {
        ASRPartialResult(text: "", chunkID: chunk.id, isStable: false)
    }

    public func transcribeFinal(buffer: AudioBuffer) async throws -> ASRResult {
        guard let model = loadedModel, process?.isRunning == true else {
            throw LocalVoiceFlowError.modelNotLoaded
        }
        guard !buffer.samples.isEmpty else {
            throw LocalVoiceFlowError.invalidAudio("No captured samples.")
        }

        let stopwatch = Stopwatch()
        let wavURL = try WAVFileWriter.writeTemporaryWAV(samples: buffer.samples, sampleRate: buffer.sampleRate)
        defer { try? FileManager.default.removeItem(at: wavURL) }

        var request = URLRequest(url: URL(string: "http://\(host):\(port)/inference")!)
        let boundary = "LocalVoiceFlow-\(UUID().uuidString)"
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try multipartBody(fileURL: wavURL, boundary: boundary)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LocalVoiceFlowError.transcriptionFailed("whisper-server returned \(String(describing: (response as? HTTPURLResponse)?.statusCode)): \(body)")
        }

        return ASRResult(
            text: try Self.parseTextResponse(data),
            latency: stopwatch.elapsedSeconds(),
            modelID: model.id
        )
    }

    public func unload() async {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        if process?.isRunning == true {
            process?.terminate()
            process?.waitUntilExit()
        }
        process = nil
        stdoutPipe = nil
        stderrPipe = nil
        loadedModel = nil
    }

    public static func parseTextResponse(_ data: Data) throws -> String {
        struct Response: Decodable {
            var text: String?
        }

        if let decoded = try? JSONDecoder().decode(Response.self, from: data), let text = decoded.text {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let raw = String(data: data, encoding: .utf8) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LocalVoiceFlowError.transcriptionFailed("Empty whisper-server response.")
        }
        return trimmed
    }

    private func waitUntilReady(timeoutSeconds: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        let healthURL = URL(string: "http://\(host):\(port)/")!

        while Date() < deadline {
            if process?.isRunning != true {
                throw LocalVoiceFlowError.transcriptionFailed("whisper-server exited before becoming ready.")
            }

            do {
                let (_, response) = try await URLSession.shared.data(from: healthURL)
                if let httpResponse = response as? HTTPURLResponse, (200..<500).contains(httpResponse.statusCode) {
                    return
                }
            } catch {
                try await Task.sleep(for: .milliseconds(150))
            }
        }

        throw LocalVoiceFlowError.transcriptionFailed("Timed out waiting for whisper-server on \(host):\(port).")
    }

    private func multipartBody(fileURL: URL, boundary: String) throws -> Data {
        var data = Data()
        data.appendUTF8("--\(boundary)\r\n")
        data.appendUTF8("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")
        data.appendUTF8("Content-Type: audio/wav\r\n\r\n")
        data.append(try Data(contentsOf: fileURL))
        data.appendUTF8("\r\n--\(boundary)--\r\n")
        return data
    }
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        append(contentsOf: string.utf8)
    }
}
