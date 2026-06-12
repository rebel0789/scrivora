import Foundation
import Testing
@testable import LocalVoiceFlowCore

struct WhisperCppIntegrationTests {
    @Test func whisperServerResponseParserReturnsTrimmedText() throws {
        let data = #"{"text":" Hello local voice flow.\n"}"#.data(using: .utf8)!

        let text = try WhisperCppServerEngine.parseTextResponse(data)

        #expect(text == "Hello local voice flow.")
    }

    @Test func whisperCppCLIEngineTranscribesConfiguredAudioFile() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard
            let executablePath = environment["LOCALVOICEFLOW_WHISPER_CLI"],
            let modelPath = environment["LOCALVOICEFLOW_WHISPER_MODEL"],
            let audioPath = environment["LOCALVOICEFLOW_TEST_WAV"]
        else {
            return
        }

        let modelURL = URL(fileURLWithPath: modelPath)
        let audio = try readPCM16MonoWAV(URL(fileURLWithPath: audioPath))
        let model = ASRModelInfo(
            id: "integration-whisper",
            mode: .instant,
            displayName: "Integration Whisper",
            backend: .whisperCpp,
            engineIdentifier: modelURL.deletingPathExtension().lastPathComponent,
            localFilename: modelURL.lastPathComponent,
            downloadURL: nil,
            estimatedSizeMB: 0,
            estimatedMemoryMB: 0,
            speedLabel: "Integration",
            qualityLabel: "Integration",
            license: "MIT"
        )
        let engine = WhisperCppCLIEngine(
            executablePath: executablePath,
            modelStorage: ModelStorage(directory: modelURL.deletingLastPathComponent())
        )

        try await engine.loadModel(model)
        let result = try await engine.transcribeFinal(buffer: audio)

        #expect(result.text.lowercased().contains("local voice flow"))
    }

    @Test func whisperCppServerEngineTranscribesConfiguredAudioFile() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard
            let executablePath = environment["LOCALVOICEFLOW_WHISPER_SERVER"],
            let modelPath = environment["LOCALVOICEFLOW_WHISPER_MODEL"],
            let audioPath = environment["LOCALVOICEFLOW_TEST_WAV"]
        else {
            return
        }

        let modelURL = URL(fileURLWithPath: modelPath)
        let audio = try readPCM16MonoWAV(URL(fileURLWithPath: audioPath))
        let model = ASRModelInfo(
            id: "integration-whisper-server",
            mode: .instant,
            displayName: "Integration Whisper Server",
            backend: .whisperCpp,
            engineIdentifier: modelURL.deletingPathExtension().lastPathComponent,
            localFilename: modelURL.lastPathComponent,
            downloadURL: nil,
            estimatedSizeMB: 0,
            estimatedMemoryMB: 0,
            speedLabel: "Integration",
            qualityLabel: "Integration",
            license: "MIT"
        )
        let engine = WhisperCppServerEngine(
            serverExecutablePath: executablePath,
            modelStorage: ModelStorage(directory: modelURL.deletingLastPathComponent()),
            port: 48_181
        )

        try await engine.loadModel(model)
        let result = try await engine.transcribeFinal(buffer: audio)
        await engine.unload()

        #expect(result.text.lowercased().contains("local voice flow"))
    }

    private func readPCM16MonoWAV(_ url: URL) throws -> AudioBuffer {
        let data = try Data(contentsOf: url)
        guard data.count > 44, String(data: data[0..<4], encoding: .ascii) == "RIFF" else {
            throw LocalVoiceFlowError.invalidAudio("Expected RIFF WAV.")
        }

        var offset = 12
        var sampleRate = 16_000
        var channelCount = 1
        var bitsPerSample = 16
        var pcmData: Data?

        while offset + 8 <= data.count {
            let chunkID = String(data: data[offset..<(offset + 4)], encoding: .ascii) ?? ""
            let chunkSize = Int(readUInt32LE(data, offset: offset + 4))
            let payloadStart = offset + 8
            let payloadEnd = min(payloadStart + chunkSize, data.count)

            if chunkID == "fmt ", payloadEnd - payloadStart >= 16 {
                channelCount = Int(readUInt16LE(data, offset: payloadStart + 2))
                sampleRate = Int(readUInt32LE(data, offset: payloadStart + 4))
                bitsPerSample = Int(readUInt16LE(data, offset: payloadStart + 14))
            } else if chunkID == "data" {
                pcmData = data[payloadStart..<payloadEnd]
                break
            }

            offset = payloadStart + chunkSize + (chunkSize % 2)
        }

        guard let pcmData, bitsPerSample == 16 else {
            throw LocalVoiceFlowError.invalidAudio("Expected 16-bit PCM data.")
        }

        var samples: [Float] = []
        samples.reserveCapacity(pcmData.count / max(2, channelCount * 2))

        var index = pcmData.startIndex
        while index + (channelCount * 2) <= pcmData.endIndex {
            let sample = Int16(bitPattern: readUInt16LE(pcmData, offset: index))
            samples.append(Float(sample) / Float(Int16.max))
            index += channelCount * 2
        }

        return AudioBuffer(samples: samples, sampleRate: sampleRate)
    }

    private func readUInt16LE(_ data: Data, offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private func readUInt32LE(_ data: Data, offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }
}
