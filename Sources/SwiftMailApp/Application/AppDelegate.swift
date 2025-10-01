import AppKit
import SwiftMailCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?
    private var environment: AppEnvironment?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()

        do {
            let environment = try AppEnvironment.bootstrap()
            self.environment = environment

            let windowController = MainWindowController(environment: environment)
            windowController.showWindow(self)
            self.windowController = windowController
        } catch {
            presentFatalError(error)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment?.database.close()
    }

    private func presentFatalError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "アプリケーションを初期化できません"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.addButton(withTitle: "終了")
        alert.runModal()
        NSApplication.shared.terminate(self)
    }

    // MARK: - Menu Setup

    private func setupMenuBar() {
        let mainMenu = NSMenu()

        // SwiftMailメニュー（アプリケーションメニュー）
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu

        appMenu.addItem(withTitle: "SwiftMailについて", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())

        // 設定
        let preferencesItem = appMenu.addItem(withTitle: "設定...", action: #selector(showPreferences), keyEquivalent: ",")
        preferencesItem.target = self

        appMenu.addItem(NSMenuItem.separator())

        // サービス
        let servicesItem = NSMenuItem(title: "サービス", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu()
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        NSApp.servicesMenu = servicesMenu

        appMenu.addItem(NSMenuItem.separator())

        // SwiftMailを隠す
        appMenu.addItem(withTitle: "SwiftMailを隠す", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")

        // 他を隠す
        let hideOthersItem = appMenu.addItem(withTitle: "他を隠す", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]

        // すべてを表示
        appMenu.addItem(withTitle: "すべてを表示", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")

        appMenu.addItem(NSMenuItem.separator())

        // SwiftMailを終了
        appMenu.addItem(withTitle: "SwiftMailを終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        mainMenu.addItem(appMenuItem)

        // ファイルメニュー
        let fileMenu = NSMenu(title: "ファイル")
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu

        fileMenu.addItem(withTitle: "新規メッセージ", action: #selector(newMessage), keyEquivalent: "n")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "ウインドウを閉じる", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        mainMenu.addItem(fileMenuItem)

        // 編集メニュー
        let editMenu = NSMenu(title: "編集")
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu

        editMenu.addItem(withTitle: "取り消す", action: #selector(UndoManager.undo), keyEquivalent: "z")
        editMenu.addItem(withTitle: "やり直す", action: #selector(UndoManager.redo), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "カット", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "コピー", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "ペースト", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "削除", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: "すべてを選択", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        mainMenu.addItem(editMenuItem)

        // 表示メニュー
        let viewMenu = NSMenu(title: "表示")
        let viewMenuItem = NSMenuItem()
        viewMenuItem.submenu = viewMenu

        // ツールバー項目
        viewMenu.addItem(withTitle: "ツールバーをカスタマイズ...", action: #selector(NSWindow.runToolbarCustomizationPalette(_:)), keyEquivalent: "")

        mainMenu.addItem(viewMenuItem)

        // ウインドウメニュー
        let windowMenu = NSMenu(title: "ウインドウ")
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu

        windowMenu.addItem(withTitle: "しまう", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "拡大/縮小", action: #selector(NSWindow.zoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "すべてを手前に移動", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")

        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        // ヘルプメニュー
        let helpMenu = NSMenu(title: "ヘルプ")
        let helpMenuItem = NSMenuItem()
        helpMenuItem.submenu = helpMenu

        helpMenu.addItem(withTitle: "SwiftMailヘルプ", action: #selector(showHelp), keyEquivalent: "?")

        mainMenu.addItem(helpMenuItem)
        NSApp.helpMenu = helpMenu

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Menu Actions

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "SwiftMail",
            .applicationVersion: "0.1.0",
            .version: "プレアルファ版",
            .credits: NSAttributedString(string: "超軽量・超高速なmacOS用メールクライアント")
        ])
    }

    @objc private func showPreferences() {
        // TODO: 設定画面実装
        let alert = NSAlert()
        alert.messageText = "設定"
        alert.informativeText = "設定画面は実装予定です"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func newMessage() {
        // メインウィンドウのメール作成ボタンと同じ動作
        windowController?.showComposeWindow()
    }

    @objc private func showHelp() {
        // TODO: ヘルプ表示実装
        if let url = URL(string: "https://github.com/ayumuwall/SwiftMail") {
            NSWorkspace.shared.open(url)
        }
    }
}
