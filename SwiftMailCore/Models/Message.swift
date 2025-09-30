import Foundation

struct Message: Identifiable, Equatable {
    let id: UUID
    let accountID: UUID
    var messageID: String?
    var folderID: UUID?
    var subject: String
    var sender: String
    var recipients: [String]
    var date: Date
    var size: Int
    var headersJSON: String?
    var bodyPlain: String
    var bodyHTML: String?
    var isRead: Bool
    var isFlagged: Bool
    var isDeleted: Bool
    var cachedAt: Date

    init(id: UUID = UUID(),
         accountID: UUID,
         messageID: String?,
         folderID: UUID?,
         subject: String,
         sender: String,
         recipients: [String],
         date: Date,
         size: Int,
         headersJSON: String?,
         bodyPlain: String,
         bodyHTML: String?,
         isRead: Bool = false,
         isFlagged: Bool = false,
         isDeleted: Bool = false,
         cachedAt: Date = Date()) {
        self.id = id
        self.accountID = accountID
        self.messageID = messageID
        self.folderID = folderID
        self.subject = subject
        self.sender = sender
        self.recipients = recipients
        self.date = date
        self.size = size
        self.headersJSON = headersJSON
        self.bodyPlain = bodyPlain
        self.bodyHTML = bodyHTML
        self.isRead = isRead
        self.isFlagged = isFlagged
        self.isDeleted = isDeleted
        self.cachedAt = cachedAt
    }

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
