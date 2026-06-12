import Foundation

public struct VoiceActivityDetector: Equatable, Sendable {
    public var energyThreshold: Float

    public init(energyThreshold: Float = 0.012) {
        self.energyThreshold = energyThreshold
    }

    public func energy(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(Float(0)) { partial, sample in
            partial + sample * sample
        }
        return sqrt(sum / Float(samples.count))
    }

    public func isSpeech(_ samples: [Float]) -> Bool {
        energy(samples) >= energyThreshold
    }
}

public struct SilenceDetector: Equatable, Sendable {
    public var requiredSilentFrames: Int
    private var silentFrameCount: Int
    private var hasSeenSpeech: Bool

    public init(requiredSilentFrames: Int) {
        self.requiredSilentFrames = max(1, requiredSilentFrames)
        self.silentFrameCount = 0
        self.hasSeenSpeech = false
    }

    public mutating func observe(isSpeech: Bool) -> Bool {
        if isSpeech {
            hasSeenSpeech = true
            silentFrameCount = 0
            return false
        }

        guard hasSeenSpeech else { return false }
        silentFrameCount += 1
        return silentFrameCount >= requiredSilentFrames
    }

    public mutating func reset() {
        silentFrameCount = 0
        hasSeenSpeech = false
    }
}

