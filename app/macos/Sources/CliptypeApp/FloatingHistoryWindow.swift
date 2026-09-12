// クリップボード履歴のフローティングウィンドウ（常に手前・全スペース表示）。
// nonactivatingPanel を使うため、行をクリックしても前面アプリは切り替わらず、
// そのまま直前のアプリへ入力できる。

import AppKit
import Combine
import SwiftUI

@MainActor
final class FloatingHistoryController: ObservableObject {
    static let shared = FloatingHistoryController()

    /// 表示件数の選択肢（設定 UI と揃える）。
    static let countOptions = [5, 10, 15, 20]

    @Published private(set) var isVisible = false

    private var panel: NSPanel?
    private var hostingView: NSHostingView<FloatingHistoryView>?
    private var cancellables = Set<AnyCancellable>()

    /// 表示する件数。
    var count: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: "floatWindowCount")
            return Self.countOptions.contains(v) ? v : 10
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "floatWindowCount")
            objectWillChange.send()
            resizeToFitContent()
        }
    }

    private init() {
        // 履歴が増えたら窓の高さを追従させる
        ClipboardHistory.shared.$entries
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.resizeToFitContent() }
            .store(in: &cancellables)
    }

    func toggle() {
        setPreferred(!isPreferred)
    }

    /// ユーザー設定として表示するか（次回起動時の復元にも使う）。
    var isPreferred: Bool {
        UserDefaults.standard.bool(forKey: "floatWindowPreferred")
    }

    func setPreferred(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: "floatWindowPreferred")
        objectWillChange.send()
        on ? show() : hide()
    }

    func show() {
        let p = panel ?? makePanel()
        p.orderFrontRegardless()
        isVisible = true
        resizeToFitContent()
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    private func makePanel() -> NSPanel {
        let view = FloatingHistoryView()
        let host = NSHostingView(rootView: view)
        // SwiftUI の理想サイズに追従させる（macOS 13+）
        host.sizingOptions = [.preferredContentSize]

        let p = HistoryFloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: false)
        p.contentView = host
        p.title = L("Clipboard history")
        p.level = .floating
        p.isFloatingPanel = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.isMovableByWindowBackground = true
        p.becomesKeyOnlyIfNeeded = true
        p.hidesOnDeactivate = false
        p.hasShadow = true
        // 角丸は SwiftUI 側で描くため、窓自体は透過にする
        p.isOpaque = false
        p.backgroundColor = .clear

        // 既定の位置はメイン画面の右上
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let size = host.fittingSize
            let x = visible.maxX - size.width - 16
            let y = visible.maxY - size.height - 16
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }

        hostingView = host
        panel = p
        return p
    }

    /// SwiftUI コンテンツの理想サイズへ窓を合わせる（上端を固定して下に伸縮）。
    func resizeToFitContent() {
        guard isVisible, let panel, let host = hostingView else { return }
        DispatchQueue.main.async {
            let size = host.fittingSize
            var frame = panel.frame
            frame.origin.y += frame.height - size.height
            frame.size = size
            panel.setFrame(frame, display: false)
        }
    }
}

/// クリックしても前面アプリを切り替えないパネル。
final class HistoryFloatingPanel: NSPanel {
    // ボタン操作のためにキーにはなれるが、nonactivatingPanel なので
    // アプリは activate されず、直前のアプリが入力フォーカスを保つ。
    override var canBecomeKey: Bool { true }
}

/// 浮動ウィンドウの中身。
struct FloatingHistoryView: View {
    @ObservedObject private var history = ClipboardHistory.shared
    @ObservedObject private var controller = FloatingHistoryController.shared

    private let rowHeight: CGFloat = 40

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if history.entries.isEmpty {
                Text(L("No items yet"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        ForEach(
                            Array(history.entries.prefix(controller.count).enumerated()),
                            id: \.element.id
                        ) { index, entry in
                            row(index, entry)
                        }
                    }
                }
                .frame(maxHeight: CGFloat(controller.count) * rowHeight)
            }
            Divider()
            footer
        }
        .frame(width: 320)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.separator, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.secondary)
            Text(L("Clipboard history"))
                .font(.headline)
            Spacer()
            Button {
                // 設定のトグルと状態を揃える（閉じたら「表示しない」扱い）
                FloatingHistoryController.shared.setPreferred(false)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L("Close"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func row(_ index: Int, _ entry: ClipEntry) -> some View {
        HStack(spacing: 8) {
            if let badge = quickBadge(index) {
                Text(badge)
                    .font(.caption2.monospacedDigit())
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(.quaternary))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.preview)
                    .lineLimit(1)
                Text(L("%d chars", entry.characterCount))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button {
                history.remove(entry)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L("Delete this item"))
        }
        .padding(.horizontal, 12)
        .frame(height: rowHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            AppState.shared.inputHistoryEntry(entry)
        }
    }

    private var footer: some View {
        HStack {
            Text(L("%d items stored", history.entries.count))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button(L("Clear")) {
                history.clear()
            }
            .buttonStyle(.link)
            .font(.caption2)
            .disabled(history.entries.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    /// 数字キーでクイック入力できる先頭 10 件のバッジ（1–9 のあと 0）。
    private func quickBadge(_ index: Int) -> String? {
        guard index < HotkeyCombo.digitLabels.count else { return nil }
        return HotkeyCombo.digitLabels[index]
    }
}
