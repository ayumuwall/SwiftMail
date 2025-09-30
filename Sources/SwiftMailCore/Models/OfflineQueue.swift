import Foundation

public final class OfflineQueue: @unchecked Sendable {
    private var outboxQueue: [Message] = []
    private let queue = DispatchQueue(label: "com.swiftmail.offlinequeue", attributes: .concurrent)

    public init() {}

    public func queueForSending(_ message: Message) {
        queue.async(flags: .barrier) {
            self.outboxQueue.append(message)
        }
    }

    public func dequeue() -> Message? {
        queue.sync(flags: .barrier) {
            guard !outboxQueue.isEmpty else { return nil }
            return outboxQueue.removeFirst()
        }
    }

    public func allQueued() -> [Message] {
        queue.sync { outboxQueue }
    }
}
