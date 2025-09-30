import Foundation
import Security

/// Keychainへの安全なパスワード保存・取得を提供
public final class KeychainManager: @unchecked Sendable {

    public enum KeychainError: LocalizedError {
        case itemNotFound
        case duplicateItem
        case invalidData
        case unhandledError(status: OSStatus)

        public var errorDescription: String? {
            switch self {
            case .itemNotFound:
                return "Keychainにアイテムが見つかりません"
            case .duplicateItem:
                return "既に同じアイテムが存在します"
            case .invalidData:
                return "無効なデータ形式です"
            case .unhandledError(let status):
                return "Keychainエラー（コード: \(status)）"
            }
        }
    }

    private let service: String

    public init(service: String = "com.swiftmail.app") {
        self.service = service
    }

    // MARK: - Password Management

    /// パスワードを保存
    public func savePassword(_ password: String, for account: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            // 既存アイテムを更新
            try updatePassword(password, for: account)
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }

    /// パスワードを取得
    public func retrievePassword(for account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unhandledError(status: status)
        }

        guard let passwordData = result as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return password
    }

    /// パスワードを更新
    public func updatePassword(_ password: String, for account: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: passwordData
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unhandledError(status: status)
        }
    }

    /// パスワードを削除
    public func deletePassword(for account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    /// すべてのパスワードを削除（テスト用）
    public func deleteAllPasswords() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)

        // アイテムが存在しない場合もエラーにしない
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
}
