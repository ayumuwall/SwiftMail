import Foundation
import SQLite3

protocol MailRepository {
    func fetchAccounts() throws -> [Account]
    func upsert(account: Account) throws
    func fetchMessages(accountID: UUID, limit: Int) throws -> [Message]
}

final class SQLiteMailRepository: MailRepository {
    private let database: MailDatabase

    init(database: MailDatabase) {
        self.database = database
    }

    func fetchAccounts() throws -> [Account] {
        try database.withPreparedStatement("""
            SELECT id, email, server_type, imap_host, imap_port, smtp_host, smtp_port, created_at
            FROM accounts
            ORDER BY created_at DESC
        """) { statement in
            var accounts: [Account] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let idString = stringColumn(statement, index: 0)
                guard let id = UUID(uuidString: idString) else { continue }
                let email = stringColumn(statement, index: 1)
                let serverRaw = stringColumn(statement, index: 2)
                let serverType = Account.ServerType(rawValue: serverRaw) ?? .imap
                let imapHost = optionalStringColumn(statement, index: 3)
                let imapPort = Int(sqlite3_column_int(statement, 4))
                let smtpHost = stringColumn(statement, index: 5)
                let smtpPort = Int(sqlite3_column_int(statement, 6))
                let createdAtSeconds = sqlite3_column_int64(statement, 7)
                let createdAt = Date(timeIntervalSince1970: TimeInterval(createdAtSeconds))

                accounts.append(Account(id: id,
                                        email: email,
                                        serverType: serverType,
                                        imapHost: imapHost,
                                        imapPort: imapPort,
                                        smtpHost: smtpHost,
                                        smtpPort: smtpPort,
                                        createdAt: createdAt))
            }
            return accounts
        }
    }

    func upsert(account: Account) throws {
        try database.withPreparedStatement("""
            INSERT OR REPLACE INTO accounts (
                id, email, server_type, imap_host, imap_port, smtp_host, smtp_port, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """) { statement in
            sqlite3_bind_text(statement, 1, account.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, account.email, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, account.serverType.rawValue, -1, SQLITE_TRANSIENT)
            if let host = account.imapHost {
                sqlite3_bind_text(statement, 4, host, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(statement, 4)
            }
            sqlite3_bind_int(statement, 5, Int32(account.imapPort))
            sqlite3_bind_text(statement, 6, account.smtpHost, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 7, Int32(account.smtpPort))
            sqlite3_bind_int64(statement, 8, sqlite3_int64(account.createdAt.timeIntervalSince1970))

            guard sqlite3_step(statement) == SQLITE_DONE else {
                let code = sqlite3_errcode(sqlite3_db_handle(statement))
                let message = String(cString: sqlite3_errmsg(sqlite3_db_handle(statement)))
                throw MailDatabaseError.sqliteError(code: code, message: message)
            }
            return ()
        }
    }

    func fetchMessages(accountID: UUID, limit: Int) throws -> [Message] {
        try database.withPreparedStatement("""
            SELECT id, account_id, message_id, folder_id, subject, sender, recipients, date,
                   size, headers, body_plain, body_html, is_read, is_flagged, is_deleted, cached_at
            FROM messages
            WHERE account_id = ?
            ORDER BY date DESC
            LIMIT ?
        """) { statement in
            sqlite3_bind_text(statement, 1, accountID.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 2, Int32(limit))

            var messages: [Message] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let id = UUID(uuidString: stringColumn(statement, index: 0)),
                      let accountID = UUID(uuidString: stringColumn(statement, index: 1)) else {
                    continue
                }
                let messageID = optionalStringColumn(statement, index: 2)
                let folderID = optionalStringColumn(statement, index: 3).flatMap(UUID.init(uuidString:))
                let subject = stringColumn(statement, index: 4)
                let sender = stringColumn(statement, index: 5)
                let recipientsJSON = optionalStringColumn(statement, index: 6)
                let dateValue = sqlite3_column_int64(statement, 7)
                let size = Int(sqlite3_column_int(statement, 8))
                let headersJSON = optionalStringColumn(statement, index: 9)
                let bodyPlain = stringColumn(statement, index: 10)
                let bodyHTML = optionalStringColumn(statement, index: 11)
                let isRead = sqlite3_column_int(statement, 12) == 1
                let isFlagged = sqlite3_column_int(statement, 13) == 1
                let isDeleted = sqlite3_column_int(statement, 14) == 1
                let cachedAtValue = sqlite3_column_int64(statement, 15)

                let recipients = recipientsJSON
                    .flatMap { try? JSONDecoder().decode([String].self, from: Data($0.utf8)) }
                    ?? []

                let message = Message(id: id,
                                      accountID: accountID,
                                      messageID: messageID,
                                      folderID: folderID,
                                      subject: subject,
                                      sender: sender,
                                      recipients: recipients,
                                      date: Date(timeIntervalSince1970: TimeInterval(dateValue)),
                                      size: size,
                                      headersJSON: headersJSON,
                                      bodyPlain: bodyPlain,
                                      bodyHTML: bodyHTML,
                                      isRead: isRead,
                                      isFlagged: isFlagged,
                                      isDeleted: isDeleted,
                                      cachedAt: Date(timeIntervalSince1970: TimeInterval(cachedAtValue)))
                messages.append(message)
            }
            return messages
        }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func stringColumn(_ statement: OpaquePointer, index: Int32) -> String {
    guard let cString = sqlite3_column_text(statement, index) else { return "" }
    return String(cString: cString)
}

private func optionalStringColumn(_ statement: OpaquePointer, index: Int32) -> String? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
    return stringColumn(statement, index: index)
}
