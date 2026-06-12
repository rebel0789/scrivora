import Foundation

public enum LocalVoiceFlowError: Error, LocalizedError, Sendable {
    case modelNotLoaded
    case modelUnavailable(String)
    case transcriptionFailed(String)
    case insertionFailed(String)
    case permissionDenied(String)
    case invalidAudio(String)
    case processFailed(command: String, status: Int32, output: String)
    case fileSystem(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            "No ASR model is loaded."
        case .modelUnavailable(let message):
            "Model unavailable: \(message)"
        case .transcriptionFailed(let message):
            "Transcription failed: \(message)"
        case .insertionFailed(let message):
            "Text insertion failed: \(message)"
        case .permissionDenied(let message):
            "Permission denied: \(message)"
        case .invalidAudio(let message):
            "Invalid audio: \(message)"
        case .processFailed(let command, let status, let output):
            "Command failed (\(status)): \(command)\n\(output)"
        case .fileSystem(let message):
            "File system error: \(message)"
        }
    }
}

