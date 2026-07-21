# PROGRESS.md — cliptype 进度记录

> 最新在上；绝对日期；记录实质进展、技术决策、卡点。规则见 [AGENTS.md](AGENTS.md)。

## 2026-07-22

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
