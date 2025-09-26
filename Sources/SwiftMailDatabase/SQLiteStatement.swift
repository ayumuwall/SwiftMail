import Foundation
import SQLite3
import SwiftMailCore

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum SQLiteValue {
    case int(Int64)
    case double(Double)
    case text(String)
    case blob(Data)
    case null

    static func from(optionalInt value: Int?) -> SQLiteValue {
        if let value { return .int(Int64(value)) }
        return .null
    }

    static func from(optionalString value: String?) -> SQLiteValue {
        if let value { return .text(value) }
        return .null
    }

    static func from(optionalDate value: Date?) -> SQLiteValue {
        if let value { return .int(Int64(value.timeIntervalSince1970)) }
        return .null
    }
}

public final class SQLiteStatement {
    let pointer: OpaquePointer

    init(database: OpaquePointer, sql: String) throws {
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
        guard result == SQLITE_OK, let prepared = statement else {
            let message = sqlite3_errmsg(database).flatMap { String(cString: $0) } ?? "ステートメントの準備に失敗しました"
            throw MailError.databaseError(message)
        }
        pointer = prepared
    }

    deinit {
        sqlite3_finalize(pointer)
    }

    public func bind(_ values: [SQLiteValue]) throws {
        for (index, value) in values.enumerated() {
            try bind(value, to: Int32(index + 1))
        }
    }

    public func bind(_ value: SQLiteValue, to index: Int32) throws {
        let result: Int32
        switch value {
        case .int(let number):
            result = sqlite3_bind_int64(pointer, index, number)
        case .double(let number):
            result = sqlite3_bind_double(pointer, index, number)
        case .text(let string):
            result = sqlite3_bind_text(pointer, index, string, -1, SQLITE_TRANSIENT)
        case .blob(let data):
            result = data.withUnsafeBytes { bytes in
                sqlite3_bind_blob(pointer, index, bytes.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
            }
        case .null:
            result = sqlite3_bind_null(pointer, index)
        }
        if result != SQLITE_OK {
            let message = sqlite3_errmsg(sqlite3_db_handle(pointer)).flatMap { String(cString: $0) } ?? "バインドに失敗しました"
            throw MailError.databaseError(message)
        }
    }

    @discardableResult
    public func step() throws -> Int32 {
        let result = sqlite3_step(pointer)
        if result != SQLITE_ROW && result != SQLITE_DONE {
            let message = sqlite3_errmsg(sqlite3_db_handle(pointer)).flatMap { String(cString: $0) } ?? "ステップに失敗しました"
            throw MailError.databaseError(message)
        }
        return result
    }

    public func reset() {
        sqlite3_reset(pointer)
        sqlite3_clear_bindings(pointer)
    }

    public func text(at index: Int32) -> String? {
        guard let cString = sqlite3_column_text(pointer, index) else { return nil }
        return String(cString: cString)
    }

    public func int(at index: Int32) -> Int {
        Int(sqlite3_column_int(pointer, index))
    }

    public func int64(at index: Int32) -> Int64 {
        sqlite3_column_int64(pointer, index)
    }

    public func double(at index: Int32) -> Double {
        sqlite3_column_double(pointer, index)
    }

    public func data(at index: Int32) -> Data? {
        guard let bytes = sqlite3_column_blob(pointer, index) else { return nil }
        let length = Int(sqlite3_column_bytes(pointer, index))
        return Data(bytes: bytes, count: length)
    }
}
