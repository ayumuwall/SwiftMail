import XCTest
@testable import SwiftMailCore

final class MessageComposerTests: XCTestCase {

    var composer: MessageComposer!

    override func setUp() {
        super.setUp()
        composer = MessageComposer()
    }

    override func tearDown() {
        composer = nil
        super.tearDown()
    }

    func testComposeSimpleMessage() throws {
        let from = EmailAddress(email: "sender@example.com", name: "Sender")
        let to = [EmailAddress(email: "recipient@example.com", name: "Recipient")]

        let message = try composer.compose(
            from: from,
            to: to,
            subject: "Test Subject",
            body: "This is a test message."
        )

        XCTAssertTrue(message.contains("From: \"Sender\" <sender@example.com>"))
        XCTAssertTrue(message.contains("To: \"Recipient\" <recipient@example.com>"))
        XCTAssertTrue(message.contains("Subject: Test Subject"))
        XCTAssertTrue(message.contains("This is a test message."))
        XCTAssertTrue(message.contains("MIME-Version: 1.0"))
        XCTAssertTrue(message.contains("Content-Type: text/plain; charset=UTF-8"))
    }

    func testComposeHTMLMessage() throws {
        let from = EmailAddress(email: "sender@example.com", name: nil)
        let to = [EmailAddress(email: "recipient@example.com", name: nil)]

        let message = try composer.compose(
            from: from,
            to: to,
            subject: "HTML Email",
            body: "<html><body><h1>Hello</h1></body></html>",
            isHTML: true
        )

        XCTAssertTrue(message.contains("Content-Type: text/html; charset=UTF-8"))
        XCTAssertTrue(message.contains("<html><body><h1>Hello</h1></body></html>"))
    }

    func testComposeMultipleRecipients() throws {
        let from = EmailAddress(email: "sender@example.com", name: "Sender")
        let to = [
            EmailAddress(email: "user1@example.com", name: "User 1"),
            EmailAddress(email: "user2@example.com", name: "User 2")
        ]

        let message = try composer.compose(
            from: from,
            to: to,
            subject: "Multiple Recipients",
            body: "Test body"
        )

        XCTAssertTrue(message.contains("To: \"User 1\" <user1@example.com>, \"User 2\" <user2@example.com>"))
    }

    func testComposeWithCc() throws {
        let from = EmailAddress(email: "sender@example.com", name: "Sender")
        let to = [EmailAddress(email: "to@example.com", name: nil)]
        let cc = [EmailAddress(email: "cc@example.com", name: "CC User")]

        let message = try composer.compose(
            from: from,
            to: to,
            cc: cc,
            subject: "With CC",
            body: "Test body"
        )

        XCTAssertTrue(message.contains("Cc: \"CC User\" <cc@example.com>"))
    }

    func testComposeReplyMessage() throws {
        let from = EmailAddress(email: "sender@example.com", name: "Sender")
        let to = [EmailAddress(email: "recipient@example.com", name: nil)]

        let message = try composer.compose(
            from: from,
            to: to,
            subject: "Re: Original Subject",
            body: "Reply body",
            inReplyTo: "<12345@example.com>",
            references: ["<12345@example.com>", "<67890@example.com>"]
        )

        XCTAssertTrue(message.contains("In-Reply-To: <12345@example.com>"))
        XCTAssertTrue(message.contains("References: <12345@example.com> <67890@example.com>"))
    }

    func testComposeWithJapaneseSubject() throws {
        let from = EmailAddress(email: "sender@example.com", name: nil)
        let to = [EmailAddress(email: "recipient@example.com", name: nil)]

        let message = try composer.compose(
            from: from,
            to: to,
            subject: "日本語の件名テスト",
            body: "本文"
        )

        // UTF-8 Base64エンコードされているか確認
        XCTAssertTrue(message.contains("Subject: =?UTF-8?B?"))
    }

    func testComposeWithoutName() throws {
        let from = EmailAddress(email: "sender@example.com", name: nil)
        let to = [EmailAddress(email: "recipient@example.com", name: nil)]

        let message = try composer.compose(
            from: from,
            to: to,
            subject: "No Name",
            body: "Test"
        )

        XCTAssertTrue(message.contains("From: sender@example.com"))
        XCTAssertTrue(message.contains("To: recipient@example.com"))
    }

    func testComposeIncludesMessageId() throws {
        let from = EmailAddress(email: "sender@example.com", name: nil)
        let to = [EmailAddress(email: "recipient@example.com", name: nil)]

        let message = try composer.compose(
            from: from,
            to: to,
            subject: "Test",
            body: "Test"
        )

        XCTAssertTrue(message.contains("Message-ID: <"))
        XCTAssertTrue(message.contains("@example.com>"))
    }

    func testComposeIncludesDate() throws {
        let from = EmailAddress(email: "sender@example.com", name: nil)
        let to = [EmailAddress(email: "recipient@example.com", name: nil)]

        let message = try composer.compose(
            from: from,
            to: to,
            subject: "Test",
            body: "Test"
        )

        XCTAssertTrue(message.contains("Date: "))
    }

    func testComposeMissingRecipient() {
        let from = EmailAddress(email: "sender@example.com", name: nil)

        XCTAssertThrowsError(try composer.compose(
            from: from,
            to: [],
            subject: "Test",
            body: "Test"
        )) { error in
            XCTAssertTrue(error is MessageComposer.ComposerError)
        }
    }
}
