import XCTest
@testable import SwiftMailCore

final class CoreModelTests: XCTestCase {
    func testAccountInitializationDefaults() {
        let account = Account(
            email: "user@example.com",
            serverType: .imap,
            imapHost: "imap.example.com",
            smtpHost: "smtp.example.com"
        )

        XCTAssertEqual(account.imapPort, 993)
        XCTAssertEqual(account.smtpPort, 587)
        XCTAssertEqual(account.serverType, .imap)
    }

    func testMessageRecipientsEncoding() throws {
        let message = Message(
            accountID: UUID().uuidString,
            recipients: [
                Message.Address(name: "Test", email: "test@example.com")
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(message.recipients)
        XCTAssertNotNil(String(data: data, encoding: .utf8))
    }
}
