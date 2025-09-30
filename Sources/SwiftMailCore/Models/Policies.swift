import Foundation

public enum SyncStrategy: Sendable {
    case full
    case incremental
    case headers
}

public struct CachePolicy {
    public static let recentMailsDays = 30
    public static let headerOnlyAfterDays = 30
    public static let maxAttachmentCacheMB: Double = 500.0
    public static let maxTotalCacheGB: Double = 1.0

    private init() {}
}

public struct AttachmentPolicy {
    public enum Mode: Sendable {
        case onDemand
        case automatic
    }

    public static let mode: Mode = .onDemand

    private init() {}
}

public struct RetryPolicy {
    public static let maxRetries = 3
    public static let backoffMultiplier = 2.0
    public static let initialDelay: TimeInterval = 1.0

    private init() {}
}
