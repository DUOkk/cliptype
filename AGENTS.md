# AGENTS.md — cliptype 项目说明

本文件是 agent 在本仓库工作时的权威指引，开工前先读一遍。
**CLAUDE.md 是本文件的精简镜像；两者保持一致。**

## ⚠️ 第一要求：随时更新进度

**每次有实质进展、决策、或卡点时，必须更新 [PROGRESS.md](PROGRESS.md)（最新放最上）。**
- 完成一个模块、做出一个技术决策、遇到阻塞 → 立刻记进 PROGRESS.md，不要等会话结束才补记。
- 重大决策同时更新本文件和 CLAUDE.md 的相关部分。
- 日期一律写绝对日期（如 2026-07-21），不要写"今天/昨天"。

## 项目速览

跨平台"剪贴板转键盘输入"工具：读取剪贴板文本，模拟键入，用于禁止粘贴的输入框
（远程桌面、VM、部分密码框等）。思路借鉴一个 Windows-only 的 AutoHotkey 小工具，
但是**全新实现，不含任何原始代码**。

**产品形态（2026-07-22 用户确定）**：最终产品是平台原生常驻应用；Rust CLI 是
功能验证手段 + Linux 形态 + 各原生应用同捆的键入引擎。macOS = SwiftUI 应用
（应用本体/设置窗口 + 常驻菜单栏）；Windows = 暂用 Rust tray exe，将来原生化；
两平台界面独立维护、打包互不包含对方内容。

- [src/main.rs](src/main.rs) — 入口：按参数分派到单次/热键/托盘模式。
- [src/cli.rs](src/cli.rs) — clap derive 参数：`--delay` / `--interval` / `--dry-run` /
  `--hotkey [COMBO]`（feature hotkey）/ `--tray`（feature tray）。
- [src/clipboard.rs](src/clipboard.rs) — `read_text()`，用 `arboard`。
- [src/typer.rs](src/typer.rs) — `type_text()`（enigo）+ macOS 辅助功能权限检测。
- [src/hotkey.rs](src/hotkey.rs) — feature `hotkey`：常驻热键模式（global-hotkey）。
  macOS 事件循环必须用 Carbon `RunApplicationEventLoop`（见 PROGRESS 2026-07-22）。
- [src/tray.rs](src/tray.rs) — feature `tray`（仅 macOS/Windows）：状态栏/托盘 UI
  （tray-icon + tao），菜单改设置须在主线程（经 EventLoopProxy 转发）。
- [src/config.rs](src/config.rs) — 托盘设置持久化（std 手写 key=value，无新依赖）。
- 依赖用 target-specific dependencies 隔离：macOS 二进制不含 Windows UI 代码，
  反之亦然；Linux 构建完全不引入托盘依赖（GTK 太重，托盘不支持 Linux）。
- [app/macos/](app/macos/) — SwiftUI 菜单栏应用（SwiftPM，macOS 14+）：MenuBarExtra +
  Settings 窗口 + Carbon 热键；按热键时调用同捆的 Rust 引擎（`--delay 0` 单次模式）。
  键入实现只在 Rust 侧维护，Swift 不重复实现。
- [scripts/bundle-macos.sh](scripts/bundle-macos.sh) — 组装 dist/Cliptype.app
  （LSUIElement、ad-hoc 签名；TCC 只需授权 App 一处，子进程引擎自动继承）。

实施计划见 [docs/implementation-plan.md](docs/implementation-plan.md)，当前进度见 [PROGRESS.md](PROGRESS.md)。

## 语言规范

- **对话**：与用户交流一律使用中文。
- **代码注释**：日语（用户个人偏好，遵循既有代码风格）；标识符、变量名用英文。
- **git / 面向公众的文本**：这是开源项目——commit message、PR、README、错误提示等
  用户可见输出一律用英文。

## 核心设计原则

1. **绝不泄露剪贴板内容**：剪贴板里可能是密码。除显式的 `--dry-run` 外，
   任何日志、错误信息、panic 输出都不得包含剪贴板文本（长度、字符数可以）。
2. **默认安全**：键入前必须有可感知的延迟（默认 2000ms）并提示用户切换窗口；
   不做任何"自动聚焦目标窗口"的魔法。
3. **跨平台一致**：新功能必须三平台都能编译（CI 会验证）；平台差异集中在模块内部处理，
   不泄漏到 main.rs。
4. **保持小而专**：这是单一用途 CLI，抵制范围蔓延；新依赖要有充分理由。

## 平台注意事项

- **macOS**（主要开发/验证平台）：模拟键入需要「系统设置 → 隐私与安全性 → 辅助功能」授权；
  未授权时 enigo 会静默失败或报错，错误提示里要引导用户去授权。
- **Linux (X11)**：需要 `libxdo-dev` 和 xcb 系列开发库（CI 已安装）；Wayland 支持有限，
  依赖 compositor，README 已说明。
- **Windows**：无需额外配置。

## 工程流程

- **会话内**：非平凡的多步任务用 TaskCreate/TaskUpdate 跟踪，完成即时标记。
- 提交前跑 `cargo fmt` 和 `cargo clippy -- -D warnings`（CI 同样标准）。
- 文本处理逻辑（换行归一化等）抽成纯函数写单元测试；依赖真实剪贴板/键盘的部分
  靠 `--dry-run` 和手动验证，不写脆弱的集成测试。
- 测试真实键入时，先复制无害的测试文本；不要把测试用剪贴板内容写进文档或 commit。
