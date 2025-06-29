struct RingBuffer<T> {
    private var buffer: [T?]
    private var index: Int = 0
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }

    mutating func write(_ value: T) {
        buffer[index] = value
        index = (index + 1) % capacity
    }

    func getBuffer() -> [T] {
        return buffer.compactMap { $0 }
    }
}
