import Foundation

public struct Account: Identifiable, Hashable, Sendable {
    public enum ServerType: String, Codable, Sendable {
        case imap
        case pop3
    }

    public let id: String
    public var email: String
    public var serverType: ServerType
    public var imapHost: String?
    public var imapPort: Int
    public var smtpHost: String
    public var smtpPort: Int
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        email: String,
        serverType: ServerType,
        imapHost: String?,
        imapPort: Int = 993,
        smtpHost: String,
        smtpPort: Int = 587,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.serverType = serverType
        self.imapHost = imapHost
        self.imapPort = imapPort
        self.smtpHost = smtpHost
        self.smtpPort = smtpPort
        self.createdAt = createdAt
    }
}
