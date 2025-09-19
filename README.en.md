# SwiftMail

<div align="center">
  <img src="assets/icon.png" alt="SwiftMail Icon" width="128" height="128">
  
  **A minimalist email client for macOS (in development)**
  
  [![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
  [![macOS](https://img.shields.io/badge/macOS-12.0+-blue.svg)](https://www.apple.com/macos)
  [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
  [![Status](https://img.shields.io/badge/Status-Pre--Alpha-red.svg)](https://github.com/yourusername/SwiftMail)
  [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
</div>

---

## 🚧 Development Status

**SwiftMail is currently in early development.** The foundation is being built with a focus on performance and minimalism from day one.

### Current Progress
- ✅ Architecture design complete
- ✅ Development guidelines established
- 🚧 Database layer implementation (SQLite3)
- 🚧 Basic UI framework
- ⏳ IMAP/POP3 protocols
- ⏳ Core functionality

## 🎯 Philosophy & Goals

**Minimalism First** - SwiftMail aims to be the antithesis of bloated email clients. While others add features, we will perfect the essentials.

### Performance Targets
- **< 1 second** startup time
- **< 100MB** memory footprint  
- **< 10ms** search response (10,000 emails)
- **Zero external dependencies**
- **100% native macOS experience**

## ✨ Planned Features

### What SwiftMail Will Do
- 📋 **Lightning Fast Performance** - Target: Boot in under 1 second, search 10,000 emails in 10ms
- 📋 **POP3/IMAP Support** - Full protocol implementation without external libraries
- 📋 **Security First** - Keychain integration, TLS 1.2+, sandboxed JavaScript
- 📋 **Offline Capable** - Full functionality without network connection
- 📋 **Mail.app Compatibility** - Familiar keyboard shortcuts (⌘N, ⌘R, ⌘D)
- 📋 **Privacy Focused** - No tracking, no analytics, no telemetry

### What SwiftMail Won't Do
- ❌ No calendar integration
- ❌ No task management  
- ❌ No RSS feeds
- ❌ No chat features
- ❌ No plugins or themes
- ❌ No AI/smart features
- ❌ No social media

**This is intentional.** Email should be email.

## 🖼️ Design Mockups

<div align="center">
  <img src="assets/mockup-main.png" alt="SwiftMail Design Mockup" width="800">
  <p><em>Target UI: Clean, focused, distraction-free interface</em></p>
</div>

## 🚀 Getting Started (For Developers)

### System Requirements
- macOS 12.0 (Monterey) or later
- Xcode 15.0+
- 2GB RAM minimum
- 100MB disk space

### Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/SwiftMail.git
cd SwiftMail

# Open in Xcode
open SwiftMail.xcodeproj

# Build and run (⌘R)
# Note: Current build is pre-alpha and may not be fully functional
```

**Note**: SwiftMail uses zero external dependencies. No CocoaPods, no Carthage, no Swift Package Manager dependencies. Just pure Swift and macOS frameworks.

## 🏗️ Architecture

```
SwiftMail/
├── Core/
│   ├── Database/      # SQLite3 direct (no CoreData)
│   ├── Networking/    # IMAP/POP3/SMTP (in development)
│   └── Models/        # Swift structs
├── UI/
│   ├── Controllers/   # Minimal ViewControllers
│   └── Views/         # AppKit views
└── Resources/
    └── Assets/        # Icons and images
```

### Technology Stack
- **Language**: Swift 5.9
- **UI**: AppKit (no Catalyst, no SwiftUI)
- **Database**: SQLite3 C API (no wrappers)
- **Security**: macOS Keychain
- **HTML Rendering**: WebKit (JavaScript disabled)

## 📊 Performance Goals

Target performance metrics (to be achieved):

| Metric | SwiftMail (Target) | Thunderbird | Mail.app |
|--------|-------------------|-------------|----------|
| Startup Time | < 1s | ~5s | ~2s |
| Memory (idle) | < 50MB | 350MB | 180MB |
| Memory (1000 emails) | < 100MB | 520MB | 280MB |
| Search 10k emails | < 10ms | 150ms | 50ms |

*Competitive measurements taken on MacBook Air M1, 8GB RAM*

## 🛠️ Development

### Prerequisites
- Xcode 15.0+
- macOS 12.0+ development machine
- Apple Developer account (for signing)

### Development Philosophy
```swift
// ❌ Don't do this
import SomeThirdPartyLibrary
class ComplexFeatureViewController: NSViewController {
    // 500+ lines of code
}

// ✅ Do this
import Foundation
class MailListViewController: NSViewController {
    // Single responsibility, < 200 lines
}
```

### Development Guide
See [claude.md](claude.md) for detailed development guidelines, coding standards, and architectural decisions.

## 🤝 Contributing

We welcome contributions that align with our minimalist philosophy!

### How to Contribute
1. **Before starting**: Read [claude.md](claude.md) to understand our strict guidelines
2. **Fork** the repository
3. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
4. **Commit** your changes (`git commit -m 'Add amazing feature'`)
5. **Push** to the branch (`git push origin feature/amazing-feature`)
6. **Open** a Pull Request

### Contribution Rules
- ✅ **Performance improvements** always welcome
- ✅ **Bug fixes** always welcome
- ✅ **Security enhancements** always welcome
- ⚠️ **New features** require extensive discussion
- ❌ **External dependencies** will be rejected
- ❌ **Feature creep** will be rejected

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## 📝 Development Roadmap

### Phase 1: Foundation (In Progress) 🚧
- [x] Architecture design
- [x] Development guidelines (claude.md)
- [ ] SQLite database layer
- [ ] Basic UI structure
- [ ] Account management models

### Phase 2: Core Email
- [ ] IMAP implementation
- [ ] POP3 implementation  
- [ ] Message parser (RFC822)
- [ ] Message viewing
- [ ] Compose and send

### Phase 3: Essential Features
- [ ] Local search (FTS5)
- [ ] Keyboard shortcuts
- [ ] Multiple accounts
- [ ] Offline support
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

### Non-Goals (Will Never Implement)
- Calendar integration
- Task management
- Plugins/Extensions
- Themes beyond system dark/light
- AI/ML features
- Social media integration

## 📄 License

SwiftMail is released under the MIT License. See [LICENSE](LICENSE) file for details.

## 🙏 Motivation

Modern email clients have lost their way. They've become bloated, slow, and complicated:

- **Thunderbird** uses 350MB+ RAM just to read email
- **Outlook** bundles calendar, tasks, teams, and more
- **Mail.app** is decent but could be faster and lighter

**SwiftMail's vision** is different:
- Target: Use < 100MB RAM with 1000 emails loaded
- Target: Boot in under 1 second
- Focus: Do email. Just email. Perfectly.

## 💬 Support & Community

- **Issues**: [GitHub Issues](https://github.com/yourusername/SwiftMail/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/SwiftMail/discussions)
- **Development Chat**: Coming soon
- **Security**: Report vulnerabilities via GitHub Security tab

## 🌟 Why SwiftMail?

We believe email clients should be:
- **Fast** - Instant startup, instant search
- **Focused** - Email only, no distractions
- **Respectful** - Of your system resources and privacy

If you share this vision, we'd love your help making it reality.

---

<div align="center">
  <b>Join us in building a better email client.</b>
  
  <br><br>
  
  ⭐ Star this repo to follow our progress<br>
  👁️ Watch for updates<br>
  🔨 Contribute to make it happen
</div>