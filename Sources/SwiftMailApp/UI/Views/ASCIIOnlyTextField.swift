import AppKit

/// 半角英数字専用テキストフィールド（メールアドレス、サーバー名等）
/// フォーカス時に自動的に英数入力モードに切り替わる
public final class ASCIIOnlyTextField: NSTextField {

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Cmd+C (Copy), Cmd+V (Paste), Cmd+X (Cut), Cmd+A (Select All) を許可
        if event.modifierFlags.contains(.command) {
            if let characters = event.charactersIgnoringModifiers {
                if characters == "c" || characters == "v" || characters == "x" || characters == "a" {
                    return super.performKeyEquivalent(with: event)
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    public override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        // コピー、ペースト、カット、全選択メニューを有効化
        if let action = item.action {
            if action == #selector(NSText.copy(_:)) ||
               action == #selector(NSText.paste(_:)) ||
               action == #selector(NSText.cut(_:)) ||
               action == #selector(NSText.selectAll(_:)) {
                return true
            }
        }
        return super.validateUserInterfaceItem(item)
    }

    public override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            // 日本語入力を無効化（英数字入力のみ）
            NSTextInputContext.current?.discardMarkedText()
        }
        return result
    }
}
