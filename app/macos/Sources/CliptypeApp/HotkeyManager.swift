// Carbon RegisterEventHotKey の薄いラッパー。
// グローバルホットキーの押下を onPressed コールバックで通知する。
//
// 1 プロセスで複数の組み合わせ（メイン・数字キー・フローティング切替）を
// 登録するため、インスタンスごとに一意の hotkey ID を持ち、イベントの
// EventHotKeyID と突き合わせて自分の押下だけを通知する
// （ハンドラは GetApplicationEventTarget に登録され、全インスタンスに
// 配送されるため、ID で振り分けないと全員が反応してしまう）。

import Carbon.HIToolbox
import Foundation

final class HotkeyManager {
    /// 自分のホットキー ID（インスタンスごとに一意）。メインスレッドでのみ生成される。
    private(set) var hotKeyId: UInt32 = 0
    private static var nextId: UInt32 = 0

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// ホットキー押下時に呼ばれる（Carbon のイベントスレッド = メインスレッド）。
    var onPressed: (() -> Void)?

    enum HotkeyError: LocalizedError {
        case installHandler(OSStatus)
        case register(OSStatus)

        var errorDescription: String? {
            switch self {
            case .installHandler(let s): return "InstallEventHandler failed (\(s))"
            case .register(let s): return "RegisterEventHotKey failed (\(s)) — combo already in use?"
            }
        }
    }

    init() {
        assert(Thread.isMainThread, "HotkeyManager must be created on the main thread")
        HotkeyManager.nextId += 1
        hotKeyId = HotkeyManager.nextId
    }

    /// 既存の登録を解除して、新しい組み合わせを登録する。
    /// keyCode が 0（未設定）なら登録解除のみ行う。
    func register(keyCode: UInt32, modifiers: UInt32) throws {
        unregister()
        guard keyCode != 0 else { return }

        if handlerRef == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            let status = InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, userData in
                    guard let userData else { return noErr }
                    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                    // 全ハンドラに配送されるため、EventHotKeyID で自分の押下か判定する
                    var hotkeyId = EventHotKeyID()
                    let getStatus = GetEventParameter(
                        event,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &hotkeyId
                    )
                    if getStatus == noErr, hotkeyId.id == manager.hotKeyId {
                        manager.onPressed?()
                    }
                    return noErr
                },
                1,
                &eventType,
                Unmanaged.passUnretained(self).toOpaque(),
                &handlerRef
            )
            guard status == noErr else { throw HotkeyError.installHandler(status) }
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C_5054) /* "CLPT" */, id: hotKeyId)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else { throw HotkeyError.register(status) }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    deinit {
        unregister()
        if let ref = handlerRef {
            RemoveEventHandler(ref)
        }
    }
}
