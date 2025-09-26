import Foundation

public struct Attachment: Identifiable, Hashable, Sendable {
    public let id: String
    public var messageID: String
    public var filename: String
    public var mimeType: String
    public var size: Int
    public var data: Data?
    public var isDownloaded: Bool
    public var downloadedAt: Date?

    public init(
        id: String = UUID().uuidString,
        messageID: String,
        filename: String,
        mimeType: String,
        size: Int,
        data: Data? = nil,
        isDownloaded: Bool = false,
        downloadedAt: Date? = nil
    ) {
        self.id = id
        self.messageID = messageID
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
        self.data = data
        self.isDownloaded = isDownloaded
        self.downloadedAt = downloadedAt
    }
}
