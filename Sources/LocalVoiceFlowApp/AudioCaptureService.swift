import AVFoundation
import Foundation

final class AudioCaptureService: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let converter = AudioConverter16kMono()
    private var isRunning = false

    func start(onSamples: @escaping @Sendable ([Float]) -> Void) throws {
        guard !isRunning else { return }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 960, format: format) { [converter] buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            let sourceSamples = Array(UnsafeBufferPointer(start: channel, count: frameCount))
            let converted = converter.convert(sourceSamples, sourceSampleRate: format.sampleRate)
            if !converted.isEmpty {
                onSamples(converted)
            }
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }
}

final class AudioConverter16kMono: @unchecked Sendable {
    private let targetSampleRate = 16_000.0
    private var carry: Double = 0

    func convert(_ samples: [Float], sourceSampleRate: Double) -> [Float] {
        guard !samples.isEmpty, sourceSampleRate > 0 else { return [] }
        if abs(sourceSampleRate - targetSampleRate) < 1 {
            return samples
        }

        let step = sourceSampleRate / targetSampleRate
        var position = carry
        var output: [Float] = []
        output.reserveCapacity(Int(Double(samples.count) / step) + 1)

        while Int(position) < samples.count {
            output.append(samples[Int(position)])
            position += step
        }

        carry = position - Double(samples.count)
        return output
    }
}

