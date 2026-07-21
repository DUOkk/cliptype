# PROGRESS.md — cliptype 进度记录

> 最新在上；绝对日期；记录实质进展、技术决策、卡点。规则见 [AGENTS.md](AGENTS.md)。

## 2026-07-21

- 制定项目文档体系：AGENTS.md（权威指引）、CLAUDE.md（精简镜像）、
  [docs/implementation-plan.md](docs/implementation-plan.md)（分 4 个 Phase 的实施计划）、本文件。
- 确定核心设计原则：绝不在输出中泄露剪贴板内容（`--dry-run` 除外）；
  语言规范为对话中文 / 注释日语 / commit 与用户可见文本英文。
- 仓库已推送到 GitHub（https://github.com/Szyoo/cliptype ，分支 `main`），
  占位符 USERNAME 已替换为 Szyoo，CI（三平台 fmt+clippy+build+test）已触发。
- 当前状态：脚手架完成；`clipboard::read_text()` 和 `typer::type_text()` 仍是
  `bail!` 的 stub。下一步：Phase 1（实装这两个函数 + 换行归一化 + macOS 实测）。
