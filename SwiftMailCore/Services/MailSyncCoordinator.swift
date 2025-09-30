import Foundation

final class MailSyncCoordinator {
    enum Strategy {
        case full
        case incremental
        case headers
    }

    private let repository: MailRepository
    private let queue = DispatchQueue(label: "com.swiftmail.sync", qos: .userInitiated)

    init(repository: MailRepository) {
        self.repository = repository
    }

    func synchronize(accounts: [Account], strategy: Strategy = .incremental, completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            do {
                // プロトコル実装が整うまではダミー同期。
                for account in accounts {
                    _ = try self.repository.fetchMessages(accountID: account.id, limit: 1)
                    _ = strategy
                }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
