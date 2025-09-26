import Foundation

public struct Message: Identifiable, Hashable, Sendable {
    public struct Address: Hashable, Codable, Sendable {
        public var name: String?
        public var email: String

        public init(name: String? = nil, email: String) {
            self.name = name
            self.email = email
        }
    }

    public let id: String
    public var accountID: String
    public var messageID: String?
    public var folderID: String?
    public var subject: String?
    public var sender: Address?
    public var recipients: [Address]
    public var date: Date?
    public var size: Int
    public var headers: [String: String]
    public var bodyPlain: String?
    public var bodyHTML: String?
    public var isRead: Bool
    public var isFlagged: Bool
    public var isDeleted: Bool
    public var cachedAt: Date

    public init(
        id: String = UUID().uuidString,
        accountID: String,
        messageID: String? = nil,
        folderID: String? = nil,
        subject: String? = nil,
        sender: Address? = nil,
        recipients: [Address] = [],
        date: Date? = nil,
        size: Int = 0,
        headers: [String: String] = [:],
        bodyPlain: String? = nil,
        bodyHTML: String? = nil,
        isRead: Bool = false,
        isFlagged: Bool = false,
        isDeleted: Bool = false,
        cachedAt: Date = Date()
    ) {
        self.id = id
        self.accountID = accountID
        self.messageID = messageID
        self.folderID = folderID
        self.subject = subject
        self.sender = sender
        self.recipients = recipients
        self.date = date
        self.size = size
        self.headers = headers
        self.bodyPlain = bodyPlain
        self.bodyHTML = bodyHTML
        self.isRead = isRead
        self.isFlagged = isFlagged
        self.isDeleted = isDeleted
        self.cachedAt = cachedAt
    }
}
