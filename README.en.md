# SwiftMail

<!-- バッジ: 必要に応じてワークフロー/ブランチを調整してください -->

<p align="center">
  <!-- Build (GitHub Actions) -->
  <a href="https://github.com/ayumuwall/SwiftMail/actions/workflows/ci.yml">
    <img alt="Build"
         src="https://img.shields.io/github/actions/workflow/status/ayumuwall/SwiftMail/ci.yml?label=Build&logo=githubactions&logoColor=white&branch=main">
  </a>

  <!-- License -->

  <a href="https://github.com/ayumuwall/SwiftMail/blob/main/LICENSE">
    <img alt="License" src="https://img.shields.io/github/license/ayumuwall/SwiftMail?label=License">
  </a>

  <!-- Project status -->

  <img alt="Status" src="https://img.shields.io/badge/status-pre--alpha-orange">

  <!-- Platform / Swift -->

  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS-informational?logo=apple">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.10%2B-F05138?logo=swift&logoColor=white">

  <!-- Issues / PRs -->

  <a href="https://github.com/ayumuwall/SwiftMail/issues">
    <img alt="Issues" src="https://img.shields.io/github/issues/ayumuwall/SwiftMail?label=Issues">
  </a>
  <a href="https://github.com/ayumuwall/SwiftMail/pulls">
    <img alt="PRs Welcome" src="https://img.shields.io/badge/PRs-welcome-brightgreen?logo=github">
  </a>

  <!-- Code style: 既定は SwiftLint。SwiftFormat を使う場合は下を有効化して上を削除 -->

  <img alt="Code Style: SwiftLint" src="https://img.shields.io/badge/code%20style-SwiftLint-4B32C3">
  <!-- <img alt="Code Style: SwiftFormat" src="https://img.shields.io/badge/code%20style-SwiftFormat-1A7FD4"> -->

  <!-- Optional: Coverage (Codecov を使う場合のみ) -->

  <!-- <a href="https://codecov.io/gh/ayumuwall/SwiftMail">
        <img alt="Coverage" src="https://img.shields.io/codecov/c/gh/ayumuwall/SwiftMail?label=coverage&logo=codecov">
       </a> -->

  <!-- Optional: Releases / Downloads -->

  <a href="https://github.com/ayumuwall/SwiftMail/releases">
    <img alt="Release" src="https://img.shields.io/github/v/release/ayumuwall/SwiftMail?include_prereleases&label=Release">
  </a>
  <!-- <img alt="Downloads" src="https://img.shields.io/github/downloads/ayumuwall/SwiftMail/total?label=Downloads"> -->
</p>

<!-- Badges: replace workflow file/branch if needed -->

<p align="center">
  <!-- Build (GitHub Actions) -->
  <a href="https://github.com/ayumuwall/SwiftMail/actions/workflows/ci.yml">
    <img alt="Build"
         src="https://img.shields.io/github/actions/workflow/status/ayumuwall/SwiftMail/ci.yml?label=Build&logo=githubactions&logoColor=white&branch=main">
  </a>

  <!-- License -->

  <a href="https://github.com/ayumuwall/SwiftMail/blob/main/LICENSE">
    <img alt="License" src="https://img.shields.io/github/license/ayumuwall/SwiftMail?label=License">
  </a>

  <!-- Project status -->

  <img alt="Status" src="https://img.shields.io/badge/status-pre--alpha-orange">

  <!-- Platform / Swift -->

  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS-informational?logo=apple">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.10%2B-F05138?logo=swift&logoColor=white">

  <!-- Issues / PRs -->

  <a href="https://github.com/ayumuwall/SwiftMail/issues">
    <img alt="Issues" src="https://img.shields.io/github/issues/ayumuwall/SwiftMail?label=Issues">
  </a>
  <a href="https://github.com/ayumuwall/SwiftMail/pulls">
    <img alt="PRs Welcome" src="https://img.shields.io/badge/PRs-welcome-brightgreen?logo=github">
  </a>

  <!-- Code style: SwiftLint by default; switch to SwiftFormat if preferred -->

  <img alt="Code Style: SwiftLint" src="https://img.shields.io/badge/code%20style-SwiftLint-4B32C3">
  <!-- <img alt="Code Style: SwiftFormat" src="https://img.shields.io/badge/code%20style-SwiftFormat-1A7FD4"> -->

  <!-- Optional: Coverage (enable if using Codecov) -->

  <!-- <a href="https://codecov.io/gh/ayumuwall/SwiftMail">
        <img alt="Coverage" src="https://img.shields.io/codecov/c/gh/ayumuwall/SwiftMail?label=coverage&logo=codecov">
       </a> -->

  <!-- Optional: Releases / Downloads -->

  <a href="https://github.com/ayumuwall/SwiftMail/releases">
    <img alt="Release" src="https://img.shields.io/github/v/release/ayumuwall/SwiftMail?include_prereleases&label=Release">
  </a>
  <!-- <img alt="Downloads" src="https://img.shields.io/github/downloads/ayumuwall/SwiftMail/total?label=Downloads"> -->
</p>

> **An ultra‑light, ultra‑fast email client for macOS (pre‑alpha)**

**English** | [日本語](README.ja.md)

---

## What is this?

SwiftMail is a macOS‑only email client built with a single goal: **be fast, light, and simple**. Many modern mail apps feel heavy because they try to do everything. SwiftMail focuses on one thing—**email**—and removes the rest so you can get in, read, reply, and move on.

* **Who it's for:** People who value speed and a clean, native experience over extra features
* **OS support:** macOS 12 or later (planned)
* **Status:** Pre‑alpha (foundation and UI scaffolding in progress)

---

## Why build it? (The experience we aim for)

* **Instant launch**: Targeting under 1 second to open and ready to use
* **Low memory usage**: Aiming for < 100 MB in normal use
* **Fast search**: Snappy local search across thousands of messages
* **Native feel**: 100% macOS UI (AppKit), keyboard‑first
* **Privacy‑first**: No telemetry or tracking. JavaScript in HTML mail disabled by default

> **Philosophy:** Add by **subtracting**. We protect speed and clarity by saying no to features that aren't core to email.

---

## What SwiftMail **will** do (includes planned work)

* POP3 / IMAP / SMTP basics (with local cache & offline behavior)
* Message list & detail views (plain text first; safe HTML rendering)
* Simple local search (fast full‑text)
* Familiar shortcuts similar to Apple Mail

## What SwiftMail **won't** do (on purpose)

No calendar, tasks, RSS, chat, plug‑ins/themes, AI auto‑categorization, or social integrations—**anything that drifts from the core of email is out of scope**.

---

## Current progress

* ✅ App skeleton and three‑pane UI scaffold
* ✅ Design principles & contributor guidelines
* 🚧 Database layer (SQLite3) and repository implementation
* 🚧 Protocol layer groundwork (IMAP / POP3 / SMTP)

> Pre‑alpha means we aren't distributing builds yet. You can follow along on GitHub.

---

## How it's fast (gentle technical notes)

* **Minimal dependencies**: Pure Swift with macOS system frameworks
* **Direct SQLite3**: Lightweight local storage for speed
* **Simple UI**: Minimal rendering, optimized interactions
* **Safe HTML**: JavaScript disabled and trackers reduced by default

---

## Who will like it

* You want **speed** and **quiet** in your email app
* You prefer a **just‑email** workflow without extra integrations
* You enjoy a native macOS look & feel

---

## Screenshots (work in progress)

> UI is under active development and may change.

<p align="center">
  <img src="assets/mockup-main.png" alt="SwiftMail Mockup" width="800" />
</p>

---

## FAQ

**Why no calendar or tasks?**

Because other apps do those well already. By focusing on reading and composing email, SwiftMail stays fast and light.

**Do you collect telemetry or track usage?**

No. We don't collect behavioral data. JavaScript in HTML emails is disabled by default.

**When can I try it?**

We're still in pre‑alpha. Please star or watch the repo to follow progress.

---

## Contribute & follow

* Report bugs and feature requests: [GitHub Issues](../../issues)
* Propose ideas and discuss: [GitHub Discussions](../../discussions)
* Security: use the Security tab on GitHub

> ⚠️ For build steps, coding conventions, and deeper technical details, see **AGENTS.md** (developer‑focused).

---

## License

Released under the **Apache License 2.0**. See [LICENSE](LICENSE) for details.

---

### Credits

Thanks to the Swift and macOS communities. Let's grow a better email experience—focused, fast, and respectful of your attention.
