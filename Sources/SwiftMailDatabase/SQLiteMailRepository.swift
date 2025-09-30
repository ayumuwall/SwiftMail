import Foundation
import SQLite3
import SwiftMailCore

public final class SQLiteMailRepository: MailRepository {
    private let database: MailDatabase
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(database: MailDatabase) {
        self.database = database
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .secondsSince1970
        self.encoder.outputFormatting = [.sortedKeys]

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .secondsSince1970
    }

    // MARK: - Accounts

    public func fetchAccount(by id: String) throws -> Account? {
        let sql = """
            SELECT id, email, server_type, imap_host, imap_port, smtp_host, smtp_port, created_at
            FROM accounts
            WHERE id = ?
        """
        let statement = try database.prepareStatement(sql)
        defer { statement.reset() }
        try statement.bind([.text(id)])
        guard try statement.step() == SQLITE_ROW else { return nil }
        return try account(from: statement)
    }

    public func fetchAccounts() throws -> [Account] {
        let sql = """
            SELECT id, email, server_type, imap_host, imap_port, smtp_host, smtp_port, created_at
            FROM accounts
            ORDER BY created_at ASC
        """
        let statement = try database.prepareStatement(sql)
        defer { statement.reset() }

        var accounts: [Account] = []
        while try statement.step() == SQLITE_ROW {
            accounts.append(try account(from: statement))
        }
        return accounts
    }

    public func upsertAccount(_ account: Account) throws {
        let sql = """
            INSERT INTO accounts (id, email, server_type, imap_host, imap_port, smtp_host, smtp_port, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                email = excluded.email,
                server_type = excluded.server_type,
                imap_host = excluded.imap_host,
                imap_port = excluded.imap_port,
                smtp_host = excluded.smtp_host,
                smtp_port = excluded.smtp_port,
                created_at = excluded.created_at
        """
        let statement = try database.prepareStatement(sql)
        defer { statement.reset() }
        try statement.bind([
            .text(account.id),
            .text(account.email),
            .text(account.serverType.rawValue),
            SQLiteValue.from(optionalString: account.imapHost),
            .int(Int64(account.imapPort)),
            .text(account.smtpHost),
            .int(Int64(account.smtpPort)),
            .int(Int64(account.createdAt.timeIntervalSince1970))
        ])
        try statement.step()
    }

    public func removeAccount(by id: String) throws {
        let sql = "DELETE FROM accounts WHERE id = ?"
        let statement = try database.prepareStatement(sql)
        defer { statement.reset() }
        try statement.bind([.text(id)])
        try statement.step()
    }

    // MARK: - Messages

    public func fetchMessages(accountID: String, folderID: String?, limit: Int, offset: Int) throws -> [Message] {
        var sql = """
            SELECT id, account_id, message_id, folder_id, subject, sender, recipients, date, size, headers, body_plain, body_html, is_read, is_flagged, is_deleted, cached_at
            FROM messages
            WHERE account_id = ?
        """
        var bindings: [SQLiteValue] = [.text(accountID)]
        if let folderID {
            sql += " AND folder_id = ?"
            bindings.append(.text(folderID))
        } else {
            sql += " AND folder_id IS NULL"
        }
        sql += " AND is_deleted = 0 ORDER BY date DESC LIMIT ? OFFSET ?"
        bindings.append(.int(Int64(limit)))
        bindings.append(.int(Int64(offset)))

        let statement = try database.prepareStatement(sql)
        defer { statement.reset() }
        try statement.bind(bindings)

        var messages: [Message] = []
        while try statement.step() == SQLITE_ROW {
            if let message = try message(from: statement) {
                messages.append(message)
            }
        }
        return messages
    }

    public func fetchMessage(by id: String) throws -> Message? {
        let sql = """
            SELECT id, account_id, message_id, folder_id, subject, sender, recipients, date, size, headers, body_plain, body_html, is_read, is_flagged, is_deleted, cached_at
            FROM messages
            WHERE id = ?
        """
        let statement = try database.prepareStatement(sql)
        defer { statement.reset() }
        try statement.bind([.text(id)])
        guard try statement.step() == SQLITE_ROW else { return nil }
        return try message(from: statement)
    }

    public func saveMessages(_ messages: [Message]) throws {
        guard !messages.isEmpty else { return }
        try database.performBatch {
            for message in messages {
                try upsert(message)
            }
        }
    }

    public func markMessage(_ id: String, isRead: Bool) throws {
        try updateMessageFlag(id: id, column: "is_read", value: isRead)
    }

    public func markMessage(_ id: String, isDeleted: Bool) throws {
        try updateMessageFlag(id: id, column: "is_deleted", value: isDeleted)
    }

    public func deleteMessage(_ id: String) throws {
        let sql = "DELETE FROM messages WHERE id = ?"
        let statement = try database.prepareStatement(sql)
        defer { statement.reset() }
        try statement.bind([.text(id)])
        try statement.step()
    }

    // MARK: - Attachments

    public func fetchAttachments(messageID: String) throws -> [Attachment] {
        let sql = """
            SELECT id, message_id, filename, mime_type, size, content, downloaded_at
            FROM attachments
            WHERE message_id = ?
        """
        let statement = try database.prepareStatement(sql)
        defer { statement.reset() }
        try statement.bind([.text(messageID)])

        var attachments: [Attachment] = []
        while try statement.step() == SQLITE_ROW {
            attachments.append(attachment(from: statement))
        }
        return attachments
    }

    public func saveAttachments(_ attachments: [Attachment]) throws {
        guard !attachments.isEmpty else { return }
        try database.performBatch {
            for attachment in attachments {
                try upsert(attachment)
            }
        }
    }

    public func updateAttachmentDownloadState(_ id: String, isDownloaded: Bool, downloadedAt: Date?) throws {
        let sql = """
            UPDATE attachments
            SET downloaded_at = ?, content = CASE WHEN ? = 1 THEN content ELSE NULL END
            WHERE id = ?
        """
        let statement = try database.prepareStatement(sql)
        defer { statement.reset() }
        try statement.bind([
            SQLiteValue.from(optionalDate: downloadedAt),
            .int(isDownloaded ? 1 : 0),
            .text(id)
        ])
        try statement.step()
    }

    // MARK: - IMAP Folders

    public func fetchIMAPFolders(accountID: String) throws -> [IMAPFolder] {
        let sql = """
            SELECT id, account_id, name, full_path, parent_id, uidvalidity, uidnext
            FROM imap_folders
            WHERE account_id = ?
            ORDER BY full_path
        """
        let statement = try database.prepareStatement(sql)
        defer { statement.reset() }
        try statement.bind([.text(accountID)])

        var folders: [IMAPFolder] = []
        while try statement.step() == SQLITE_ROW {
            folders.append(folder(from: statement))
        }
        return folders
    }

    public func upsertIMAPFolders(_ folders: [IMAPFolder]) throws {
        guard !folders.isEmpty else { return }
        try database.performBatch {
            for folder in folders {
                try upsert(folder)
            }
        }
    }

    public func deleteIMAPFolders(accountID: String) throws {
        let sql = "DELETE FROM imap_folders WHERE account_id = ?"
        let statement = try database.prepareStatement(sql)
        defer { statement.reset() }
        try statement.bind([.text(accountID)])
        try statement.step()
    }

    // MARK: - Helpers

    private func account(from statement: SQLiteStatement) throws -> Account {
        guard let id = statement.text(at: 0) else { throw MailError.databaseError("アカウントIDを取得できません") }
        guard let email = statement.text(at: 1) else { throw MailError.databaseError("メールアドレスを取得できません") }
        let serverRaw = statement.text(at: 2) ?? "imap"
        let serverType = Account.ServerType(rawValue: serverRaw) ?? .imap
        let imapHost = statement.text(at: 3)
        let imapPort = Int(statement.int(at: 4))
        let smtpHost = statement.text(at: 5) ?? ""
        let smtpPort = Int(statement.int(at: 6))
        let createdAt = Date(timeIntervalSince1970: TimeInterval(statement.int64(at: 7)))
        return Account(
            id: id,
            email: email,
            serverType: serverType,
            imapHost: imapHost,
            imapPort: imapPort,
            smtpHost: smtpHost,
            smtpPort: smtpPort,
            createdAt: createdAt
        )
    }

    private func message(from statement: SQLiteStatement) throws -> Message? {
        guard let id = statement.text(at: 0) else { return nil }
        guard let accountID = statement.text(at: 1) else { return nil }
        let messageID = statement.text(at: 2)
        let folderID = statement.text(at: 3)
        let subject = statement.text(at: 4)
        let sender = try decodeSender(statement.text(at: 5))
        let recipients = try decodeRecipients(statement.text(at: 6))
        let timestamp = statement.int64(at: 7)
        let date = timestamp > 0 ? Date(timeIntervalSince1970: TimeInterval(timestamp)) : nil
        let size = Int(statement.int(at: 8))
        let headers = try decodeHeaders(statement.text(at: 9))
        let bodyPlain = statement.text(at: 10)
        let bodyHTML = statement.text(at: 11)
        let isRead = statement.int(at: 12) == 1
        let isFlagged = statement.int(at: 13) == 1
        let isDeleted = statement.int(at: 14) == 1
        let cachedAt = Date(timeIntervalSince1970: TimeInterval(statement.int64(at: 15)))

        return Message(
            id: id,
            accountID: accountID,
            messageID: messageID,
            folderID: folderID,
            subject: subject,
            sender: sender,
            recipients: recipients,
            date: date,
            size: size,
            headers: headers,
            bodyPlain: bodyPlain,
            bodyHTML: bodyHTML,
            isRead: isRead,
            isFlagged: isFlagged,
            isDeleted: isDeleted,
            cachedAt: cachedAt
        )
    }

    private func attachment(from statement: SQLiteStatement) -> Attachment {
        let id = statement.text(at: 0) ?? UUID().uuidString
        let messageID = statement.text(at: 1) ?? ""
        let filename = statement.text(at: 2) ?? ""
        let mimeType = statement.text(at: 3) ?? "application/octet-stream"
        let size = Int(statement.int(at: 4))
        let data = statement.data(at: 5)
        let downloadedAtValue = statement.int64(at: 6)
        let downloadedAt = downloadedAtValue > 0 ? Date(timeIntervalSince1970: TimeInterval(downloadedAtValue)) : nil
        let isDownloaded = data != nil || downloadedAt != nil

        return Attachment(
            id: id,
            messageID: messageID,
            filename: filename,
            mimeType: mimeType,
            size: size,
            data: data,
            isDownloaded: isDownloaded,
            downloadedAt: downloadedAt
        )
    }

    private func folder(from statement: SQLiteStatement) -> IMAPFolder {
        let id = statement.text(at: 0) ?? UUID().uuidString
        let accountID = statement.text(at: 1) ?? ""
        let name = statement.text(at: 2) ?? ""
        let fullPath = statement.text(at: 3) ?? name
        let parentID = statement.text(at: 4)
        let uidValidity = statement.int(at: 5)
        let uidNext = statement.int(at: 6)

        return IMAPFolder(
            id: id,
            accountID: accountID,
            name: name,
            fullPath: fullPath,
            parentID: parentID,
            uidValidity: uidValidity == 0 ? nil : uidValidity,
            uidNext: uidNext == 0 ? nil : uidNext
        )
    }

    private func upsert(_ message: Message) throws {
        let sql = """
            INSERT INTO messages (
                id, account_id, message_id, folder_id, subject, sender, recipients, date, size, headers, body_plain, body_html, is_read, is_flagged, is_deleted, cached_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                account_id = excluded.account_id,
                message_id = excluded.message_id,
                folder_id = excluded.folder_id,
                subject = excluded.subject,
                sender = excluded.sender,
                recipients = excluded.recipients,
                date = excluded.date,
                size = excluded.size,
                headers = excluded.headers,
                body_plain = excluded.body_plain,
                body_html = excluded.body_html,
                is_read = excluded.is_read,
                is_flagged = excluded.is_flagged,
                is_deleted = excluded.is_deleted,
                cached_at = excluded.cached_at
        """
        let statement = try database.prepareStatement(sql)
        defer { statement.reset() }
        try statement.bind([
            .text(message.id),
            .text(message.accountID),
            SQLiteValue.from(optionalString: message.messageID),
            SQLiteValue.from(optionalString: message.folderID),
            SQLiteValue.from(optionalString: message.subject),
            encodeSender(message.sender),
            encodeRecipients(message.recipients),
            SQLiteValue.from(optionalDate: message.date),
            .int(Int64(message.size)),
            encodeHeaders(message.headers),
            SQLiteValue.from(optionalString: message.bodyPlain),
            SQLiteValue.from(optionalString: message.bodyHTML),
            .int(message.isRead ? 1 : 0),
            .int(message.isFlagged ? 1 : 0),
            .int(message.isDeleted ? 1 : 0),
            .int(Int64(message.cachedAt.timeIntervalSince1970))
        ])
        try statement.step()
    }

    private func updateMessageFlag(id: String, column: String, value: Bool) throws {
        let sql = "UPDATE messages SET \(column) = ? WHERE id = ?"
        let statement = try database.prepareStatement(sql)
        defer { statement.reset() }
        try statement.bind([
            .int(value ? 1 : 0),
            .text(id)
        ])
        try statement.step()
    }

    private func upsert(_ attachment: Attachment) throws {
        let sql = """
            INSERT INTO attachments (id, message_id, filename, mime_type, size, content, downloaded_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                message_id = excluded.message_id,
                filename = excluded.filename,
                mime_type = excluded.mime_type,
                size = excluded.size,
                content = excluded.content,
                downloaded_at = excluded.downloaded_at
        """
        let statement = try database.prepareStatement(sql)
        defer { statement.reset() }
        try statement.bind([
            .text(attachment.id),
            .text(attachment.messageID),
            .text(attachment.filename),
            .text(attachment.mimeType),
            .int(Int64(attachment.size)),
            attachment.data.map { SQLiteValue.blob($0) } ?? .null,
            SQLiteValue.from(optionalDate: attachment.downloadedAt)
        ])
        try statement.step()
    }

    private func upsert(_ folder: IMAPFolder) throws {
        let sql = """
            INSERT INTO imap_folders (id, account_id, name, full_path, parent_id, uidvalidity, uidnext)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                account_id = excluded.account_id,
                name = excluded.name,
                full_path = excluded.full_path,
                parent_id = excluded.parent_id,
                uidvalidity = excluded.uidvalidity,
                uidnext = excluded.uidnext
        """
        let statement = try database.prepareStatement(sql)
        defer { statement.reset() }
        try statement.bind([
            .text(folder.id),
            .text(folder.accountID),
            .text(folder.name),
            .text(folder.fullPath),
            SQLiteValue.from(optionalString: folder.parentID),
            SQLiteValue.from(optionalInt: folder.uidValidity),
            SQLiteValue.from(optionalInt: folder.uidNext)
        ])
        try statement.step()
    }

    private func encodeSender(_ sender: Message.Address?) -> SQLiteValue {
        guard let sender else { return .null }
        let data = try? encoder.encode(sender)
        return data.flatMap { SQLiteValue.text(String(data: $0, encoding: .utf8) ?? "") } ?? .null
    }

    private func decodeSender(_ value: String?) throws -> Message.Address? {
        guard let value, let data = value.data(using: .utf8) else { return nil }
        return try decoder.decode(Message.Address.self, from: data)
    }

    private func encodeRecipients(_ recipients: [Message.Address]) -> SQLiteValue {
        guard let data = try? encoder.encode(recipients), let string = String(data: data, encoding: .utf8) else {
            return .text("[]")
        }
        return .text(string)
    }

    private func decodeRecipients(_ value: String?) throws -> [Message.Address] {
        guard let value, let data = value.data(using: .utf8) else { return [] }
        return try decoder.decode([Message.Address].self, from: data)
    }

    private func encodeHeaders(_ headers: [String: String]) -> SQLiteValue {
        guard let data = try? encoder.encode(headers), let string = String(data: data, encoding: .utf8) else {
            return .text("{}")
        }
        return .text(string)
    }

    private func decodeHeaders(_ value: String?) throws -> [String: String] {
        guard let value, let data = value.data(using: .utf8) else { return [:] }
        return try decoder.decode([String: String].self, from: data)
    }
}

extension SQLiteMailRepository: @unchecked Sendable {}
