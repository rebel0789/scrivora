import Foundation

struct VoiceSpectrumBands: Equatable {
    var low: Double
    var mid: Double
    var high: Double

    static let silent = VoiceSpectrumBands(low: 0, mid: 0, high: 0)

    var brightness: Double {
        min(1, max(0, (mid * 0.35) + (high * 0.65)))
    }

    func scaled(by level: Double) -> VoiceSpectrumBands {
        let clampedLevel = min(1, max(0, level))
        return VoiceSpectrumBands(
            low: min(1, low * clampedLevel),
            mid: min(1, mid * clampedLevel),
            high: min(1, high * clampedLevel)
        )
    }

    func smoothed(toward target: VoiceSpectrumBands, attack: Double, release: Double) -> VoiceSpectrumBands {
        VoiceSpectrumBands(
            low: smooth(current: low, target: target.low, attack: attack, release: release),
            mid: smooth(current: mid, target: target.mid, attack: attack, release: release),
            high: smooth(current: high, target: target.high, attack: attack, release: release)
        )
    }

    private func smooth(current: Double, target: Double, attack: Double, release: Double) -> Double {
        let factor = target > current ? attack : release
        return (current * (1 - factor)) + (target * factor)
    }
}

enum VoiceSpectrumAnalyzer {
    private static let fftSize = 512

    static func analyze(samples: [Float], sampleRate: Double = 16_000) -> VoiceSpectrumBands {
        guard !samples.isEmpty, sampleRate > 0 else { return .silent }

        var real = Array(repeating: 0.0, count: fftSize)
        var imaginary = Array(repeating: 0.0, count: fftSize)
        let sampleStart = max(0, samples.count - fftSize)
        let sampleCount = min(fftSize, samples.count - sampleStart)

        for index in 0..<sampleCount {
            let sample = Double(samples[sampleStart + index])
            let window = 0.5 - (0.5 * cos((2 * Double.pi * Double(index)) / Double(fftSize - 1)))
            real[index] = sample * window
        }

        fft(real: &real, imaginary: &imaginary)

        var lowEnergy = 0.0
        var midEnergy = 0.0
        var highEnergy = 0.0
        var totalEnergy = 0.0
        var lowBins = 0
        var midBins = 0
        var highBins = 0

        for bin in 1..<(fftSize / 2) {
            let frequency = Double(bin) * sampleRate / Double(fftSize)
            let power = (real[bin] * real[bin]) + (imaginary[bin] * imaginary[bin])
            totalEnergy += power

            switch frequency {
            case 85..<300:
                lowEnergy += power
                lowBins += 1
            case 300..<1_600:
                midEnergy += power
                midBins += 1
            case 1_600..<4_200:
                highEnergy += power
                highBins += 1
            default:
                break
            }
        }

        guard totalEnergy > 0.000001 else { return .silent }

        return VoiceSpectrumBands(
            low: bandScore(energy: lowEnergy, bins: lowBins, totalEnergy: totalEnergy, expectedShare: 0.22),
            mid: bandScore(energy: midEnergy, bins: midBins, totalEnergy: totalEnergy, expectedShare: 0.48),
            high: bandScore(energy: highEnergy, bins: highBins, totalEnergy: totalEnergy, expectedShare: 0.18)
        )
    }

    private static func bandScore(energy: Double, bins: Int, totalEnergy: Double, expectedShare: Double) -> Double {
        guard bins > 0, totalEnergy > 0, expectedShare > 0 else { return 0 }
        let share = energy / totalEnergy
        return min(1, max(0, share / expectedShare))
    }

    private static func fft(real: inout [Double], imaginary: inout [Double]) {
        let count = real.count
        guard count > 1, count == imaginary.count else { return }

        var swapIndex = 0
        for index in 1..<count {
            var bit = count >> 1
            while swapIndex & bit != 0 {
                swapIndex ^= bit
                bit >>= 1
            }
            swapIndex ^= bit

            if index < swapIndex {
                real.swapAt(index, swapIndex)
                imaginary.swapAt(index, swapIndex)
            }
        }

        var length = 2
        while length <= count {
            let angle = -2 * Double.pi / Double(length)
            let stepReal = cos(angle)
            let stepImaginary = sin(angle)
            let halfLength = length / 2

            for start in stride(from: 0, to: count, by: length) {
                var unitReal = 1.0
                var unitImaginary = 0.0

                for offset in 0..<halfLength {
                    let evenIndex = start + offset
                    let oddIndex = evenIndex + halfLength
                    let oddReal = (real[oddIndex] * unitReal) - (imaginary[oddIndex] * unitImaginary)
                    let oddImaginary = (real[oddIndex] * unitImaginary) + (imaginary[oddIndex] * unitReal)

                    real[oddIndex] = real[evenIndex] - oddReal
                    imaginary[oddIndex] = imaginary[evenIndex] - oddImaginary
                    real[evenIndex] += oddReal
                    imaginary[evenIndex] += oddImaginary

                    let nextUnitReal = (unitReal * stepReal) - (unitImaginary * stepImaginary)
                    unitImaginary = (unitReal * stepImaginary) + (unitImaginary * stepReal)
                    unitReal = nextUnitReal
                }
            }

            length <<= 1
        }
    }
}
