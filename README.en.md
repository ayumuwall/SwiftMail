# SwiftMail

> **Lightning-fast, featherweight email client for macOS (pre-alpha)**

**English** | [日本語](README.md)

---

## 📑 Table of Contents

- [What is this?](#what-is-this)
- [Design Mockup](#️-design-mockup)
- [Why We Built This](#-why-we-built-this)
- [Getting Started (Developers)](#-getting-started-developers)
  - [Requirements](#requirements)
  - [Build from Source](#build-from-source)
- [Architecture](#️-architecture)
- [What's Currently Implemented](#-whats-currently-implemented)
  - [Tech Stack](#tech-stack)
  - [UI Philosophy (LLM-Optimized)](#ui-philosophy-llm-optimized)
- [Performance Goals](#-performance-goals)
- [Development](#️-development)
  - [Development Philosophy](#development-philosophy)
  - [Development Guide](#development-guide)
- [Contributing](#-contributing)
  - [Contribution Rules](#contribution-rules)
- [Roadmap](#-roadmap)
- [License](#-license)
- [Support & Community](#-support--community)
- [Why SwiftMail?](#-why-swiftmail)

---

## What is this?

SwiftMail is a macOS-only email client laser-focused on **speed, simplicity, and minimalism**. Modern email apps have become bloated with features. SwiftMail takes a different approach: **email should do email, and nothing else**.

### What SwiftMail Does
- 📋 **Blazing fast** - Goals: <1s launch, 10ms search across 10,000 emails
- 📋 **POP3/IMAP support** - Pure Swift implementation, zero external libraries
- 📋 **Security-first** - Keychain integration, TLS 1.2+, JavaScript disabled
- 📋 **Offline-ready** - Full functionality without network
- 📋 **Mail.app compatible** - Familiar keyboard shortcuts (⌘N, ⌘R, ⌘D)
- 📋 **Privacy-focused** - No tracking, no analytics, no telemetry

### What SwiftMail Doesn't Do
- ❌ Calendar integration
- ❌ Task management
- ❌ RSS feeds
- ❌ Chat features
- ❌ Plugins & themes
- ❌ AI & smart features
- ❌ Social media integration

**This is intentional.** Email should be email.

## 🖼️ Design Mockup

<div align="center">
  <img src="assets/mockup-main.png" alt="SwiftMail Design Mockup" width="800">
  <p><em>Target UI: Clean, focused, zero distractions</em></p>
</div>

## 🙏 Why We Built This

Modern email clients have lost their way. They're bloated, slow, and overcomplicated:

- **Thunderbird** - Uses 350MB+ of RAM just to read email
- **Outlook** - Crammed with calendars, tasks, Teams, and everything else
- **Mail.app** - Not bad, but we can do better

**SwiftMail's vision is different:**
- Target: <100MB RAM even with 1,000 emails loaded
- Target: <1s startup time
- Focus: Email only. But do it perfectly.

## 🚀 Getting Started (Developers)

### Requirements
- macOS 12.0 (Monterey) or later
- Xcode 15.0+
- 2GB+ RAM
- 100MB disk space

### Build from Source

```bash
# Clone the repo
git clone https://github.com/ayumuwall/SwiftMail.git
cd SwiftMail

# Build/test with SwiftPM
swift build
swift test

# Open in Xcode
open Package.swift

# Note: The AppKit app is currently pre-alpha with placeholder UI
```

**Important**: SwiftMail has **zero external dependencies**. We use Swift Package Manager (SPM) as our build system, but we don't add any external packages. No CocoaPods, no Carthage, no third-party libraries. Just pure Swift and macOS system frameworks (Foundation/AppKit/Security).

## 🏗️ Architecture

```
SwiftMail/
├── Package.swift              # Multi-target configuration (SwiftPM)
├── Sources/
│   ├── SwiftMailCore/         # Domain models/protocols/policies
│   ├── SwiftMailDatabase/     # SQLite3 C API wrapper & repository
│   └── SwiftMailApp/          # AppKit entry point & UI layer
└── Tests/
    ├── SwiftMailCoreTests/    # Model tests
    └── SwiftMailDatabaseTests/# Data layer tests
```

## 🧱 What's Currently Implemented
- **Domain layer**: Account/Message/Attachment/Folder models with retry policies
- **Database layer**: Direct SQLite3 access via `MailDatabase` and `SQLiteMailRepository`. Supports WAL, FTS5, and attachment BLOB management
- **UI layer**: AppKit three-pane layout (folders/message list/detail) with repository integration and placeholder display
- **Unit tests**: Basic scenarios covering core models and database initialization

### Tech Stack
- **Language**: Swift 6.2
- **UI**: AppKit programmatic UI (100% Swift code, no XIB/Storyboard/SwiftUI/Catalyst)
- **Database**: SQLite3 C API (no wrapper)
- **Security**: macOS Keychain
- **HTML rendering**: WebKit (JavaScript disabled)

### UI Philosophy (LLM-Optimized)

SwiftMail uses **AppKit programmatic UI**, with all UI written in Swift code.

#### Why Programmatic UI?

| Approach | Used? | Performance | LLM Development | Reason |
|---------|-------|-------------|-----------------|--------|
| **AppKit (Code)** | ✅ | ⚡️⚡️⚡️ Fastest | 🤖🤖🤖 Optimal | All code in .swift files, LLM fully understands |
| SwiftUI | ❌ | 🐢 Slow | 🤖🤖 Good | Runtime overhead, increased memory |
| XIB/Storyboard | ❌ | 🐌 Slow launch | ❌ Can't edit | Binary files, LLM can't parse |
| Catalyst | ❌ | 🐌 Degraded | 🤖 Possible | Don't need iOS compatibility layer |

**Programmatic UI example**:
```swift
// ✅ SwiftMail implementation style
final class MessageListViewController: NSViewController {
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()

    override func viewDidLoad() {
        super.viewDidLoad()
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

**Benefits for LLM development**:
- ✅ All UI code self-contained in .swift files
- ✅ LLM can grasp full context
- ✅ Clear version control diffs
- ✅ Zero XIB/Storyboard load time (faster startup)
- ✅ No SwiftUI abstraction layer (reduced memory)

## 📊 Performance Goals

Target metrics we're aiming for:

| Metric | SwiftMail (Target) | Thunderbird | Mail.app |
|--------|-------------------|-------------|----------|
| Launch time | < 1s | ~5s | ~2s |
| Memory (idle) | < 50MB | 350MB | 180MB |
| Memory (1000 emails) | < 100MB | 520MB | 280MB |
| Search (10000 emails) | < 10ms | 150ms | 50ms |

*Competitor measurements: Tested on MacBook Air M1, 8GB RAM*

## 🛠️ Development

### Prerequisites
- Xcode 15.0+
- macOS 12.0+ development machine
- Apple Developer account (for signing)

### Development Philosophy
```swift
// ❌ Bad example
import SomeThirdPartyLibrary
class ComplexFeatureViewController: NSViewController {
    // 500+ lines of code
}

// ✅ Good example
import Foundation
class MailListViewController: NSViewController {
    // Single responsibility, <200 lines
}
```

### Development Guide
For detailed development guidelines, coding conventions, and architectural decisions, see [AGENTS.md](AGENTS.md).

## 🤝 Contributing

We welcome contributions from anyone who shares our minimalist philosophy!

### How to Contribute
1. **Before starting**: Read [AGENTS.md](AGENTS.md) to understand our strict guidelines
2. **Fork** the repository
3. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
4. **Commit** your changes (`git commit -m 'Add amazing feature'`)
5. **Push** to the branch (`git push origin feature/amazing-feature`)
6. **Open a Pull Request**

### Contribution Rules
- ✅ **Performance improvements** - Always welcome
- ✅ **Bug fixes** - Always welcome
- ✅ **Security enhancements** - Always welcome
- ⚠️ **New features** - Requires thorough discussion first
- ❌ **External dependencies** - Will be rejected
- ❌ **Feature bloat** - Will be rejected

By contributing code, you agree it will be licensed under Apache License 2.0.

See [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

## 📝 Roadmap

### Phase 1: Foundation (In Progress) 🚧
- [x] Architecture design
- [x] Development guidelines (AGENTS.md)
- [x] SQLite database layer (PRAGMA optimizations & FTS)
- [x] Basic UI structure (AppKit three-pane skeleton)
- [x] Account management model

### Phase 2: Core Email Features
- [ ] IMAP implementation
- [ ] POP3 implementation
- [ ] Message parser (RFC822)
- [ ] Message display
- [ ] Compose & send

### Phase 3: Essential Features
- [ ] Local search (FTS5)
- [ ] Keyboard shortcuts
- [ ] Multiple accounts
- [ ] Offline mode
- [ ] Attachment handling

### Phase 4: Polish
- [ ] Performance optimization
- [ ] Memory optimization
- [ ] Accessibility (VoiceOver)
- [ ] Error handling
- [ ] Auto-update mechanism

### Phase 5: Release
- [ ] Testing & bug fixes
- [ ] Documentation
- [ ] App Store submission
- [ ] Website launch

### What We'll Never Implement
- Calendar integration
- Task management
- Plugins & extensions
- Themes (beyond system dark/light)
- AI & machine learning features
- Social media integration

## 📄 License

SwiftMail is released under the Apache License 2.0. See [LICENSE](LICENSE) for details.

### Why Apache 2.0?
- **Patent protection**: Protects users and contributors from patent lawsuits
- **Enterprise-friendly**: Clear legal terms, widely accepted in corporate environments
- **App Store compatible**: No issues distributing on Mac App Store
- **Contributor protection**: Shields contributors from warranty/liability claims
- **Swift compatibility**: Apple uses Apache 2.0 for Swift itself

This means you can:
- ✅ Use commercially
- ✅ Modify & distribute
- ✅ Create proprietary forks
- ✅ Embed in closed-source projects
- ⚠️ Must preserve original license & notices
- ⚠️ Must state significant changes

## 💬 Support & Community

- **Issues**: [GitHub Issues](https://github.com/ayumuwall/SwiftMail/issues)
- **Discussions**: [GitHub Discussions](https://github.com/ayumuwall/SwiftMail/discussions)
- **Dev Chat**: Coming soon
- **Security**: Report vulnerabilities via GitHub Security tab

## 🌟 Why SwiftMail?

What we believe an email client should be:
- **Fast** - Instant launch, instant search
- **Focused** - Just email, no distractions
- **Respectful** - Of your system resources and privacy

If this vision resonates with you, let's build it together.
