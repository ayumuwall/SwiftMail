import Foundation
import SQLite3

enum MailDatabaseError: Error, LocalizedError {
    case alreadyOpen
    case notOpen
    case sqliteError(code: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .alreadyOpen:
            return "データベースはすでに開かれています"
        case .notOpen:
            return "データベースが開かれていません"
        case .sqliteError(_, let message):
            return message
        }
    }
}

final class MailDatabase {
    private var handle: OpaquePointer?
    private let queue = DispatchQueue(label: "com.swiftmail.database", qos: .userInitiated)

    deinit {
        close()
    }

    func open(at path: String) throws {
        if handle != nil {
            throw MailDatabaseError.alreadyOpen
        }

        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        var db: OpaquePointer?
        let status = sqlite3_open_v2(path, &db, flags, nil)
        guard status == SQLITE_OK, let db else {
            let message = Self.errorMessage(from: db)
            sqlite3_close(db)
            throw MailDatabaseError.sqliteError(code: status, message: message)
        }
        handle = db
        try execute("PRAGMA foreign_keys = ON")
    }

    func close() {
        guard let db = handle else { return }
        sqlite3_close(db)
        handle = nil
    }

    func performMigrationsIfNeeded() throws {
        try queue.sync {
            let currentVersion = try self.userVersion()
            guard currentVersion == 0 else { return }

            try self.executeUnlocked("BEGIN IMMEDIATE TRANSACTION")
            do {
                try self.executeUnlocked(Schema.accounts)
                try self.executeUnlocked(Schema.messages)
                try self.executeUnlocked(Schema.messagesIndexes)
                try self.executeUnlocked(Schema.messagesFTS)
                try self.executeUnlocked(Schema.attachments)
                try self.executeUnlocked(Schema.pop3UIDL)
                try self.executeUnlocked(Schema.imapFolders)
                try self.executeUnlocked("PRAGMA user_version = 1")
                try self.executeUnlocked("COMMIT")
            } catch {
                try? self.executeUnlocked("ROLLBACK")
                throw error
            }
        }
    }

    func optimizeForPerformance() throws {
        try queue.sync {
            try self.executeUnlocked("PRAGMA journal_mode = WAL")
            try self.executeUnlocked("PRAGMA synchronous = NORMAL")
            try self.executeUnlocked("PRAGMA cache_size = -64000")
            try self.executeUnlocked("PRAGMA temp_store = MEMORY")
            try self.executeUnlocked("PRAGMA mmap_size = 134217728")
        }
    }

    func execute(_ sql: String) throws {
        try queue.sync {
            try executeUnlocked(sql)
        }
    }

    private func executeUnlocked(_ sql: String) throws {
        guard let db = handle else { throw MailDatabaseError.notOpen }
        var errorPointer: UnsafeMutablePointer<Int8>?
        let result = sqlite3_exec(db, sql, nil, nil, &errorPointer)
        if result != SQLITE_OK {
            let message = errorPointer.flatMap { String(cString: $0) } ?? "不明なエラー"
            sqlite3_free(errorPointer)
            throw MailDatabaseError.sqliteError(code: result, message: message)
        }
    }

    func withPreparedStatement<R>(_ sql: String, _ body: (OpaquePointer) throws -> R) throws -> R {
        try queue.sync {
            guard let db = handle else { throw MailDatabaseError.notOpen }
            var statement: OpaquePointer?
            let status = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
            guard status == SQLITE_OK, let statement else {
                let message = Self.errorMessage(from: db)
                throw MailDatabaseError.sqliteError(code: status, message: message)
            }
            defer { sqlite3_finalize(statement) }
            return try body(statement)
        }
    }

    private func userVersion() throws -> Int {
        guard let db = handle else { throw MailDatabaseError.notOpen }
        var statement: OpaquePointer?
        let status = sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &statement, nil)
        guard status == SQLITE_OK, let statement else {
            let message = Self.errorMessage(from: db)
            throw MailDatabaseError.sqliteError(code: status, message: message)
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(statement, 0))
    }

    private static func errorMessage(from db: OpaquePointer?) -> String {
        guard let db else { return "不明なエラー" }
        if let message = sqlite3_errmsg(db) {
            return String(cString: message)
        }
        return "不明なエラー"
    }
}

private extension MailDatabase {
    enum Schema {
        static let accounts = """
        CREATE TABLE IF NOT EXISTS accounts (
            id TEXT PRIMARY KEY,
            email TEXT NOT NULL UNIQUE,
            server_type TEXT CHECK(server_type IN ('imap', 'pop3')),
            imap_host TEXT,
            imap_port INTEGER DEFAULT 993,
            smtp_host TEXT,
            smtp_port INTEGER DEFAULT 587,
            created_at INTEGER DEFAULT (strftime('%s','now'))
        );
        """

        static let messages = """
        CREATE TABLE IF NOT EXISTS messages (
            id TEXT PRIMARY KEY,
            account_id TEXT NOT NULL,
            message_id TEXT,
            folder_id TEXT,
            subject TEXT,
            sender TEXT,
            recipients TEXT,
            date INTEGER,
            size INTEGER,
            headers TEXT,
            body_plain TEXT,
            body_html TEXT,
            is_read INTEGER DEFAULT 0,
            is_flagged INTEGER DEFAULT 0,
            is_deleted INTEGER DEFAULT 0,
            cached_at INTEGER DEFAULT (strftime('%s','now')),
            FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
        );
        """

        static let messagesIndexes = """
        CREATE INDEX IF NOT EXISTS idx_messages_date ON messages(date DESC);
        CREATE INDEX IF NOT EXISTS idx_messages_unread ON messages(is_read, date DESC) WHERE is_read = 0;
        CREATE INDEX IF NOT EXISTS idx_messages_account_folder ON messages(account_id, folder_id);
        """

        static let messagesFTS = """
        CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
            subject, sender, body_plain,
            content=messages,
            tokenize='unicode61 remove_diacritics 2'
        );
        """

        static let attachments = """
        CREATE TABLE IF NOT EXISTS attachments (
            id TEXT PRIMARY KEY,
            message_id TEXT NOT NULL,
            filename TEXT,
            mime_type TEXT,
            size INTEGER,
            content BLOB,
            downloaded_at INTEGER,
            FOREIGN KEY(message_id) REFERENCES messages(id) ON DELETE CASCADE
        );
        """

        static let pop3UIDL = """
        CREATE TABLE IF NOT EXISTS pop3_uidl (
            account_id TEXT,
            uidl TEXT,
            downloaded_at INTEGER,
            PRIMARY KEY(account_id, uidl),
            FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
        );
        """

        static let imapFolders = """
        CREATE TABLE IF NOT EXISTS imap_folders (
            id TEXT PRIMARY KEY,
            account_id TEXT NOT NULL,
            name TEXT NOT NULL,
            full_path TEXT NOT NULL,
            parent_id TEXT,
            uidvalidity INTEGER,
            uidnext INTEGER,
            FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
        );
        """
    }
}
