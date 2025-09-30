import Foundation

struct Account: Identifiable, Equatable {
    enum ServerType: String {
        case imap
        case pop3
    }

    let id: UUID
    var email: String
    var serverType: ServerType
    var imapHost: String?
    var imapPort: Int
    var smtpHost: String
    var smtpPort: Int
    var createdAt: Date

    init(id: UUID = UUID(),
         email: String,
         serverType: ServerType,
         imapHost: String?,
         imapPort: Int = 993,
         smtpHost: String,
         smtpPort: Int = 587,
         createdAt: Date = Date()) {
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
