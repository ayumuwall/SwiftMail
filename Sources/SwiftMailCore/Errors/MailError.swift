import Foundation

public enum MailError: LocalizedError, Sendable {
    case connectionFailed(String)
    case authenticationFailed
    case invalidEmailFormat
    case networkTimeout
    case serverNotResponding
    case quotaExceeded
    case databaseError(String)
    case decodingError

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let server):
            return "サーバー '\(server)' への接続に失敗しました"
        case .authenticationFailed:
            return "認証に失敗しました"
        case .invalidEmailFormat:
            return "メールアドレスの形式が正しくありません"
        case .networkTimeout:
            return "ネットワークタイムアウトが発生しました"
        case .serverNotResponding:
            return "サーバーから応答がありません"
        case .quotaExceeded:
            return "サーバーの保存容量を超えました"
        case .databaseError(let message):
            return "データベースエラー: \(message)"
        case .decodingError:
            return "データの読み込みに失敗しました"
        }
    }
}
