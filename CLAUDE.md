# CLAUDE.md — cliptype

> 本文件是 [AGENTS.md](AGENTS.md) 的精简镜像，两者保持一致；详细规则以 AGENTS.md 为准。
> 进度与决策记录在 [PROGRESS.md](PROGRESS.md)（最新在上，绝对日期），每次实质进展立刻更新。

## 这是什么

跨平台 CLI（Rust）：读剪贴板文本 → 延迟 → 用 enigo 逐字符模拟键入，
绕过禁止粘贴的输入框。macOS 为主要开发平台。计划见 [docs/implementation-plan.md](docs/implementation-plan.md)。

## 结构

- [src/main.rs](src/main.rs) — 入口流程；[src/cli.rs](src/cli.rs) — clap 参数
- [src/clipboard.rs](src/clipboard.rs) — arboard 读剪贴板；[src/typer.rs](src/typer.rs) — enigo 键入
- feature `hotkey` — 常驻热键模式（global-hotkey，未实装）

## 关键规则

1. **对话中文；代码注释日语；commit/PR/README/错误提示英文**（开源项目）。
2. **绝不在日志/错误/输出里泄露剪贴板内容**（可能是密码），`--dry-run` 是唯一例外。
3. 三平台必须能编译；提交前 `cargo fmt` + `cargo clippy -- -D warnings`。
4. macOS 键入需辅助功能授权，错误提示要引导用户授权。
5. 保持小而专，抵制范围蔓延和多余依赖。
