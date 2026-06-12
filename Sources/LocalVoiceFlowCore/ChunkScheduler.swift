import Foundation

public struct ChunkScheduler: Sendable {
    public let sampleRate: Int
    public let chunkLengthSamples: Int
    public let overlapSamples: Int

    private var samples: [Float] = []
    private var absoluteStartSample: Int = 0
    private var nextStartIndex: Int = 0
    private var sequenceNumber: Int = 0

    public init(sampleRate: Int = 16_000, chunkLengthSeconds: Double = 6.0, overlapSeconds: Double = 0.75) {
        self.sampleRate = sampleRate
        self.chunkLengthSamples = max(1, Int(Double(sampleRate) * chunkLengthSeconds))
        self.overlapSamples = min(
            max(0, Int(Double(sampleRate) * overlapSeconds)),
            max(0, Int(Double(sampleRate) * chunkLengthSeconds) - 1)
        )
    }

    public mutating func append(_ newSamples: [Float]) -> [AudioChunk] {
        guard !newSamples.isEmpty else { return [] }
        samples.append(contentsOf: newSamples)

        var chunks: [AudioChunk] = []
        while samples.count - nextStartIndex >= chunkLengthSamples {
            let start = nextStartIndex
            let end = start + chunkLengthSamples
            let chunkSamples = Array(samples[start..<end])
            let chunk = AudioChunk(
                id: sequenceNumber,
                samples: chunkSamples,
                sampleRate: sampleRate,
                startSample: absoluteStartSample + start,
                sequenceNumber: sequenceNumber
            )
            chunks.append(chunk)
            sequenceNumber += 1
            nextStartIndex = end - overlapSamples
        }

        compactIfNeeded()
        return chunks
    }

    public mutating func reset() {
        samples.removeAll(keepingCapacity: true)
        absoluteStartSample = 0
        nextStartIndex = 0
        sequenceNumber = 0
    }

    private mutating func compactIfNeeded() {
        let safeDropCount = max(0, nextStartIndex - overlapSamples - chunkLengthSamples)
        guard safeDropCount > 0 else { return }
        samples.removeFirst(safeDropCount)
        absoluteStartSample += safeDropCount
        nextStartIndex -= safeDropCount
    }
}

