# Implementation Plan

按阶段推进；每个阶段完成后在 [PROGRESS.md](../PROGRESS.md) 记录并勾选。
与 README 的 Roadmap 对应，但这里是给开发用的细化版本。

## Phase 1: 核心 MVP（可用的 v0.1.0）

1. `clipboard::read_text()` — `arboard::Clipboard::new()?.get_text()`；
   剪贴板为空或非文本（`ContentNotAvailable`）时给出清晰的英文错误提示，不 panic。
2. `typer::type_text()` — `enigo::Enigo::new(&Settings::default())?`：
   - `interval == 0`：`enigo.text(&text)` 整段发送（最快，enigo 内部处理 Unicode）。
   - `interval > 0`：逐字符发送，字符间 sleep interval。
3. 换行归一化：键入前把 `\r\n` / `\r` 归一为 `\n`，避免 Windows 剪贴板文本在
   macOS/Linux 上多敲一次回车（抽成纯函数 + 单元测试）。
4. 本机验证：`cargo run -- --dry-run` → macOS 辅助功能授权 → 真实键入
   TextEdit/浏览器输入框（英文、日文、emoji、多行、Tab）。
5. 里程碑：macOS 上端到端可用，CHANGELOG 记 0.1.0。

## Phase 2: 跨平台健壮性

1. macOS 未授权辅助功能时的错误检测与引导信息（enigo 的失败模式实测确认）。
2. Windows / Linux(X11) 实机或 VM 验证 Unicode、换行、Tab 行为，平台差异记进
   AGENTS.md 平台注意事项。
3. 特殊字符边界情况：IME 干扰、目标应用吞字（interval 建议值写进 README）。
4. `--interval` 下的进度反馈（长文本时 stderr 显示进度，不显示内容本身）。

## Phase 3: 常驻热键模式（feature = `hotkey`）— ✅ 2026-07-22 完成

1. ✅ `--hotkey [COMBO]` 参数（仅 `--features hotkey` 编译时存在，默认 `ctrl+shift+v`）。
2. ✅ `global-hotkey` 事件循环。macOS 必须用 Carbon `RunApplicationEventLoop`
   （裸 CFRunLoopRun 不分发应用目标事件，详见 PROGRESS.md 2026-07-22）。
3. ✅ 常驻时按热键 = 等修饰键松开后立即"读剪贴板→键入"（`--delay` 在此模式无效）。
4. ✅ README 增加 hotkey 模式用法。

## Phase 3.5: 状态栏/托盘 UI（feature = `tray`，macOS/Windows）— ✅ 2026-07-22 完成

1. ✅ `--tray`：热键常驻 + 原生状态栏图标（tray-icon + tao，target-specific deps，
   两平台二进制互不包含对方 UI 代码；Linux 不支持托盘）。
2. ✅ 菜单：当前热键显示、Pause/Resume、打字速度预设（Fastest/20ms/50ms）、Quit。
3. ✅ 设置持久化：`~/.config/cliptype/config.toml`（Windows `%APPDATA%\cliptype\`），
   std 手写 key=value 解析（有单元测试），坏文件静默回退默认值。
4. ✅ macOS 全链路真机验证（图标、菜单、暂停/恢复、持久化、退出）。
   Windows 待实机验证。

## Phase 4: 发布与打磨

1. GitHub Actions release workflow：打 tag → 构建三平台二进制 → 上传 Release。
2. 打字速度预设：`--speed slow|normal|fast` 映射到 interval 值。
3. （可选）发布到 crates.io / Homebrew tap。

## 已知风险

- enigo 0.2 在 macOS 对长文本 `.text()` 的可靠性未验证；不行就退回逐字符模式。
- Wayland 下 enigo/arboard 支持不完整，明确标注为 best-effort。
- 部分目标应用（远程桌面客户端）会在高速键入时吞字 → interval 是第一缓解手段。
