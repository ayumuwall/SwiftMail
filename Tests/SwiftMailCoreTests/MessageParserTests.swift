import XCTest
@testable import SwiftMailCore

final class MessageParserTests: XCTestCase {

    var parser: MessageParser!

    override func setUp() {
        super.setUp()
        parser = MessageParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    func testParseSimpleMessage() throws {
        let rawMessage = """
        From: sender@example.com\r
        To: recipient@example.com\r
        Subject: Test Subject\r
        Date: Mon, 01 Oct 2025 12:00:00 +0900\r
        Message-ID: <12345@example.com>\r
        \r
        This is the body of the email.
        """

        let parsed = try parser.parse(rawMessage: rawMessage)

        XCTAssertEqual(parsed.messageId, "<12345@example.com>")
        XCTAssertEqual(parsed.subject, "Test Subject")
        XCTAssertEqual(parsed.from?.email, "sender@example.com")
        XCTAssertEqual(parsed.to.count, 1)
        XCTAssertEqual(parsed.to.first?.email, "recipient@example.com")
        XCTAssertEqual(parsed.bodyPlain, "This is the body of the email.")
        XCTAssertNil(parsed.bodyHTML)
    }

    func testParseMessageWithName() throws {
        let rawMessage = """
        From: "Sender Name" <sender@example.com>\r
        To: "Recipient Name" <recipient@example.com>\r
        Subject: Test\r
        \r
        Body text.
        """

        let parsed = try parser.parse(rawMessage: rawMessage)

        XCTAssertEqual(parsed.from?.email, "sender@example.com")
        XCTAssertEqual(parsed.from?.name, "Sender Name")
        XCTAssertEqual(parsed.to.first?.email, "recipient@example.com")
        XCTAssertEqual(parsed.to.first?.name, "Recipient Name")
    }

    func testParseMultipleRecipients() throws {
        let rawMessage = """
        From: sender@example.com\r
        To: user1@example.com, user2@example.com, user3@example.com\r
        Subject: Multiple Recipients\r
        \r
        Body.
        """

        let parsed = try parser.parse(rawMessage: rawMessage)

        XCTAssertEqual(parsed.to.count, 3)
        XCTAssertEqual(parsed.to[0].email, "user1@example.com")
        XCTAssertEqual(parsed.to[1].email, "user2@example.com")
        XCTAssertEqual(parsed.to[2].email, "user3@example.com")
    }

    func testParseWithCc() throws {
        let rawMessage = """
        From: sender@example.com\r
        To: to@example.com\r
        Cc: cc1@example.com, cc2@example.com\r
        Subject: With CC\r
        \r
        Body.
        """

        let parsed = try parser.parse(rawMessage: rawMessage)

        XCTAssertEqual(parsed.cc.count, 2)
        XCTAssertEqual(parsed.cc[0].email, "cc1@example.com")
        XCTAssertEqual(parsed.cc[1].email, "cc2@example.com")
    }

    func testParseHTMLContent() throws {
        let rawMessage = """
        From: sender@example.com\r
        To: recipient@example.com\r
        Subject: HTML Email\r
        Content-Type: text/html; charset="UTF-8"\r
        \r
        <html><body><h1>HTML Body</h1></body></html>
        """

        let parsed = try parser.parse(rawMessage: rawMessage)

        XCTAssertNil(parsed.bodyPlain)
        XCTAssertEqual(parsed.bodyHTML, "<html><body><h1>HTML Body</h1></body></html>")
    }

    func testParseMultilineBody() throws {
        let rawMessage = """
        From: sender@example.com\r
        To: recipient@example.com\r
        Subject: Multiline\r
        \r
        Line 1\r
        \r
        Line 2\r
        \r
        Line 3
        """

        let parsed = try parser.parse(rawMessage: rawMessage)

        XCTAssertTrue(parsed.bodyPlain?.contains("Line 1") == true)
        XCTAssertTrue(parsed.bodyPlain?.contains("Line 2") == true)
        XCTAssertTrue(parsed.bodyPlain?.contains("Line 3") == true)
    }

    func testParseFoldedHeader() throws {
        let rawMessage = """
        From: sender@example.com\r
        To: recipient@example.com\r
        Subject: This is a very long subject line\r
         that is folded across multiple lines\r
         for better readability\r
        \r
        Body.
        """

        let parsed = try parser.parse(rawMessage: rawMessage)

        XCTAssertTrue(parsed.subject?.contains("very long subject") == true)
        XCTAssertTrue(parsed.subject?.contains("folded") == true)
    }

    func testParseHeadersOnly() throws {
        let rawMessage = """
        From: sender@example.com\r
        To: recipient@example.com\r
        Subject: Headers Only
        """

        let parsed = try parser.parse(rawMessage: rawMessage)

        XCTAssertEqual(parsed.subject, "Headers Only")
        XCTAssertNil(parsed.bodyPlain)
        XCTAssertNil(parsed.bodyHTML)
    }

    func testParseDateFormat() throws {
        let rawMessage = """
        From: sender@example.com\r
        To: recipient@example.com\r
        Subject: Date Test\r
        Date: Mon, 01 Oct 2025 12:34:56 +0900\r
        \r
        Body.
        """

        let parsed = try parser.parse(rawMessage: rawMessage)

        XCTAssertNotNil(parsed.date)
        // 日付が正しくパースされていることを確認
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: parsed.date!)
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 10)
        XCTAssertEqual(components.day, 1)
    }

    func testEmailAddressDisplayName() {
        let addressWithName = EmailAddress(email: "test@example.com", name: "Test User")
        XCTAssertEqual(addressWithName.displayName, "Test User")

        let addressWithoutName = EmailAddress(email: "test@example.com", name: nil)
        XCTAssertEqual(addressWithoutName.displayName, "test@example.com")
    }
}
