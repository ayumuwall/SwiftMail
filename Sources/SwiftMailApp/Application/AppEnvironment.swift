import Foundation
import SwiftMailCore
import SwiftMailDatabase

struct AppEnvironment {
    let database: MailDatabase
    let repository: SQLiteMailRepository

    static func bootstrap() throws -> AppEnvironment {
        let databaseURL = try defaultDatabaseURL()
        let database = MailDatabase(url: databaseURL)
        try database.open()
        let repository = SQLiteMailRepository(database: database)
        return AppEnvironment(database: database, repository: repository)
    }

    private static func defaultDatabaseURL() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw MailError.databaseError("アプリケーションサポートディレクトリを取得できませんでした")
        }
        let directory = applicationSupport.appendingPathComponent("SwiftMail", isDirectory: true)
        return directory.appendingPathComponent("mail.db")
    }
}
