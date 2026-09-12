// 設定ウィンドウ（アプリ本体の UI）。
// メニューバーのメニューより詳しい説明つきで同じ設定を編集できる。

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var updater = Updater.shared
    @ObservedObject private var history = ClipboardHistory.shared
    @ObservedObject private var floating = FloatingHistoryController.shared

    var body: some View {
        Form {
            Section {
                Picker(L("Input method"), selection: inputActionBinding) {
                    ForEach(AppState.InputAction.allCases) { action in
                        Text(action.label).tag(action)
                    }
                }
                Text(L("Typing works even in input fields that block pasting — that is what cliptype was built for. \"Paste text only\" writes the plain text to the clipboard (stripping rich formatting) and presses ⌘V once: instant for long texts, but only works where pasting is allowed."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(L("Input method"))
            }

            Section {
                LabeledContent(L("Type the clipboard")) {
                    HotkeyRecorder(
                        combo: mainHotkeyBinding,
                        allowsModifiersOnly: false,
                        allowsNone: false
                    )
                    .frame(height: 24)
                }
                LabeledContent(L("History item (number keys)")) {
                    HotkeyRecorder(
                        combo: historyHotkeyBinding,
                        allowsModifiersOnly: true,
                        allowsNone: true
                    )
                    .frame(height: 24)
                }
                LabeledContent(L("Show the history window")) {
                    HotkeyRecorder(
                        combo: floatHotkeyBinding,
                        allowsModifiersOnly: false,
                        allowsNone: true
                    )
                    .frame(height: 24)
                }
                Text(L("Click a field, then press the key combination you want. Esc cancels recording; Backspace clears the shortcut. Combine the history prefix with the number keys 1–9 and 0 to input that history item."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(state.hotkeyErrors, id: \.self) { combo in
                    Label(
                        L("⚠ %@ could not be registered — it may already be in use by another app.", combo),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            } header: {
                Text(L("Shortcuts"))
            }

            Section {
                Picker(L("Typing speed"), selection: $state.intervalMs) {
                    ForEach(AppState.speedPresets, id: \.intervalMs) { preset in
                        Text(preset.label).tag(preset.intervalMs)
                    }
                }
                .pickerStyle(.radioGroup)
                Text(L("Slow down if the target app drops characters (common in remote desktops)."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(L("Typing"))
            }

            Section {
                Toggle(L("Remote console mode (VNC / VM)"), isOn: $state.keycodeMode)
                Text(L("Presses real key codes instead of sending Unicode text. Turn this on for VNC, remote consoles and VM windows, which otherwise receive every character as \"a\". Only characters on your keyboard layout can be typed this way."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(L("Compatibility"))
            }

            Section {
                Toggle(
                    L("Keep a clipboard history"),
                    isOn: Binding(
                        get: { history.isEnabled },
                        set: {
                            history.isEnabled = $0
                            // 数字キーの登録・解除を反映する
                            state.refreshHotkeys()
                        }
                    )
                )
                Text(L("Stores the text you copy, on this Mac only, in your Application Support folder. Items that password managers mark as concealed are skipped. Off by default."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if history.isEnabled {
                    Picker(
                        L("Keep up to"),
                        selection: Binding(
                            get: { history.maxEntries },
                            set: { history.maxEntries = $0 }
                        )
                    ) {
                        ForEach(ClipboardHistory.maxEntriesOptions, id: \.self) { n in
                            Text(L("%d items", n)).tag(n)
                        }
                    }
                    HStack {
                        Text(L("%d items stored", history.entries.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L("Clear history")) {
                            history.clear()
                        }
                        .disabled(history.entries.isEmpty)
                    }

                    Toggle(
                        L("Floating history window"),
                        isOn: Binding(
                            get: { floating.isPreferred },
                            set: { floating.setPreferred($0) }
                        )
                    )
                    Text(L("Shows an always-on-top window with your recent items. Click an item to input it; the window stays visible in every space."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if floating.isPreferred {
                        Picker(
                            L("Items shown"),
                            selection: Binding(
                                get: { floating.count },
                                set: { floating.count = $0 }
                            )
                        ) {
                            ForEach(FloatingHistoryController.countOptions, id: \.self) { n in
                                Text(L("%d items", n)).tag(n)
                            }
                        }
                    }
                }
            } header: {
                Text(L("Clipboard history"))
            }

            Section {
                if state.axTrusted {
                    Label(L("Accessibility permission granted"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label(
                        L("Accessibility permission required — without it macOS discards simulated keystrokes"),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                    Button(L("Open System Settings…")) {
                        PermissionHelper.openSystemSettings()
                    }
                    // アップデート後は TCC の古いレコードが残り、スイッチを入れ直しても
                    // 効かないことがある（ユーザー報告）。その手順をそのまま案内する。
                    Text(L("If Cliptype is already listed and switching it off and on doesn't help, select the Cliptype row, click the − button to remove it, then click + and add Cliptype again. An update changes the app's signature, and only re-adding the entry records the new one."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(L("Remove the stale entry for me…")) {
                        PermissionHelper.resetPermissionRecord()
                        PermissionHelper.promptIfNeeded()
                        PermissionHelper.openSystemSettings()
                    }
                }
            } header: {
                Text(L("Permissions"))
            }

            Section {
                Toggle(
                    L("Check for updates automatically"),
                    isOn: Binding(
                        get: { updater.autoCheckEnabled },
                        set: { updater.autoCheckEnabled = $0 }
                    )
                )
                HStack {
                    Button(L("Check Now…")) {
                        Task { @MainActor in await updater.check(userInitiated: true) }
                    }
                    .disabled(updater.status == .checking || updater.status == .downloading)
                    Text(updater.statusDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(L("Version %@", Updater.currentVersion))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(L("Updates"))
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - バインディング

    private var inputActionBinding: Binding<AppState.InputAction> {
        Binding(
            get: { state.inputAction },
            set: { state.inputAction = $0 }
        )
    }

    /// HotkeyRecorder は nil = 未設定を扱うため、AppState の保存値と相互変換する。
    private var mainHotkeyBinding: Binding<HotkeyCombo?> {
        Binding(
            get: { state.mainHotkey },
            set: { state.mainHotkey = $0 ?? state.mainHotkey }
        )
    }

    private var historyHotkeyBinding: Binding<HotkeyCombo?> {
        Binding(
            get: {
                let c = state.historyHotkey
                return c.isUnset ? nil : c
            },
            set: { state.historyHotkey = $0 ?? HotkeyCombo(keyCode: 0, modifiers: 0) }
        )
    }

    private var floatHotkeyBinding: Binding<HotkeyCombo?> {
        Binding(
            get: {
                let c = state.floatHotkey
                return c.isUnset ? nil : c
            },
            set: { state.floatHotkey = $0 ?? HotkeyCombo(keyCode: 0, modifiers: 0) }
        )
    }
}
