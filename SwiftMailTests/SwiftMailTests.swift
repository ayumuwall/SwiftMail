import XCTest
@testable import SwiftMail

final class SwiftMailTests: XCTestCase {
    func testDatabaseMigrationCreatesSchema() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
        let dbURL = tempDirectory.appendingPathComponent("swiftmail-test-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let database = MailDatabase()
        try database.open(at: dbURL.path)
        try database.performMigrationsIfNeeded()
        try database.optimizeForPerformance()

        let repository = SQLiteMailRepository(database: database)
        let accounts = try repository.fetchAccounts()
        XCTAssertTrue(accounts.isEmpty)

        database.close()
    }
}
