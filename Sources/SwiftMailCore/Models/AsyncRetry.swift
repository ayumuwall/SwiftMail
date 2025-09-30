import Foundation

public enum RetryExecutor {
    public static func retry<T>(operation: () async throws -> T) async throws -> T {
        var delay = RetryPolicy.initialDelay
        for attempt in 0..<RetryPolicy.maxRetries {
            do {
                return try await operation()
            } catch {
                if attempt == RetryPolicy.maxRetries - 1 {
                    throw MailError.serverNotResponding
                }
                let nanoseconds = UInt64(delay * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
                delay *= RetryPolicy.backoffMultiplier
            }
        }
        throw MailError.serverNotResponding
    }
}
