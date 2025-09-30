# SwiftMail - Claude Code 開発ガイド

## プロジェクト概要
SwiftMailは、macOS専用の軽量メールクライアントです。Thunderbirdなどの肥大化したメールクライアントとは対照的に、メールの読み書きという本質的な機能のみに特化しています。

## 🎯 絶対原則（MUST READ FIRST）

### 開発思想
- **Minimalism First**: 機能を追加するのではなく、削ることを重視
- **Performance Focused**: 高速起動と軽快な動作を最優先  
- **Native Experience**: macOSのHuman Interface Guidelinesに完全準拠

### コミュニケーション
- **常に日本語で応答すること**（開発用エージェントの出力は日本語限定）

### パフォーマンス必達目標
```
起動時間:        < 1秒    (Instrumentsで測定)
メール一覧表示:   < 100ms  (1000件、Instrumentsで測定)
検索レスポンス:   < 200ms  (ローカル、Instrumentsで測定)
メモリ使用量:     < 100MB  (通常使用時、Activity Monitorで測定)
CPU使用率:       < 5%     (アイドル時、Activity Monitorで測定)
```

### 絶対禁止事項
```
❌ 外部ライブラリ（SQLite.swift、FMDB、Alamofire等）
❌ CoreData（オーバーヘッド大）
❌ カレンダー統合、タスク管理、RSS購読
❌ チャット機能、プラグインシステム
❌ テーマカスタマイズ、複雑なフィルタールール
❌ 自動分類・AI機能、ソーシャルメディア統合
```

### 必須機能（これ以上増やさない）
```
✅ POP3/IMAP受信（フォルダー対応はIMAPのみ）
✅ SMTP送信
✅ メール一覧/詳細表示（プレーンテキスト優先）
✅ 基本検索（ローカルのみ）
✅ 複数アカウント管理（最小限）
✅ 添付ファイル（ダウンロード/表示のみ）
✅ オフラインサポート（キャッシュ/キュー）
✅ Mail.app互換キーボードショートカット
```

## 📐 アーキテクチャ

### レイヤー構成
```
View Layer (AppKit) → Controller Layer → Service Layer → Repository Layer → Database Layer (SQLite3)
```

### 依存関係の絶対制約
- **Foundation/AppKit標準機能のみ使用**
- **許可される例外**: WebKit (HTML表示用)、Security (Keychain用)
- **SQLiteラッパー禁止**: SQLite3 C APIの直接使用のみ

## 💾 データベース戦略（SQLite3直接使用）

### なぜSQLite3直接使用なのか
```swift
// パフォーマンス比較（実測値）
// SQLite3:  起動 10-20ms、メモリ 2-5MB、クエリ 5-10ms
// CoreData: 起動 50-100ms、メモリ 10-15MB、クエリ 15-30ms

// 結論: SQLite3で起動時間-80%、メモリ-70%削減
```

### データベース設定
```swift
// MailDatabase.swift
import SQLite3

final class MailDatabase {
    private var db: OpaquePointer?
    
    func optimizeForPerformance() {
        execute("PRAGMA journal_mode = WAL")        // Write-Ahead Logging
        execute("PRAGMA synchronous = NORMAL")      // バランスの良い同期
        execute("PRAGMA cache_size = -64000")       // 64MBキャッシュ
        execute("PRAGMA temp_store = MEMORY")       // 一時データはメモリ
        execute("PRAGMA mmap_size = 134217728")     // 128MBメモリマップ
    }
}
```

### SQLiteスキーマ定義
```sql
-- アカウント管理
CREATE TABLE accounts (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    server_type TEXT CHECK(server_type IN ('imap', 'pop3')),
    imap_host TEXT,
    imap_port INTEGER DEFAULT 993,
    smtp_host TEXT,
    smtp_port INTEGER DEFAULT 587,
    created_at INTEGER DEFAULT (strftime('%s', 'now'))
);

-- メッセージ保存
CREATE TABLE messages (
    id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL,
    message_id TEXT,         -- Message-ID header
    folder_id TEXT,          -- IMAPのみ、POP3はNULL
    subject TEXT,
    sender TEXT,
    recipients TEXT,         -- JSON array
    date INTEGER,
    size INTEGER,
    headers TEXT,            -- JSON
    body_plain TEXT,
    body_html TEXT,
    is_read INTEGER DEFAULT 0,
    is_flagged INTEGER DEFAULT 0,
    is_deleted INTEGER DEFAULT 0,
    cached_at INTEGER DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
);

-- 高速検索用インデックス（必須）
CREATE INDEX idx_messages_date ON messages(date DESC);
CREATE INDEX idx_messages_unread ON messages(is_read, date DESC) WHERE is_read = 0;
CREATE INDEX idx_messages_account_folder ON messages(account_id, folder_id);

-- 全文検索（FTS5）
CREATE VIRTUAL TABLE messages_fts USING fts5(
    subject, sender, body_plain,
    content=messages,
    tokenize='unicode61 remove_diacritics 2'
);

-- 添付ファイル
CREATE TABLE attachments (
    id TEXT PRIMARY KEY,
    message_id TEXT NOT NULL,
    filename TEXT,
    mime_type TEXT,
    size INTEGER,
    content BLOB,            -- NULL if not downloaded (on-demand)
    downloaded_at INTEGER,
    FOREIGN KEY(message_id) REFERENCES messages(id) ON DELETE CASCADE
);

-- POP3専用：UIDL管理（重複防止）
CREATE TABLE pop3_uidl (
    account_id TEXT,
    uidl TEXT,
    downloaded_at INTEGER,
    PRIMARY KEY(account_id, uidl),
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
);

-- IMAPフォルダー階層
CREATE TABLE imap_folders (
    id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL,
    name TEXT NOT NULL,
    full_path TEXT NOT NULL,
    parent_id TEXT,
    uidvalidity INTEGER,
    uidnext INTEGER,
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
);
```

### メモリ効率的なデータアクセス
```swift
// カーソルベースのストリーミング（大量データでもメモリ効率的）
struct MessageIterator: Sequence, IteratorProtocol {
    private let statement: OpaquePointer?
    
    mutating func next() -> Message? {
        guard sqlite3_step(statement) == SQLITE_ROW else { 
            sqlite3_finalize(statement)
            return nil 
        }
        return Message(from: statement)
    }
}

// トランザクション制御
func performBatch(_ block: () throws -> Void) rethrows {
    execute("BEGIN IMMEDIATE TRANSACTION")
    do {
        try block()
        execute("COMMIT")
    } catch {
        execute("ROLLBACK")
        throw error
    }
}
```

## 🔄 データ同期・キャッシュ戦略

### キャッシュポリシー
```swift
struct CachePolicy {
    static let recentMailsDays = 30              // 30日分フルキャッシュ
    static let headerOnlyAfterDays = 30          // それ以前はヘッダーのみ
    static let attachmentPolicy = .onDemand      // 添付は必要時のみ
    static let maxAttachmentCacheMB = 500.0      // 添付キャッシュ上限
    static let maxTotalCacheGB = 1.0             // 総キャッシュ上限
}
```

### 同期戦略
```swift
enum SyncStrategy {
    case full        // 初回同期
    case incremental // 差分同期（通常）
    case headers     // ヘッダーのみ（高速）
}

// POP3: UIDLで重複チェック
// IMAP: UID FETCHで差分同期、FLAGSで既読管理
```

## 📂 ファイルシステム構造
```
~/Library/Application Support/SwiftMail/
├── mail.db                  # SQLiteデータベース
├── mail.db-wal              # WALファイル
└── backups/                 # 日次バックアップ（最大7世代）

~/Library/Caches/SwiftMail/
└── attachments/             # 添付ファイルキャッシュ

~/Library/Preferences/
└── com.swiftmail.plist      # 設定（機密情報以外）

Keychain: 
└── パスワード、認証トークン等
```

## ⚡ メール処理プロトコル実装

### POP3/IMAP共通インターフェース
```swift
protocol MailProtocol {
    func connect() async throws
    func authenticate() async throws
    func fetchMessages() async throws -> [Message]
    func deleteMessage(_ id: String) async throws
}

// POP3制約
// - フォルダーなし（受信トレイのみ）
// - サーバー側既読管理なし
// - UIDL必須（重複防止）

// IMAP機能
// - フォルダー階層
// - サーバー側フラグ管理
// - 部分フェッチ（BODY.PEEK）
```

## 🛡️ セキュリティ実装必須要件

### 認証情報保管（Keychainのみ）
```swift
import Security

func savePassword(_ password: String, for account: String) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account,
        kSecValueData as String: password.data(using: .utf8)!,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]
    SecItemAdd(query as CFDictionary, nil)
}

// ❌ 絶対禁止: UserDefaults、plist、ファイルへの保存
```

### 通信セキュリティ
```swift
// TLS 1.2以上強制
let config = URLSessionConfiguration.default
config.tlsMinimumSupportedProtocolVersion = .TLSv12

// 証明書検証
func urlSession(_ session: URLSession, 
                didReceive challenge: URLAuthenticationChallenge) {
    // 証明書ピンニング実装
}
```

### HTMLメールセキュリティ
```swift
import WebKit

class SecureMailViewer {
    func configureWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = false              // JS完全禁止
        config.websiteDataStore = .nonPersistent()               // データ保存なし
        config.suppressesIncrementalRendering = true             // 外部リソース無効
        
        return WKWebView(frame: .zero, configuration: config)
    }
    
    func sanitizeHTML(_ html: String) -> String {
        // CSP適用
        return """
        <meta http-equiv="Content-Security-Policy" 
              content="default-src 'self'; script-src 'none'; style-src 'unsafe-inline';">
        """ + html
    }
}
```

## 🎨 UI/UX実装規則

### UI構築方針（LLM最適化）

SwiftMailは**AppKitプログラマティックUI（コードベース）**を採用します。これはLLMによる開発に最適化された選択です。

#### フレームワーク比較と選択理由

| フレームワーク | 採用 | 理由 |
|--------------|------|------|
| **AppKit（プログラマティック）** | ✅ 採用 | LLMが完全理解可能、最高速、最小メモリ、完全制御 |
| SwiftUI | ❌ 禁止 | ランタイムオーバーヘッド大、メモリ使用量増、抽象化による制御不能 |
| XIB/Storyboard | ❌ 禁止 | バイナリファイル、LLMが編集不可、起動オーバーヘッド |
| Catalyst | ❌ 禁止 | iOS互換レイヤー不要、パフォーマンス劣化 |

#### プログラマティックUI実装例

```swift
// ✅ 正しい実装（AppKitプログラマティック）
final class MessageListViewController: NSViewController {
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
    }

    private func configureTableView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

// ❌ SwiftUI（禁止）
struct MessageListView: View {
    var body: some View {
        List { }
    }
}

// ❌ XIB/Storyboard（禁止）
@IBOutlet weak var tableView: NSTableView!
```

#### なぜプログラマティックUIなのか

**LLMによる開発効率**:
- ✅ 全てのUIコードが.swiftファイルに記述される
- ✅ LLMがコンテキスト全体を理解可能
- ✅ バージョン管理の差分が明確
- ✅ コンパイル時型チェック

**パフォーマンス**:
- ✅ XIB/Storyboardのロード時間ゼロ（起動時間-50ms以上削減）
- ✅ SwiftUIのランタイムオーバーヘッドなし（メモリ-30%削減）
- ✅ 直接AppKit APIアクセスによる最適化

**保守性**:
- ✅ 検索・置換が容易
- ✅ リファクタリング安全性
- ✅ コードレビューが明確

### LLMが生成・編集してはいけないファイル（厳格なルール）

```
❌ 絶対に生成・編集禁止:
  - *.storyboard      (Interface Builderバイナリファイル)
  - *.xib             (Interface Builderバイナリファイル)
  - *.xcodeproj/*     (Xcodeプロジェクト設定、人間が管理)
  - *.xcworkspace/*   (Xcodeワークスペース設定)
  - project.pbxproj   (Xcodeプロジェクトファイル、競合多発)
  - *.xcassets/*      (Asset Catalog、人間がXcodeで管理)

✅ LLMが生成・編集可能:
  - *.swift           (Swiftソースコード)
  - Package.swift     (SwiftPMマニフェスト、テキスト形式)
  - *.md              (ドキュメント)
  - .gitignore        (Git設定)
```

**理由**:
- Xcodeプロジェクトファイルは複雑なXML/バイナリ形式
- LLMによる編集はマージコンフリクト・破損リスク大
- Interface Builderファイルは人間による視覚的編集が必須
- プログラマティックUIならSwiftコードのみで完結

### 必須キーボードショートカット（Mail.app完全互換）
```swift
enum KeyboardShortcut {
    static let newMail = "⌘N"        // 新規メール
    static let reply = "⌘R"          // 返信
    static let replyAll = "⇧⌘R"      // 全員に返信
    static let forward = "⇧⌘F"       // 転送
    static let send = "⇧⌘D"          // 送信
    static let delete = "⌫"          // ゴミ箱へ
    static let search = "⌘F"         // 検索
    static let preview = "Space"     // プレビュー
}
```

### レイアウト規則（Auto Layout必須）
```swift
// ✅ 正しい実装
view.translatesAutoresizingMaskIntoConstraints = false
NSLayoutConstraint.activate([
    view.topAnchor.constraint(equalTo: superview.topAnchor),
    view.leadingAnchor.constraint(equalTo: superview.leadingAnchor)
])

// ❌ フレームベースは禁止
view.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
```

### システムカラー/フォント使用
```swift
// カラー（システムカラー必須）
let textColor = NSColor.labelColor
let backgroundColor = NSColor.controlBackgroundColor

// フォント（システムフォント必須）
let bodyFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
let titleFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 2)
```

### アクセシビリティ（VoiceOver完全対応）
```swift
messageCell.accessibilityLabel = "\(message.sender), \(message.subject)"
messageCell.accessibilityTraits = message.isRead ? .none : .updatesFrequently
messageCell.accessibilityHint = "ダブルタップでメールを開きます"
```

## 🔄 エラーハンドリングとリカバリー

### エラー定義
```swift
enum MailError: LocalizedError {
    case connectionFailed(String)
    case authenticationFailed
    case invalidEmailFormat
    case networkTimeout
    case serverNotResponding
    case quotaExceeded
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed(let server):
            return "サーバー '\(server)' への接続に失敗しました"
        case .authenticationFailed:
            return "認証に失敗しました"
        // ...
        }
    }
}
```

### 自動リトライ戦略
```swift
struct RetryPolicy {
    static let maxRetries = 3
    static let backoffMultiplier = 2.0
    static let initialDelay: TimeInterval = 1.0
}

// エクスポネンシャルバックオフ実装
func retry<T>(operation: () async throws -> T) async throws -> T {
    var delay = RetryPolicy.initialDelay
    for _ in 0..<RetryPolicy.maxRetries {
        do {
            return try await operation()
        } catch {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            delay *= RetryPolicy.backoffMultiplier
        }
    }
    throw MailError.serverNotResponding
}
```

### オフライン動作
```swift
class OfflineQueue {
    private var outboxQueue: [Message] = []
    
    func queueForSending(_ message: Message) {
        outboxQueue.append(message)
        // 送信キューに保存、接続回復時に自動送信
    }
}
```

## ⚠️ アンチパターン（絶対にやってはいけない）

### データベース
```swift
// ❌ CoreData
let container = NSPersistentContainer(name: "Model")

// ❌ 外部ライブラリ
import SQLite  // SQLite.swift
import FMDB

// ✅ 正しい実装
import SQLite3
```

### ネットワーク処理
```swift
// ❌ 同期処理
let data = try Data(contentsOf: url)

// ✅ 非同期処理
Task {
    let data = try await URLSession.shared.data(from: url)
}
```

### ViewControllerの肥大化
```swift
// ❌ 巨大なViewController
class MassiveViewController: NSViewController {
    // 500行以上のコード...
}

// ✅ 責任分割
class MailListViewController: NSViewController {
    private let dataSource = MailListDataSource()
    private let delegate = MailListDelegate()
}
```

### メモリ管理
```swift
// ❌ 循環参照
service.completion = { 
    self.handleCompletion()  // selfを強参照
}

// ✅ weak self使用
service.completion = { [weak self] in
    self?.handleCompletion()
}
```

## 📊 パフォーマンス最適化指針

### 非同期処理とQoS
```swift
// UI更新: メインスレッド必須
DispatchQueue.main.async {
    self.tableView.reloadData()
}

// バックグラウンド処理: 適切なQoS選択
DispatchQueue.global(qos: .userInitiated).async {  // ユーザー待機中
    // メール同期処理
}

DispatchQueue.global(qos: .utility).async {  // バックグラウンド
    // インデックス作成
}
```

### メモリ効率化
```swift
// 遅延初期化
lazy var messageParser = MessageParser()

// 大量データ処理時のautoreleasepool
autoreleasepool {
    for message in largeMessageArray {
        processMessage(message)
    }
}

// 定期的なキャッシュクリーンアップ
Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
    self.purgeOldCache()
}
```

## 🚀 実装優先順位（フェーズ別）

### Phase 1: 基盤（最優先）
```
□ AppDelegate、MainWindowController
□ SQLiteデータベース層（スキーマ、最適化）
□ 基本3ペインレイアウト
□ データモデル（Account、Message、Folder）
□ Keychainアクセス層
```

### Phase 2: 受信機能
```
□ IMAP接続クラス
□ POP3接続クラス
□ メッセージパーサー（RFC822準拠）
□ メール一覧表示
□ メール詳細表示（プレーンテキスト）
□ HTMLメール表示（セキュア設定）
```

### Phase 3: 送信機能
```
□ SMTP接続クラス
□ メール作成UI
□ 送信処理（キュー管理）
□ 下書き保存
□ 添付ファイル処理
```

### Phase 4: 基本機能強化
```
□ ローカル検索（FTS5）
□ キーボードショートカット実装
□ アクセシビリティ完全対応
□ 複数アカウント切り替え
```

### Phase 5: 最適化
```
□ パフォーマンスチューニング
□ メモリ使用量削減
□ 起動時間短縮
□ エラーハンドリング強化
```

## ⚙️ ユーザー設定（最小限のみ）

### 必須設定
- アカウント情報（メール、パスワード、サーバー）
- 署名テキスト
- 同期間隔（手動/5分/15分/30分）

### オプション設定
- フォントサイズ（小/標準/大）
- ダークモード（システム設定に従う）
- 通知設定（オン/オフ）
- 起動時の動作（前回状態/受信箱）

## 🧪 テスト戦略

### カバレッジ目標
- ユニットテスト: 80%以上
- 統合テスト: 主要フロー100%

### テスト対象
```swift
// モデルのテスト例
class MessageParserTests: XCTestCase {
    func testParseSimpleMessage() {
        let rawMessage = "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
        let message = MessageParser.parse(rawMessage)
        
        XCTAssertEqual(message.from, "test@example.com")
        XCTAssertEqual(message.subject, "Test")
        XCTAssertEqual(message.body, "Body")
    }
}
```

## 📝 開発環境設定

### Xcode設定
```
Swift Language Version: 5.9
Deployment Target: macOS 12.0
App Sandbox: Enabled
Hardened Runtime: Enabled
```

### 必須Entitlements
```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.swiftmail.app</string>
</array>
```

### ビルド構成
```
Debug:   詳細ログ、アサーション有効、最適化なし
Release: 最適化有効、ログ最小限、dSYM生成  
Profile: Instruments向け、最適化有効、デバッグシンボル付き
```

## 📋 Claude Code開発時の判断基準

### 新機能追加の判断フロー
```
1. その機能はメール送受信に必須か？
   → No: 実装しない
   → Yes: 次へ

2. 既存機能で代替可能か？
   → Yes: 実装しない
   → No: 次へ

3. パフォーマンスに悪影響があるか？
   → Yes: 実装しない
   → No: 最小限の実装を検討
```

### LLM開発ガードレール（厳格遵守）

#### ファイル編集権限

```
✅ LLMが自由に生成・編集可能:
  *.swift              - Swiftソースコード（メインの開発対象）
  Package.swift        - SwiftPMマニフェスト（テキスト形式）
  *.md                 - ドキュメント
  .gitignore           - Git設定
  *.json               - 設定ファイル（テキスト形式）

❌ LLMが絶対に生成・編集禁止:
  *.storyboard         - Interface Builderファイル（バイナリ/XML複合）
  *.xib                - Interface Builderファイル（バイナリ/XML複合）
  *.xcodeproj/*        - Xcodeプロジェクト設定（複雑なXML、人間が管理）
  *.xcworkspace/*      - Xcodeワークスペース（複雑なXML）
  project.pbxproj      - Xcodeプロジェクト本体（マージコンフリクト頻発）
  *.xcassets/*         - Asset Catalog（バイナリ、Xcodeで管理）
  xcuserdata/*         - Xcodeユーザー設定（自動生成）
  xcshareddata/*       - Xcodeスキーム（自動生成）

⚠️ 読み取りのみ許可（編集時は人間に確認）:
  Info.plist           - アプリケーション設定（Xcodeで管理推奨）
  Entitlements.plist   - セキュリティ設定（慎重な編集が必要）
```

#### 禁止理由の詳細

**Xcodeプロジェクトファイル（*.xcodeproj/*）**:
- LLMによる編集は99%の確率でプロジェクト破損を引き起こす
- マージコンフリクト解決が極めて困難
- Xcodeのビルドシステムが内部形式を頻繁に変更
- 人間がXcodeのGUIで操作すべき領域

**Interface Builder（*.storyboard, *.xib）**:
- バイナリ化されたXML（LLMが正確に編集できない）
- ビジュアル編集が前提（コード編集は非効率）
- SwiftMailはプログラマティックUIのため使用しない

**Asset Catalog（*.xcassets/*）**:
- Xcodeが専用フォーマットで管理
- 画像最適化・リソース圧縮を自動実行
- 人間がXcodeで追加・管理すべき

#### LLMが守るべき開発フロー

```
1. ユーザーから機能追加要求
   ↓
2. LLMは.swiftファイルのみを生成・編集
   ↓
3. 新しいファイルを追加した場合:
   「Xcodeで[プロジェクト名].xcodeprojを開き、
    手動でファイルをプロジェクトに追加してください」
   と指示を出力
   ↓
4. Xcodeプロジェクト設定の変更が必要な場合:
   「Xcodeで以下の設定を手動で変更してください:
    - ターゲット設定 > General > ...」
   と具体的な手順を出力
```

### レビューチェックリスト
```
□ メモリリークの可能性はないか
□ UI更新がメインスレッドか
□ エラーハンドリングが適切か
□ ファイル構成が規約に従っているか
□ 機能が最小限に絞られているか
□ パフォーマンス目標を満たしているか
□ アクセシビリティ対応がされているか
□ SQLite3 C APIを直接使用しているか
□ プログラマティックUI（コードのみ）で実装されているか
□ 禁止ファイル（.xcodeproj, .storyboard, .xib等）を編集していないか
```

## 🔍 クイックリファレンス

### ファイルパス
```
DB: ~/Library/Application Support/SwiftMail/mail.db
キャッシュ: ~/Library/Caches/SwiftMail/
設定: ~/Library/Preferences/com.swiftmail.plist
```

### デバッグログ
```swift
#if DEBUG
import os.log
private let logger = OSLog(subsystem: "com.swiftmail.app", category: "MailService")
os_log("%{public}@", log: logger, type: .info, message)
#endif
```

### バージョニング
```
Major: 互換性のない変更
Minor: 後方互換性のある機能追加
Patch: バグ修正
リリースサイクル: バグ修正は随時、機能追加は年1回以下
```

---
**開発時の最重要原則**: 迷ったら機能を「追加しない」選択をする。シンプルさこそが最大の機能。
