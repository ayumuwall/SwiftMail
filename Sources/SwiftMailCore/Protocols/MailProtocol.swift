import Foundation

public protocol MailProtocol: Sendable {
    func connect() async throws
    func authenticate() async throws
    func fetchMessages() async throws -> [Message]
    func deleteMessage(_ id: String) async throws
}
