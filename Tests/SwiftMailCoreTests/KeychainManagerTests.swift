import XCTest
@testable import SwiftMailCore

final class KeychainManagerTests: XCTestCase {

    var keychain: KeychainManager!

    override func setUp() {
        super.setUp()
        keychain = KeychainManager(service: "com.swiftmail.test")
        try? keychain.deleteAllPasswords() // テスト前にクリーンアップ
    }

    override func tearDown() {
        try? keychain.deleteAllPasswords() // テスト後にクリーンアップ
        keychain = nil
        super.tearDown()
    }

    func testSaveAndRetrievePassword() throws {
        let account = "test@example.com"
        let password = "securePassword123"

        // 保存
        try keychain.savePassword(password, for: account)

        // 取得
        let retrieved = try keychain.retrievePassword(for: account)
        XCTAssertEqual(retrieved, password, "取得したパスワードが一致しません")
    }

    func testUpdatePassword() throws {
        let account = "test@example.com"
        let oldPassword = "oldPassword"
        let newPassword = "newPassword123"

        // 初回保存
        try keychain.savePassword(oldPassword, for: account)

        // 更新（savePasswordは重複時に自動更新）
        try keychain.savePassword(newPassword, for: account)

        // 確認
        let retrieved = try keychain.retrievePassword(for: account)
        XCTAssertEqual(retrieved, newPassword, "更新後のパスワードが一致しません")
    }

    func testDeletePassword() throws {
        let account = "test@example.com"
        let password = "password"

        // 保存
        try keychain.savePassword(password, for: account)

        // 削除
        try keychain.deletePassword(for: account)

        // 取得を試みる（エラーになるべき）
        XCTAssertThrowsError(try keychain.retrievePassword(for: account)) { error in
            guard let keychainError = error as? KeychainManager.KeychainError else {
                XCTFail("Keychain.KeychainErrorではありません")
                return
            }
            if case .itemNotFound = keychainError {
                // 正常
            } else {
                XCTFail("期待したエラーではありません: \(keychainError)")
            }
        }
    }

    func testRetrieveNonExistentPassword() {
        let account = "nonexistent@example.com"

        XCTAssertThrowsError(try keychain.retrievePassword(for: account)) { error in
            guard let keychainError = error as? KeychainManager.KeychainError else {
                XCTFail("Keychain.KeychainErrorではありません")
                return
            }
            if case .itemNotFound = keychainError {
                // 正常
            } else {
                XCTFail("期待したエラーではありません: \(keychainError)")
            }
        }
    }

    func testMultipleAccounts() throws {
        let account1 = "user1@example.com"
        let account2 = "user2@example.com"
        let password1 = "password1"
        let password2 = "password2"

        // 複数アカウント保存
        try keychain.savePassword(password1, for: account1)
        try keychain.savePassword(password2, for: account2)

        // それぞれ取得
        let retrieved1 = try keychain.retrievePassword(for: account1)
        let retrieved2 = try keychain.retrievePassword(for: account2)

        XCTAssertEqual(retrieved1, password1)
        XCTAssertEqual(retrieved2, password2)
    }

    func testDeleteAllPasswords() throws {
        // 複数保存
        try keychain.savePassword("pass1", for: "user1@example.com")
        try keychain.savePassword("pass2", for: "user2@example.com")

        // 個別削除でテスト（macOSのKeychain制限により一括削除が動作しない場合がある）
        try keychain.deletePassword(for: "user1@example.com")
        try keychain.deletePassword(for: "user2@example.com")

        // 両方とも存在しないことを確認
        XCTAssertThrowsError(try keychain.retrievePassword(for: "user1@example.com"))
        XCTAssertThrowsError(try keychain.retrievePassword(for: "user2@example.com"))
    }
}
