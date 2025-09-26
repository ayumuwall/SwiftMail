import Foundation

public extension MailRepository {
    func fetchAccountsAsync() async throws -> [Account] {
        try await Task.detached(priority: .userInitiated) {
            try fetchAccounts()
        }.value
    }

    func fetchAccountAsync(by id: String) async throws -> Account? {
        try await Task.detached(priority: .userInitiated) {
            try fetchAccount(by: id)
        }.value
    }

    func fetchMessagesAsync(accountID: String, folderID: String?, limit: Int, offset: Int) async throws -> [Message] {
        try await Task.detached(priority: .userInitiated) {
            try fetchMessages(accountID: accountID, folderID: folderID, limit: limit, offset: offset)
        }.value
    }

    func fetchIMAPFoldersAsync(accountID: String) async throws -> [IMAPFolder] {
        try await Task.detached(priority: .userInitiated) {
            try fetchIMAPFolders(accountID: accountID)
        }.value
    }
}
