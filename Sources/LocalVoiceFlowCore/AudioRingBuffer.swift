import Foundation

public final class AudioRingBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let capacity: Int
    private var storage: [Float] = []

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    public func append(_ samples: [Float]) {
        guard !samples.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }

        storage.append(contentsOf: samples)
        if storage.count > capacity {
            storage.removeFirst(storage.count - capacity)
        }
    }

    public func snapshot() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    public func readLast(sampleCount: Int) -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        guard sampleCount < storage.count else { return storage }
        return Array(storage.suffix(sampleCount))
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll(keepingCapacity: true)
    }
}

