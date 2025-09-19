# SwiftMail

<div align="center">
  <img src="assets/icon.png" alt="SwiftMail Icon" width="128" height="128">
  
  **超軽量・超高速なmacOS用メールクライアント（開発中）**
  
  [![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
  [![macOS](https://img.shields.io/badge/macOS-12.0+-blue.svg)](https://www.apple.com/macos)
  [![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)
  [![Status](https://img.shields.io/badge/Status-Pre--Alpha-red.svg)](https://github.com/yourusername/SwiftMail)
  [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
</div>

[English](README.en.md) | **日本語**

---

## 🚧 開発状況

**SwiftMailは現在開発初期段階です。** パフォーマンスとミニマリズムを最優先に、基盤部分から構築しています。

### 現在の進捗
- ✅ アーキテクチャ設計完了
- ✅ 開発ガイドライン策定済み
- 🚧 データベース層実装中（SQLite3）
- 🚧 基本UI構築中
- ⏳ IMAP/POP3プロトコル実装予定
- ⏳ コア機能実装予定

## 🎯 開発思想と目標

**ミニマリズム・ファースト** - SwiftMailは肥大化したメールクライアントのアンチテーゼです。他が機能を追加する中、私たちは本質を磨きます。

### パフォーマンス目標
- **起動時間**: 1秒以下
- **メモリ使用量**: 100MB以下
- **検索速度**: 10ms以下（10,000通のメール）
- **外部依存**: ゼロ
- **ネイティブ度**: 100% macOS純正体験

## ✨ 実装予定機能

### SwiftMailがやること
- 📋 **超高速動作** - 目標：1秒起動、10,000通を10msで検索
- 📋 **POP3/IMAP対応** - 外部ライブラリなしで完全実装
- 📋 **セキュリティ重視** - Keychain統合、TLS 1.2以上、JavaScript無効化
- 📋 **オフライン対応** - ネットワークなしでも完全動作
- 📋 **Mail.app互換** - おなじみのキーボードショートカット（⌘N、⌘R、⌘D）
- 📋 **プライバシー第一** - トラッキングなし、分析なし、テレメトリなし

### SwiftMailがやらないこと
- ❌ カレンダー統合
- ❌ タスク管理
- ❌ RSSフィード
- ❌ チャット機能
- ❌ プラグイン・テーマ
- ❌ AI・スマート機能
- ❌ SNS連携

**これは意図的です。** メールはメールであるべきです。

## 🖼️ デザインモックアップ

<div align="center">
  <img src="assets/mockup-main.png" alt="SwiftMail Design Mockup" width="800">
  <p><em>目標UI：クリーンで集中できる、余計なものがないインターフェース</em></p>
</div>

## 🚀 はじめ方（開発者向け）

### システム要件
- macOS 12.0（Monterey）以降
- Xcode 15.0以上
- メモリ 2GB以上
- ディスク容量 100MB

### ソースからビルド

```bash
# リポジトリをクローン
git clone https://github.com/yourusername/SwiftMail.git
cd SwiftMail

# Xcodeで開く
open SwiftMail.xcodeproj

# ビルドして実行（⌘R）
# 注意：現在のビルドはプレアルファ版で、完全に動作しない可能性があります
```

**重要**: SwiftMailは外部依存ゼロです。CocoaPods、Carthage、Swift Package Managerの依存関係は一切ありません。純粋なSwiftとmacOSフレームワークのみ。

## 🏗️ アーキテクチャ

```
SwiftMail/
├── Core/
│   ├── Database/      # SQLite3直接操作（CoreDataなし）
│   ├── Networking/    # IMAP/POP3/SMTP（開発中）
│   └── Models/        # Swift構造体
├── UI/
│   ├── Controllers/   # 最小限のViewController
│   └── Views/         # AppKitビュー
└── Resources/
    └── Assets/        # アイコンと画像
```

### 技術スタック
- **言語**: Swift 5.9
- **UI**: AppKit（Catalyst、SwiftUIは使用しない）
- **データベース**: SQLite3 C API（ラッパーなし）
- **セキュリティ**: macOS Keychain
- **HTML表示**: WebKit（JavaScript無効）

## 📊 パフォーマンス目標

達成を目指す性能指標：

| 指標 | SwiftMail（目標） | Thunderbird | Mail.app |
|-----|-----------------|-------------|----------|
| 起動時間 | < 1秒 | 約5秒 | 約2秒 |
| メモリ（待機時） | < 50MB | 350MB | 180MB |
| メモリ（1000通） | < 100MB | 520MB | 280MB |
| 検索（10000通） | < 10ms | 150ms | 50ms |

*競合製品の測定値：MacBook Air M1、RAM 8GBでの実測*

## 🛠️ 開発について

### 前提条件
- Xcode 15.0以上
- macOS 12.0以上の開発機
- Apple Developer アカウント（署名用）

### 開発哲学
```swift
// ❌ ダメな例
import SomeThirdPartyLibrary
class ComplexFeatureViewController: NSViewController {
    // 500行以上のコード
}

// ✅ 良い例
import Foundation
class MailListViewController: NSViewController {
    // 単一責任、200行以下
}
```

### 開発ガイド
詳細な開発ガイドライン、コーディング規約、アーキテクチャの決定事項は[claude.md](claude.md)を参照してください。

## 🤝 コントリビューション

ミニマリスト哲学に賛同いただける方の貢献を歓迎します！

### 貢献方法
1. **開始前に**: [claude.md](claude.md)で厳格なガイドラインを理解してください
2. **フォーク**する
3. **フィーチャーブランチ**を作成（`git checkout -b feature/amazing-feature`）
4. **コミット**（`git commit -m 'Add amazing feature'`）
5. **プッシュ**（`git push origin feature/amazing-feature`）
6. **Pull Request**を作成

### コントリビューションルール
- ✅ **パフォーマンス改善** - 常に歓迎
- ✅ **バグ修正** - 常に歓迎
- ✅ **セキュリティ強化** - 常に歓迎
- ⚠️ **新機能** - 事前に十分な議論が必要
- ❌ **外部依存** - 却下されます
- ❌ **機能の肥大化** - 却下されます

貢献いただいたコードは Apache License 2.0 でライセンスされることに同意いただきます。

詳細は[CONTRIBUTING.md](CONTRIBUTING.md)を参照してください。

## 📝 開発ロードマップ

### フェーズ1: 基盤（進行中）🚧
- [x] アーキテクチャ設計
- [x] 開発ガイドライン（claude.md）
- [ ] SQLiteデータベース層
- [ ] 基本UI構造
- [ ] アカウント管理モデル

### フェーズ2: コアメール機能
- [ ] IMAP実装
- [ ] POP3実装
- [ ] メッセージパーサー（RFC822）
- [ ] メッセージ表示
- [ ] 作成と送信

### フェーズ3: 必須機能
- [ ] ローカル検索（FTS5）
- [ ] キーボードショートカット
- [ ] 複数アカウント
- [ ] オフライン対応
- [ ] 添付ファイル処理

### フェーズ4: 品質向上
- [ ] パフォーマンス最適化
- [ ] メモリ最適化
- [ ] アクセシビリティ（VoiceOver）
- [ ] エラー処理
- [ ] 自動更新機能

### フェーズ5: リリース
- [ ] テストとバグ修正
- [ ] ドキュメント整備
- [ ] App Store申請
- [ ] ウェブサイト公開

### 実装しないもの（永遠に）
- カレンダー統合
- タスク管理
- プラグイン・拡張機能
- システムのダーク/ライト以外のテーマ
- AI・機械学習機能
- SNS連携

## 📄 ライセンス

SwiftMailはApache License 2.0でリリースされています。詳細は[LICENSE](LICENSE)ファイルを参照してください。

### なぜApache 2.0？
- **特許保護**: 利用者と貢献者を特許訴訟から保護
- **企業フレンドリー**: 法的条項が明確で企業環境で広く受け入れられている
- **App Store対応**: Mac App Storeでの配布に問題なし
- **貢献者保護**: 保証や責任に関する請求から貢献者を保護
- **Swiftとの互換性**: Apple自身もSwiftにApache 2.0を採用

つまり、以下のことが可能です：
- ✅ 商用利用
- ✅ 改変・配布
- ✅ プロプライエタリなフォーク作成
- ✅ クローズドソースプロジェクトへの組み込み
- ⚠️ オリジナルのライセンスと通知の保持が必要
- ⚠️ 重要な変更を行った場合は明記が必要

## 🙏 開発の動機

現代のメールクライアントは道を見失っています。肥大化し、遅く、複雑になりすぎました：

- **Thunderbird** - メールを読むだけで350MB以上のメモリを使用
- **Outlook** - カレンダー、タスク、Teams等を詰め込み過ぎ
- **Mail.app** - 悪くないが、もっと速く軽くできるはず

**SwiftMailのビジョン**は違います：
- 目標：1000通のメールを読み込んでも100MB以下
- 目標：1秒以下で起動
- 焦点：メールだけ。ただし完璧に。

## 💬 サポートとコミュニティ

- **Issues**: [GitHub Issues](https://github.com/yourusername/SwiftMail/issues)
- **議論**: [GitHub Discussions](https://github.com/yourusername/SwiftMail/discussions)
- **開発チャット**: 準備中
- **セキュリティ**: 脆弱性はGitHub Securityタブから報告

## 🌟 なぜSwiftMail？

私たちが信じるメールクライアントの姿：
- **高速** - 瞬時に起動、瞬時に検索
- **集中** - メールだけ、邪魔なものなし
- **敬意** - システムリソースとプライバシーを尊重

このビジョンに共感いただけるなら、ぜひ一緒に実現させましょう。

---

<div align="center">
  <b>より良いメールクライアントを一緒に作りましょう。</b>
  
  <br><br>
  
  ⭐ このリポジトリにスターを付けて進捗をフォロー<br>
  👁️ Watchして更新情報を受け取る<br>
  🔨 コントリビュートして実現に協力する
  
  <br><br>
  
  <sub>Thunderbirdが重すぎると感じているすべての人へ</sub>
</div>