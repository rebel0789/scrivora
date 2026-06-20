import Foundation

public enum WAVFileWriter {
    public static func writeTemporaryWAV(samples: [Float], sampleRate: Int = 16_000) throws -> URL {
        try TempAudioFileManager().createTemporaryWAV(samples: samples, sampleRate: sampleRate)
    }

    public static func writeWAV(samples: [Float], sampleRate: Int = 16_000, to url: URL) throws {
        let clamped = samples.map { Int16(max(-1, min(1, $0)) * Float(Int16.max)) }
        var data = Data()

        let byteRate = sampleRate * 2
        let blockAlign: UInt16 = 2
        let bitsPerSample: UInt16 = 16
        let dataSize = UInt32(clamped.count * 2)
        let chunkSize = UInt32(36) + dataSize

        data.appendASCII("RIFF")
        data.appendLittleEndian(chunkSize)
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(byteRate))
        data.appendLittleEndian(blockAlign)
        data.appendLittleEndian(bitsPerSample)
        data.appendASCII("data")
        data.appendLittleEndian(dataSize)
        clamped.forEach { data.appendLittleEndian($0) }

        try data.write(to: url, options: [.atomic])
    }
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
