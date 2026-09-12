// ホットキー録音コントロール（SwiftUI ↔ NSView ブリッジ）。
// クリックで録音モードになり、押された「キー + 修飾キー」を組み合わせとして
// 確定する。Esc でキャンセル、Backspace で解除（未設定に戻す）。
// 修飾キーのみの設定（履歴の数字キー用の接頭辞）は allowsModifiersOnly = true で、
// 修飾キーを押して離すだけで確定する。

import Carbon.HIToolbox
import SwiftUI

struct HotkeyRecorder: NSViewRepresentable {
    /// nil は「未設定」（ホットキー無効）。
    @Binding var combo: HotkeyCombo?
    /// 修飾キーのみの組み合わせを許すか。
    var allowsModifiersOnly = false
    /// Backspace での解除（未設定）を許すか。
    var allowsNone = true

    func makeNSView(context: Context) -> RecorderField {
        RecorderField()
    }

    func updateNSView(_ nsView: RecorderField, context: Context) {
        nsView.allowsModifiersOnly = allowsModifiersOnly
        nsView.allowsNone = allowsNone
        nsView.combo = combo
        nsView.onChange = { combo = $0 }
    }
}

final class RecorderField: NSView {
    var combo: HotkeyCombo? {
        didSet { if !recording { updateLabel() } }
    }
    var allowsModifiersOnly = false
    var allowsNone = true
    var onChange: ((HotkeyCombo?) -> Void)?

    private var recording = false
    /// 録音中に押された修飾キー（flagsChanged の離し判定に使う）。
    private var liveModifiers: UInt32 = 0
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.borderWidth = 1
        label.alignment = .center
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        addSubview(label)
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: max(110, label.intrinsicContentSize.width + 28), height: 24)
    }

    override func layout() {
        super.layout()
        label.frame = bounds.insetBy(dx: 6, dy: 0)
    }

    // クリックで録音開始（前面アプリの切替無しに最初のクリックを受け取る）。
    // SDK により NSEvent? / NSEvent の両方の署名が存在するため、override にはしない。
    @objc(acceptFirstMouse:) private func _acceptFirstMouse(_ event: NSEvent?) -> Bool {
        true
    }
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        recording = true
        liveModifiers = 0
        updateAppearance()
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        updateAppearance()
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { return }
        let keyCode = UInt32(event.keyCode)
        switch keyCode {
        case 53: // Esc — キャンセル
            recording = false
            updateAppearance()
        case 51 where allowsNone: // Backspace — 解除
            onChange?(nil)
            recording = false
            updateAppearance()
        default:
            let modifiers = Self.carbonFlags(from: event.modifierFlags)
            // 修飾キー無しの単独キーはホットキーとして危険（通常入力を奪う）ため弾く
            guard modifiers != 0 else {
                NSSound.beep()
                return
            }
            onChange?(HotkeyCombo(keyCode: keyCode, modifiers: modifiers))
            recording = false
            updateAppearance()
        }
    }

    override func flagsChanged(with event: NSEvent) {
        guard recording else { return }
        liveModifiers = Self.carbonFlags(from: event.modifierFlags)
        if liveModifiers != 0 {
            lastNonZeroModifiers = liveModifiers
        }
        // 修飾キーのみが許可されたコントロールでは「修飾キーを押して全て離す」で確定
        if allowsModifiersOnly, liveModifiers == 0, lastNonZeroModifiers != 0 {
            onChange?(HotkeyCombo(keyCode: 0, modifiers: lastNonZeroModifiers))
            lastNonZeroModifiers = 0
            recording = false
            updateAppearance()
        }
    }

    /// flagsChanged の「離した」側を取りこぼさないための直近の非ゼロ値。
    private var lastNonZeroModifiers: UInt32 = 0

    private func updateAppearance() {
        updateLabel()
        if recording {
            layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            label.textColor = .white
        } else {
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
            label.textColor = .labelColor
        }
        needsLayout = true
    }

    private func updateLabel() {
        if let combo, !combo.isUnset {
            label.stringValue = combo.label
        } else {
            label.stringValue = L("None")
        }
        invalidateIntrinsicContentSize()
    }

    /// NSEvent の修飾フラグ → Carbon の修飾フラグ。
    static func carbonFlags(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var f: UInt32 = 0
        if flags.contains(.control) { f |= UInt32(controlKey) }
        if flags.contains(.option) { f |= UInt32(optionKey) }
        if flags.contains(.shift) { f |= UInt32(shiftKey) }
        if flags.contains(.command) { f |= UInt32(cmdKey) }
        return f
    }
}
