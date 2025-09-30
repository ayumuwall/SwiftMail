# CONTRIBUTING.md

SwiftMail への貢献に関心をお寄せいただきありがとうございます。本プロジェクトは「Minimalism First」「Performance Focused」「Native Experience」という 3 つの原則のもとで運営されています。以下のガイドラインを必ず確認し、プロジェクトの方向性を尊重した上でコントリビュートしてください。

## 1. 事前に確認すること
- 最初に必ず [AGENTS.md](AGENTS.md) を熟読し、開発思想・禁止事項・技術要件を理解してください。
- 日本語でのコミュニケーションが必須です。Issue / Pull Request / コードコメントも日本語で記述してください。
- ライセンスは Apache License 2.0 です。貢献いただくコードは同ライセンスで公開されます。

## 2. 貢献の種類と優先度
| カテゴリ | 受け入れ方針 |
| --- | --- |
| ✅ パフォーマンス改善 | 常に歓迎。変更前後の測定結果を提示してください。 |
| ✅ バグ修正 | 再現手順、原因、修正内容を明記してください。 |
| ✅ セキュリティ強化 | 影響範囲とリスク評価を添えてください。 |
| ⚠️ 新機能 | 原則として最小限に留めます。Issue で事前議論が必須です。 |
| ❌ 外部依存の追加 | いかなる場合も認めません。標準フレームワークのみ使用可能です。 |
| ❌ 機能の肥大化 | メール送受信の本質から外れる提案は受け付けません。 |

## 3. 作業フロー
1. GitHub Issue で課題を確認し、未アサインの場合はコメントで担当を表明してください。
2. リポジトリをフォークし、`main` を基点にフィーチャーブランチを作成します。例: `git checkout -b feature/short-description`。
3. 変更は関連するコンポーネントの最小単位に留め、1 PR につき 1 機能/修正を徹底してください。
4. コミットメッセージはプレフィックス不要ですが、内容が一読で分かる日本語を心掛けてください。
5. 変更後は必ず `swift build` と `swift test` をローカルで実行し、結果を PR テンプレートに記載してください。
6. フォーク先にプッシュし、Pull Request を作成します。PR の説明には以下を含めてください:
   - 目的・背景
   - 主な変更点
   - テスト結果 (実行したコマンドと結果)
   - 残課題またはフォローアップ案

## 4. 🤖 AI/LLMコーディング歓迎

SwiftMailは**Claude Code、GitHub Copilot、Cursor等のAI支援開発を積極的に歓迎**します。

### なぜAI開発に適しているか

- ✅ **プログラマティックUI設計** - 全UIが.swiftコードで記述（XIB/Storyboard不使用）
- ✅ **詳細なAGENTS.md** - LLMが開発方針を完全理解可能
- ✅ **厳格なガイドライン** - 一貫性のあるコード生成
- ✅ **モノリシック設計** - 明確な実装パターン

### AI生成コードの提出ガイド

1. **[AGENTS.md](AGENTS.md)を必読**
   - LLMにこのファイル全体を読み込ませてください
   - 開発思想・禁止事項・実装パターンを理解させることが重要です

2. **生成元の明記（推奨）**
   ```
   PR説明に記載例:
   - 使用AI: Claude Code / GitHub Copilot / Cursor 等
   - 人間レビュー: [どの部分を確認・修正したか]
   - テスト: [実行した確認内容]
   ```

3. **レビューチェックリスト遵守**
   - [ ] メモリリーク確認（`weak self`の使用）
   - [ ] UI更新がメインスレッド（`@MainActor`）
   - [ ] プログラマティックUI（XIB/Storyboard不使用）
   - [ ] 禁止ファイル（.xcodeproj, .xib, .storyboard等）未編集
   - [ ] 外部ライブラリ未追加
   - [ ] パフォーマンス目標を満たす

### AI開発の実例

```swift
// ✅ LLMが生成しやすいコード例（AGENTS.mdのパターンに準拠）
final class MessageListViewController: NSViewController {
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
    }

    private func setupTableView() {
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
```

### 重要な注意点

- **AI生成でも人間の最終レビューは必須**です
- LLMが生成したコードでも、動作確認・テスト実行は必ず行ってください
- セキュリティに関わる部分（Keychain操作等）は特に慎重に確認してください

## 5. コーディングガイドラインの要点
- **依存関係**: Foundation / AppKit / WebKit / Security 以外の外部ライブラリは禁止です。SQLite は C API を直接呼び出してください。
- **アーキテクチャ**: `SwiftMailCore → SwiftMailDatabase → SwiftMailApp` のレイヤリングを崩さないでください。UI から直接データベース層を触らないこと。
- **UI**: プログラマティックUI必須（コードのみ）。Auto Layout を必須とし、フレームベースのレイアウトは禁止です。システムフォント・システムカラーを使用してください。
- **スレッド**: UI 更新は `@MainActor` を厳守。非同期処理は適切な QoS を設定し、循環参照に注意して `weak self` を利用してください。
- **パフォーマンス**: 大量データ処理ではカーソル・ストリーミングを活用し、不要なコピーを避けてください。測定結果や推定インパクトを PR に明記してください。
- **ドキュメント**: 設計に関する重要な判断を行った場合は README または関連ドキュメントを更新してください。

## 6. テストと品質保証
- すべての変更は `swift test` を通過させてください。必要に応じてユニットテスト・統合テストを追加してください。
- 新しい機能やバグ修正には再現ケースをテストとして追加することを推奨します。
- Instruments や Activity Monitor を用いた性能計測結果がある場合、PR に記録してください。

## 7. レビュー基準
レビューでは以下を優先的に確認します。
- プロジェクトの哲学（ミニマリズム・パフォーマンス・ネイティブ体験）に合致しているか。
- パフォーマンス・メモリ・安定性に悪影響が出ていないか。
- SQLite3 の使用方法が適切か（ステートメントの解放、トランザクション管理など）。
- UI のアクセシビリティとショートカット互換性を損なっていないか。
- ドキュメントやコードコメントが簡潔で分かりやすいか。

## 8. Issue / Pull Request のクローズ基準
- 受け入れられた変更はメンテナーが `main` にマージし、該当 Issue をクローズします。
- プロジェクト方針と合致しない提案はクローズ理由を明記して終了します。
- 一定期間アクティビティがない PR はメンテナー判断でクローズする場合があります。

## 9. セキュリティに関する報告
潜在的な脆弱性を発見した場合は、公開 Issue ではなく GitHub Security Advisories から報告してください。迅速に対応できるよう、再現手順と影響度を添えてください。

## 10. 連絡先
- 一般的な質問: GitHub Discussions
- バグ報告: GitHub Issues
- セキュリティ: GitHub Security Advisories

SwiftMail をより良いメールクライアントにするため、みなさまのご協力をお待ちしています。
