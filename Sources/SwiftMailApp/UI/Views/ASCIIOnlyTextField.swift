import AppKit

/// 半角英数字専用テキストフィールド（メールアドレス、サーバー名等）
/// フォーカス時に自動的に英数入力モードに切り替わる
public final class ASCIIOnlyTextField: NSTextField {

    public override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            // フォーカス時に日本語入力をリセット
            DispatchQueue.main.async { [weak self] in
                self?.currentEditor()?.inputContext?.invalidateCharacterCoordinates()
            }
        }
        return result
    }

    public override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        // 編集開始時にも日本語入力をリセット
        currentEditor()?.inputContext?.invalidateCharacterCoordinates()
    }
}
