import Foundation

final class AppEnvironment {
    private let fileManager: FileManager
    private(set) var database: MailDatabase?
    private(set) var repository: MailRepository?
    private(set) var syncCoordinator: MailSyncCoordinator?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func bootstrap() {
        do {
            let databaseURL = try ensureApplicationSupportURL().appendingPathComponent("mail.db", isDirectory: false)
            let database = MailDatabase()
            try database.open(at: databaseURL.path)
            try database.performMigrationsIfNeeded()
            try database.optimizeForPerformance()

            let repository = SQLiteMailRepository(database: database)
            let syncCoordinator = MailSyncCoordinator(repository: repository)

            self.database = database
            self.repository = repository
            self.syncCoordinator = syncCoordinator
        } catch {
            assertionFailure("環境初期化に失敗しました: \(error)")
        }
    }

    func shutdown() {
        database?.close()
        database = nil
        repository = nil
        syncCoordinator = nil
    }

    private func ensureApplicationSupportURL() throws -> URL {
        guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw EnvironmentError.unableToResolveApplicationSupport
        }
        let appURL = baseURL.appendingPathComponent("SwiftMail", isDirectory: true)
        if !fileManager.fileExists(atPath: appURL.path) {
            try fileManager.createDirectory(at: appURL, withIntermediateDirectories: true, attributes: nil)
        }
        return appURL
    }
}

enum EnvironmentError: Error {
    case unableToResolveApplicationSupport
}
