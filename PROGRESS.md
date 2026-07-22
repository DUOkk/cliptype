# PROGRESS.md — cliptype 进度记录

> 最新在上；绝对日期；记录实质进展、技术决策、卡点。规则见 [AGENTS.md](AGENTS.md)。

## 2026-07-22

- **TCC 授权排查（用户在 Claude Code 桌面 App 内置终端测试）**：辅助功能授权按
  "责任 App"归属，Claude 桌面版有两个独立 TCC 主体——主应用 `/Applications/Claude.app`
  （用户终端的 shell 挂在它下面）和内嵌 CLI `…/Application Support/Claude/claude-code/…/claude.app`
  （agent 工具进程挂在它下面）。只授权其中一个时会出现"agent 能打字、用户终端不能"。
  解决：在辅助功能列表把两个都启用，或改用 Terminal.app/iTerm 并给其授权。
  这也验证了 `ensure_permission()` 报错路径在真实用户场景下正常工作。
- **真实键入端到端验证通过**（用户授权辅助功能后，agent 用 AppleScript 驱动 TextEdit
  自动化验证：键入 → 读回 → 比对 → 关闭不保存）。快速模式 3/3、逐字符模式 1/1 内容完整。
  过程中发现并修复两个真实 bug：
  1. **尾部丢字（竞态）**：发送完最后一个 CGEvent 后进程立即退出，未投递的事件随进程
     消失，偶发丢失最后一段文本（enigo 块间只 sleep 2ms）。修复：type_text 结束前
     等待 120ms 再返回。
  2. **逐字符模式被 IME 截胡**：`Key::Unicode` 模拟物理键码，活跃的中文 IME 会拦截
     组词（实测「日本語」→「啊啊啊」，空格/emoji 全丢）。修复：逐字符模式改用与快速
     模式相同的 `text()`（unicode 字符串附加事件，IME 素通り），一次发一个字符。
  - 已知无害现象：TextEdit 富文本模式的自动首字母大写会把行首小写字母改成大写
    （line2→Line2），属于目标应用的替换功能，与 cliptype 无关；纯文本框不受影响。
- **用户实测发现关键坑：未授权时静默失败**。真实键入测试"什么都没输入、无报错、正常退出"。
  根因：enigo 0.2.1 在 macOS 上**完全不检查辅助功能权限**（源码里没有 AXIsProcessTrusted），
  未授权时 CGEvent 被 OS 静默丢弃。修复：typer.rs 增加 `ensure_permission()`
  （直接 FFI 调 ApplicationServices 的 `AXIsProcessTrusted`，无新依赖），main 在倒计时前
  就检查，未授权立即报错并给出授权+重启终端的指引。已在沙盒（未授权环境）端到端验证
  报错路径正确。注意：授权后必须完全退出并重开终端 App 才生效（README 已写明）。
- **Phase 1 核心功能实装完成**：
  - `clipboard::read_text()` — arboard；空/非文本返回空字符串由 main 友好提示，不报错。
  - `typer::type_text()` — enigo；`interval==0` 走批量 `text()` 快速模式，`>0` 逐字符
    （`Key::Unicode`）+ sleep。改行/Tab 一律作为真实 Return/Tab 键发送
    （混在 `text()` 里部分应用不识别）。
  - 换行归一化 `normalize_newlines()`（CRLF/CR → LF）纯函数 + 5 个单元测试。
  - macOS 键盘错误附加辅助功能授权引导；错误信息不含剪贴板内容（设计原则）。
  - 用户可见文案（--help、运行时提示）从日语改为英文，符合 AGENTS.md 语言规范。
- **dry-run 端到端验证通过**（macOS 本机）：日文/emoji/Tab/CRLF/LF 混合文本 40 字符
  全部正确读取。真实键入验证（需辅助功能授权 + 手动操作）留给用户做。
- 踩坑记录：测试时 pbcopy 吞掉含多字节字符的内容，原因是 agent 沙盒 shell 未设 locale
  （`LANG` 空）；`export LC_ALL=en_US.UTF-8` 解决。与 cliptype 本身无关。
- 下一步：用户手动验证真实键入（TextEdit/浏览器）→ Phase 2 权限失败模式实测。

## 2026-07-21

- 修复首次 CI 失败：三平台都挂在 `cargo fmt --check`（main.rs 一行过长），本地
  `cargo fmt` 修复；顺带给 stub 阶段未读取的 `TypeOptions.interval` 加临时
  `#[allow(dead_code)]`（CI clippy 带 `-D warnings`，Phase 1 实装后移除）。
  本地已通过 fmt/clippy/build/test 全部四步。开发机新装了 rustup 稳定版工具链。
- 制定项目文档体系：AGENTS.md（权威指引）、CLAUDE.md（精简镜像）、
  [docs/implementation-plan.md](docs/implementation-plan.md)（分 4 个 Phase 的实施计划）、本文件。
- 确定核心设计原则：绝不在输出中泄露剪贴板内容（`--dry-run` 除外）；
  语言规范为对话中文 / 注释日语 / commit 与用户可见文本英文。
- 仓库已推送到 GitHub（https://github.com/Szyoo/cliptype ，分支 `main`），
  占位符 USERNAME 已替换为 Szyoo，CI（三平台 fmt+clippy+build+test）已触发。
- 当前状态：脚手架完成；`clipboard::read_text()` 和 `typer::type_text()` 仍是
  `bail!` 的 stub。下一步：Phase 1（实装这两个函数 + 换行归一化 + macOS 实测）。
