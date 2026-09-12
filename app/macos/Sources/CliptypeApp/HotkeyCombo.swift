// ホットキーの組み合わせ（キーコード + 修飾キー）のモデルと永続化。
// 従来のプリセット選択に代わり、録音 UI で任意の組み合わせを設定できる。

import Carbon.HIToolbox
import Foundation

/// ホットキー 1 組。
struct HotkeyCombo: Equatable {
    /// Carbon の仮想キーコード。修飾キーのみの設定（履歴の数字キー用）では 0。
    var keyCode: UInt32
    /// Carbon の修飾キーフラグ（controlKey / shiftKey / optionKey / cmdKey）。
    var modifiers: UInt32

    /// 修飾キーだけの組み合わせか（数字キーとの併用用の「接頭辞」）。
    var isModifiersOnly: Bool { keyCode == 0 && modifiers != 0 }

    /// 無効（未設定）か。
    var isUnset: Bool { keyCode == 0 && modifiers == 0 }

    /// 表示用ラベル（例: ⌃⇧V。修飾のみなら ⌃⇧、未設定なら空文字）。
    var label: String {
        Self.modifierSymbols(modifiers) + Self.keyName(keyCode)
    }

    /// 修飾キーフラグ → シンボル（macOS 標準の並び: ⌃⌥⇧⌘）。
    static func modifierSymbols(_ modifiers: UInt32) -> String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s
    }

    /// キーコード → 表示名。ANSI 主要キー + F1–F12 + 特殊キー。
    /// 網羅はしないが、録音 UI で実際に押される範囲はカバーする。
    static func keyName(_ keyCode: UInt32) -> String {
        if keyCode == 0 { return "" }
        return keyNames[keyCode] ?? "Key \(keyCode)"
    }

    static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 25: "9", 26: "7", 27: "=", 28: "8", 29: "0", 30: "]",
        31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 43: ",", 44: "/", 45: "N",
        46: "M", 47: ".", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        103: "F11", 109: "F10", 111: "F12", 118: "F4", 120: "F2", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    /// 履歴クイック入力に使う数字キー（1–9, 0 の順でインデックス 0–9 に対応）。
    static let digitKeyCodes: [UInt32] = [
        18, 19, 20, 21, 23, 22, 26, 28, 25, 29,
    ]

    /// 履歴クイック入力のバッジ表示（1–9 のあと 0 が 10 番目）。
    static let digitLabels: [String] = [
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
    ]
}

/// UserDefaults への読み書き。
enum HotkeyStore {
    /// キー未設定時の既定値を返す。
    static func load(_ key: String, default defaultCombo: HotkeyCombo) -> HotkeyCombo {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "\(key).keyCode") != nil else { return defaultCombo }
        return HotkeyCombo(
            keyCode: UInt32(defaults.integer(forKey: "\(key).keyCode")),
            modifiers: UInt32(defaults.integer(forKey: "\(key).modifiers"))
        )
    }

    static func save(_ combo: HotkeyCombo, forKey key: String) {
        let defaults = UserDefaults.standard
        defaults.set(Int(combo.keyCode), forKey: "\(key).keyCode")
        defaults.set(Int(combo.modifiers), forKey: "\(key).modifiers")
    }

    /// 従来のプリセット ID（v0.1.x）→ 組み合わせへの移行。一度でも新しい形式で
    /// 保存されていれば何もしない。
    static func migrateFromPresetId() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "hotkeyPresetId") != nil,
            defaults.object(forKey: "hotkeyMain.keyCode") == nil
        else { return }

        let preset: HotkeyCombo
        switch defaults.string(forKey: "hotkeyPresetId") {
        case "ctrl-opt-v":
            preset = HotkeyCombo(keyCode: 9, modifiers: UInt32(controlKey | optionKey))
        case "cmd-shift-b":
            preset = HotkeyCombo(keyCode: 11, modifiers: UInt32(cmdKey | shiftKey))
        case "ctrl-shift-p":
            preset = HotkeyCombo(keyCode: 35, modifiers: UInt32(controlKey | shiftKey))
        default: // "ctrl-shift-v" など
            preset = HotkeyCombo(keyCode: 9, modifiers: UInt32(controlKey | shiftKey))
        }
        save(preset, forKey: "hotkeyMain")
        defaults.removeObject(forKey: "hotkeyPresetId")
    }
}
