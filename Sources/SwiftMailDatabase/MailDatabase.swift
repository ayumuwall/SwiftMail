import Foundation
import SQLite3
import SwiftMailCore

public final class MailDatabase: @unchecked Sendable {
    public let url: URL

    private var handle: OpaquePointer?
    private let queue: DispatchQueue
    private let queueKey = DispatchSpecificKey<Void>()

    public init(url: URL, queue: DispatchQueue = DispatchQueue(label: "com.swiftmail.database", qos: .utility)) {
        self.url = url
        self.queue = queue
        self.queue.setSpecific(key: queueKey, value: ())
    }

    deinit {
        close()
    }

    public func open() throws {
        if handle != nil { return }
        try prepareDirectory()

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(url.path, &db, flags, nil)
        guard result == SQLITE_OK, let opened = db else {
            throw MailError.databaseError(lastErrorMessage(from: db))
        }
        handle = opened
        sqlite3_busy_timeout(opened, 3_000)
        try optimizeForPerformance()
        try createSchemaIfNeeded()
    }

    public func close() {
        guard let db = handle else { return }
        sqlite3_close_v2(db)
        handle = nil
    }

    public func execute(_ sql: String) throws {
        try openIfNeeded()
        try withConnection { db in
            try run(sql: sql, on: db)
        }
    }

    public func performBatch(_ block: () throws -> Void) throws {
        try openIfNeeded()
        try withConnection { db in
            try run(sql: "BEGIN IMMEDIATE TRANSACTION", on: db)
            do {
                try block()
                try run(sql: "COMMIT", on: db)
            } catch {
                try? run(sql: "ROLLBACK", on: db)
                throw error
            }
        }
    }

    public func prepareStatement(_ sql: String) throws -> SQLiteStatement {
        try openIfNeeded()
        return try withConnection { db in
            try SQLiteStatement(database: db, sql: sql)
        }
    }

    private func optimizeForPerformance() throws {
        try execute("PRAGMA journal_mode = WAL")
        try execute("PRAGMA synchronous = NORMAL")
        try execute("PRAGMA cache_size = -64000")
        try execute("PRAGMA temp_store = MEMORY")
        try execute("PRAGMA mmap_size = 134217728")
    }

    private func createSchemaIfNeeded() throws {
        try performBatch {
            try execute("""
                CREATE TABLE IF NOT EXISTS accounts (
                    id TEXT PRIMARY KEY,
                    email TEXT NOT NULL UNIQUE,
                    server_type TEXT CHECK(server_type IN ('imap', 'pop3')),
                    imap_host TEXT,
                    imap_port INTEGER DEFAULT 993,
                    smtp_host TEXT,
                    smtp_port INTEGER DEFAULT 587,
                    created_at INTEGER DEFAULT (strftime('%s', 'now'))
                )
            """)

            try execute("""
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
                    cached_at INTEGER DEFAULT (strftime('%s', 'now')),
                    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
                )
            """)

            try execute("CREATE INDEX IF NOT EXISTS idx_messages_date ON messages(date DESC)")
            try execute("CREATE INDEX IF NOT EXISTS idx_messages_unread ON messages(is_read, date DESC) WHERE is_read = 0")
            try execute("CREATE INDEX IF NOT EXISTS idx_messages_account_folder ON messages(account_id, folder_id)")

            try execute("""
                CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
                    subject, sender, body_plain,
                    content=messages,
                    tokenize='unicode61 remove_diacritics 2'
                )
            """)

            try execute("""
                CREATE TABLE IF NOT EXISTS attachments (
                    id TEXT PRIMARY KEY,
                    message_id TEXT NOT NULL,
                    filename TEXT,
                    mime_type TEXT,
                    size INTEGER,
                    content BLOB,
                    downloaded_at INTEGER,
                    FOREIGN KEY(message_id) REFERENCES messages(id) ON DELETE CASCADE
                )
            """)

            try execute("""
                CREATE TABLE IF NOT EXISTS pop3_uidl (
                    account_id TEXT,
                    uidl TEXT,
                    downloaded_at INTEGER,
                    PRIMARY KEY(account_id, uidl),
                    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
                )
            """)

            try execute("""
                CREATE TABLE IF NOT EXISTS imap_folders (
                    id TEXT PRIMARY KEY,
                    account_id TEXT NOT NULL,
                    name TEXT NOT NULL,
                    full_path TEXT NOT NULL,
                    parent_id TEXT,
                    uidvalidity INTEGER,
                    uidnext INTEGER,
                    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
                )
            """)
        }
    }

    private func prepareDirectory() throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func openIfNeeded() throws {
        if handle == nil {
            try open()
        }
    }

    private func withConnection<T>(_ work: (OpaquePointer) throws -> T) throws -> T {
        guard let db = handle else {
            throw MailError.databaseError("データベースが開かれていません")
        }
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return try work(db)
        } else {
            return try queue.sync {
                try work(db)
            }
        }
    }

    private func run(sql: String, on db: OpaquePointer) throws {
        var errorMessage: UnsafeMutablePointer<Int8>? = nil
        defer {
            if let message = errorMessage {
                sqlite3_free(message)
            }
        }
        let result = sqlite3_exec(db, sql, nil, nil, &errorMessage)
        if result != SQLITE_OK {
            let message = errorMessage.flatMap { String(cString: $0) } ?? lastErrorMessage(from: db)
            throw MailError.databaseError(message)
        }
    }

    private func lastErrorMessage(from db: OpaquePointer?) -> String {
        guard let db else { return "不明なエラー" }
        if let cString = sqlite3_errmsg(db) {
            return String(cString: cString)
        }
        return "不明なエラー"
    }
}
