import Foundation

public protocol MailRepository: Sendable {
    func fetchAccounts() throws -> [Account]
    func fetchAccount(by id: String) throws -> Account?
    func upsertAccount(_ account: Account) throws
    func removeAccount(by id: String) throws

    func fetchMessages(accountID: String, folderID: String?, limit: Int, offset: Int) throws -> [Message]
    func fetchMessage(by id: String) throws -> Message?
    func saveMessages(_ messages: [Message]) throws
    func markMessage(_ id: String, isRead: Bool) throws
    func markMessage(_ id: String, isDeleted: Bool) throws
    func deleteMessage(_ id: String) throws

    func fetchAttachments(messageID: String) throws -> [Attachment]
    func saveAttachments(_ attachments: [Attachment]) throws
    func updateAttachmentDownloadState(_ id: String, isDownloaded: Bool, downloadedAt: Date?) throws

    func fetchIMAPFolders(accountID: String) throws -> [IMAPFolder]
    func upsertIMAPFolders(_ folders: [IMAPFolder]) throws
    func deleteIMAPFolders(accountID: String) throws
}
