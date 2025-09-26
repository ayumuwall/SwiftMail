import XCTest
import SwiftMailCore
@testable import SwiftMailDatabase

final class MailDatabaseTests: XCTestCase {
    func testOpenAndSchemaCreation() throws {
        let tempDirectory = try temporaryDirectory()
        let databaseURL = tempDirectory.appendingPathComponent("mail.db")
        let database = MailDatabase(url: databaseURL)

        XCTAssertNoThrow(try database.open())

        let repository = SQLiteMailRepository(database: database)
        let account = Account(
            email: "user@example.com",
            serverType: .imap,
            imapHost: "imap.example.com",
            smtpHost: "smtp.example.com"
        )
        try repository.upsertAccount(account)
        let fetched = try repository.fetchAccount(by: account.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.email, account.email)

        let accounts = try repository.fetchAccounts()
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts.first?.id, account.id)

        database.close()
    }

    private func temporaryDirectory() throws -> URL {
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: base)
        }
        return base
    }
}
