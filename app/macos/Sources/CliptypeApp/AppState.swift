// アプリ全体の状態と設定の永続化（UserDefaults 経由）。
// メニューと設定ウィンドウの両方から同じインスタンスを参照する。

import Carbon.HIToolbox
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    /// 速度プリセット。Rust CLI の --speed と同じ値に揃えている。
    static let speedPresets: [(label: String, intervalMs: Int)] = [
        (L("Fastest (no per-key delay)"), 0),
        (L("Steady (20 ms per key)"), 20),
        (L("Careful (50 ms per key)"), 50),
    ]

    /// テキストの入れ方。
    enum InputAction: String, CaseIterable, Identifiable {
        /// 1 文字ずつシミュレートキー入力（既定）。貼り付け禁止の入力欄でも動く。
        case type
        /// 平文をクリップボードへ書き戻し（書式を落とす）て ⌘V を 1 回送る。
        case pasteText

        var id: String { rawValue }

        var label: String {
            switch self {
            case .type: return L("Type as keystrokes")
            case .pasteText: return L("Paste text only (⌘V)")
            }
        }
    }

    // 既定のホットキー。⌃⇧V（メイン）/ ⌃⇧+数字（履歴）/ ⌃⇧H（ウィンドウ）。
    static let defaultMainHotkey = HotkeyCombo(
        keyCode: 9, modifiers: UInt32(controlKey | shiftKey))
    static let defaultHistoryHotkey = HotkeyCombo(
        keyCode: 0, modifiers: UInt32(controlKey | shiftKey))
    static let defaultFloatHotkey = HotkeyCombo(
        keyCode: 4, modifiers: UInt32(controlKey | shiftKey))

    @AppStorage("intervalMs") var intervalMs: Int = 0
    /// 実キーコードモード（VNC / リモートコンソール / VM 向け）
    @AppStorage("keycodeMode") var keycodeMode: Bool = false
    @AppStorage("inputActionRaw") private var inputActionRaw: String = InputAction.type.rawValue

    /// テキストの入れ方（貼り付け方式）。
    var inputAction: InputAction {
        get { InputAction(rawValue: inputActionRaw) ?? .type }
        set {
            inputActionRaw = newValue.rawValue
            objectWillChange.send()
        }
    }

    @Published var isPaused = false

    /// ホットキー登録に失敗した組み合わせ（設定画面に表示する）。
    @Published private(set) var hotkeyErrors: [String] = []

    /// アクセシビリティ権限の現在値。メニュー/設定の表示はこれを参照する。
    /// AXIsProcessTrusted() を直接ビューで呼ぶと、付与後もメニューが
    /// 再評価されず古い表示が残るため、監視付きの @Published にしている。
    @Published private(set) var axTrusted = PermissionHelper.isTrusted()

    /// 起動してから一度も権限を観測できていないか（＝案内を強めに出す条件）。
    @Published private(set) var permissionNeverSeen = !PermissionHelper.isTrusted()

    private let mainHotkeyManager = HotkeyManager()
    private let floatHotkeyManager = HotkeyManager()
    private lazy var digitHotkeyManagers: [HotkeyManager] = (0..<10).map { _ in HotkeyManager() }
    private var permissionTimer: Timer?

    private init() {
        // v0.1.x のプリセット選択から新形式（ keyCode + modifiers ）への移行
        HotkeyStore.migrateFromPresetId()
    }

    // MARK: - 権限

    /// 権限状態の変化（付与・剥奪とも）を定期的に拾ってメニューへ反映する。
    ///
    /// 注意: プロセス内の `AXIsProcessTrusted()` は**キャッシュされる**ため、
    /// いくらポーリングしても起動後の変化を観測できない（実測: 許可を取り消しても
    /// true のまま、許可を与えても false のまま）。これが「許可したのにアプリが
    /// 認識しない」というユーザー報告の一因だった。そこで同梱エンジンを新しい
    /// プロセスとして起動して問い合わせる。数 ms の軽い処理だが、無駄打ちを
    /// 避けるため許可済みのときは間隔を空ける。
    func startPermissionWatcher() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in AppState.shared.pollPermission() }
        }
        // 起動直後にも 1 回だけ正確な値を取り直す
        pollPermission(force: true)
    }

    private var permissionTick = 0

    /// 未許可のときは 2 秒ごと、許可済みのときは 10 秒ごとに確認する。
    private func pollPermission(force: Bool = false) {
        permissionTick += 1
        if !force, axTrusted, permissionTick % 5 != 0 { return }
        Task.detached(priority: .utility) {
            let trusted = PermissionHelper.isTrustedFresh()
            await MainActor.run { AppState.shared.applyTrustState(trusted) }
        }
    }

    fileprivate func applyTrustState(_ trusted: Bool) {
        if trusted != axTrusted {
            axTrusted = trusted
        }
        if trusted {
            permissionNeverSeen = false
            // 「一度でも許可されたことがある」を記録（起動時の自動ダイアログ抑制用）
            if !UserDefaults.standard.bool(forKey: "hasEverBeenTrusted") {
                UserDefaults.standard.set(true, forKey: "hasEverBeenTrusted")
            }
        }
    }

    // MARK: - ホットキー（任意の組み合わせを設定可能）

    /// メイン（クリップボード入力）ホットキー。
    var mainHotkey: HotkeyCombo {
        get { HotkeyStore.load("hotkeyMain", default: Self.defaultMainHotkey) }
        set { HotkeyStore.save(newValue, forKey: "hotkeyMain"); refreshHotkeys() }
    }

    /// 履歴クイック入力の接頭辞（この修飾キー + 数字 1–9, 0）。
    var historyHotkey: HotkeyCombo {
        get { HotkeyStore.load("hotkeyHistory", default: Self.defaultHistoryHotkey) }
        set { HotkeyStore.save(newValue, forKey: "hotkeyHistory"); refreshHotkeys() }
    }

    /// フローティングウィンドウの切替ホットキー。
    var floatHotkey: HotkeyCombo {
        get { HotkeyStore.load("hotkeyFloat", default: Self.defaultFloatHotkey) }
        set { HotkeyStore.save(newValue, forKey: "hotkeyFloat"); refreshHotkeys() }
    }

    /// 起動時に呼ぶ。現在の設定で全ホットキーを（再）登録する。
    func activateHotkey() {
        refreshHotkeys()
    }

    /// 設定変更時に呼ぶ。メイン / 数字 / ウィンドウ切替を登録し直す。
    /// 履歴が無効のときは数字キーを登録しない。
    func refreshHotkeys() {
        objectWillChange.send()
        var errors: [String] = []

        // メイン（クリップボード入力）
        mainHotkeyManager.onPressed = { [weak self] in
            Task { @MainActor in self?.handleHotkey() }
        }
        register(mainHotkeyManager, combo: mainHotkey, errors: &errors)

        // フローティングウィンドウ切替（未設定なら登録しない）
        floatHotkeyManager.onPressed = { [weak self] in
            Task { @MainActor in self?.handleFloatToggle() }
        }
        register(floatHotkeyManager, combo: floatHotkey, errors: &errors)

        // 履歴クイック入力（履歴が有効なときだけ数字キー 1–9, 0 を登録）
        let historyEnabled = ClipboardHistory.shared.isEnabled
        let historyMods = historyHotkey.modifiers
        for (index, manager) in digitHotkeyManagers.enumerated() {
            manager.unregister()
            manager.onPressed = { [weak self] in
                Task { @MainActor in self?.handleHistoryIndex(index) }
            }
            guard historyEnabled, historyMods != 0 else { continue }
            do {
                try manager.register(
                    keyCode: HotkeyCombo.digitKeyCodes[index], modifiers: historyMods)
            } catch {
                errors.append("\(HotkeyCombo.modifierSymbols(historyMods))\(HotkeyCombo.digitLabels[index])")
            }
        }

        hotkeyErrors = errors
        for combo in errors {
            NSLog("cliptype: failed to register hotkey: \(combo)")
        }
    }

    private func register(_ manager: HotkeyManager, combo: HotkeyCombo, errors: inout [String]) {
        manager.unregister()
        guard !combo.isUnset, combo.keyCode != 0 else { return }
        do {
            try manager.register(keyCode: combo.keyCode, modifiers: combo.modifiers)
            NSLog("cliptype: hotkey registered: \(combo.label)")
        } catch {
            NSLog("cliptype: failed to register hotkey: \(error.localizedDescription)")
            errors.append(combo.label)
        }
    }

    // MARK: - 押下ハンドラ

    private func handleHotkey() {
        guard !isPaused else { return }
        let interval = intervalMs
        let keycode = keycodeMode
        let paste = inputAction == .pasteText
        // 数百 ms かかるためメインスレッドを塞がない
        Task.detached(priority: .userInitiated) {
            await Engine.typeClipboard(
                intervalMs: interval, keycodeMode: keycode, paste: paste)
        }
    }

    /// 履歴の index 番目（0 始まり。9 が「0」キー担当）を入力する。
    func handleHistoryIndex(_ index: Int) {
        guard !isPaused else { return }
        inputHistoryEntry(at: index)
    }

    /// 履歴項目を現在の入力方式で入力する（メニュー / 浮動ウィンドウからも使う）。
    /// 入力後はその項目を先頭へ移動する。
    func inputHistoryEntry(at index: Int) {
        guard let entry = ClipboardHistory.shared.entry(at: index) else { return }
        inputHistoryEntry(entry)
    }

    func inputHistoryEntry(_ entry: ClipEntry) {
        let interval = intervalMs
        let keycode = keycodeMode
        let paste = inputAction == .pasteText
        ClipboardHistory.shared.moveEntryToTop(entry)
        Task.detached(priority: .userInitiated) {
            await Engine.typeText(
                entry.text, intervalMs: interval, keycodeMode: keycode, paste: paste)
        }
    }

    private func handleFloatToggle() {
        FloatingHistoryController.shared.toggle()
    }
}
