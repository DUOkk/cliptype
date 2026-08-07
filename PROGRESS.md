# PROGRESS.md — cliptype 进度记录

> 最新在上；绝对日期；记录实质进展、技术决策、卡点。规则见 [AGENTS.md](AGENTS.md)。

## 2026-08-07

- **v0.1.0 正式发布**（用户亲自验证 App 后拍板）：
  https://github.com/Szyoo/cliptype/releases/tag/v0.1.0 ——六个产物全部构建成功
  （macOS app universal zip + CLI 三平台四包 + sha256），已下载 app 包核验：
  双架构 fat binary、三语 lproj 齐全、签名标识正确。CHANGELOG 0.1.0 定稿。
- **发行与文档重构（用户要求）**：
  1. README 改为**中文默认**（README.md 中文 + README.en.md 英文镜像）。
  2. 安装章节明确区分 macOS 两种方式并各配教程：方式一装 Cliptype.app（授权
     Cliptype 一处）；方式二终端 CLI（授权终端 App）。两种授权互相独立。
  3. Release 增加 macOS 应用打包物：`bundle-macos.sh` 支持 `BUILD_UNIVERSAL=1`
     （rust 双 target + lipo，swift `--arch arm64 --arch x86_64`），release
     workflow 新增 build-macos-app 任务，产出
     `cliptype-<tag>-macos-app-universal.zip`（ditto 打包 + sha256）。
- **国际化（用户要求）**：
  1. README 双语：README.md（英）+ README.zh-CN.md（中），顶部互链切换。
  2. App 界面本地化 en/zh-Hans/ja：SwiftPM `defaultLocalization` + `Resources/*.lproj`
     + `L()` 助手（键=英文原文，`Bundle.module` 查找），bundle 脚本同捆
     `CliptypeApp_CliptypeApp.bundle`，Info.plist 声明 CFBundleLocalizations。
     已实测：`--args -AppleLanguages "(zh-Hans)"/"(ja)"` 菜单分别显示中/日文。
     字体无需处理——macOS 系统字体自带全语言覆盖。
- **App 形态调整（用户反馈）**：
  1. 增加**应用本体主窗口**（状态头部 + 设置表单），去掉 LSUIElement——现在是常规
     应用：Dock 有图标、启动显示窗口、关窗后菜单栏继续常驻、点 Dock 或菜单
     "Open Cliptype…" 重开窗口（WindowGroup 的标准 reopen 行为）。
  2. **授权弹窗不再每次启动自动弹**：只在"从未授权过"的首次使用弹（UserDefaults
     记录 hasEverBeenTrusted）。重打包导致授权失效的场景不再突袭弹窗，由菜单警告
     项（点击会触发系统弹窗+打开系统设置）和设置窗口引导。
- **修复：授权后菜单栏仍显示"授予权限"警告**（用户实测发现）。两个叠加原因：
  1. UI bug：菜单内容里直接调用 `AXIsProcessTrusted()`，不是可观察状态，权限变化
     后 MenuBarExtra 不会重新渲染（Settings 窗口因后打开而显示正确）。修复：权限
     状态提升为 AppState 的 `@Published var axTrusted`，2 秒轮询刷新（授权/撤销
     都能反映）。
  2. TCC 陷阱：ad-hoc 签名每次重新打包 cdhash 都变，macOS 视为不同应用，**之前的
     授权直接失效**（系统设置里开关看似还开着但不生效）。缓解：bundle 脚本支持
     `CODESIGN_ID` 环境变量（自签证书可保持授权跨构建有效）；ad-hoc 时脚本提示用
     `tccutil reset Accessibility io.github.szyoo.cliptype` 清掉陈旧条目再重新授权。
- **方向修正（用户）+ Phase 5 macOS 原生应用骨架完成**：CLI 定位改为"功能验证 +
  Linux 形态"，最终产品是平台原生应用；macOS 要"应用本体（设置窗口）+ 常驻菜单栏"。
  - 架构决定：SwiftUI App（`app/macos/`，SwiftPM）负责 UI/热键/权限引导，Rust 二进制
    同捆为键入引擎（按热键时以 `--delay 0` 单次模式调用）。键入的坑（IME/尾部丢字/
    换行 Tab）留在 Rust 一处，Swift 不重复实现。TCC 只需授权 Cliptype.app 一处。
  - `scripts/bundle-macos.sh` → dist/Cliptype.app（LSUIElement 菜单栏应用、ad-hoc 签名）。
  - 已端到端验证：模拟 ⌃⇧V → Carbon 热键 → 等修饰键松开 → 引擎 → TextEdit 键入
    正确（日文/emoji）。菜单栏图标、Settings 窗口、暂停/速度切换就绪。
  - 调试备忘：`log show --predicate` 看不到 NSLog 的场景下，直接在终端跑
    `Cliptype.app/Contents/MacOS/CliptypeApp` 从 stderr 看日志最快。
  - 待办：应用图标、任意热键录制、开机自启、release 产物集成、Windows 原生界面。

- **v0.1.0 发布撤回**（用户反馈：尚未亲自验证，不到 release 的程度——发布这类对外
  动作以后必须先经用户确认）。GitHub Release 与 tag 均已删除，CHANGELOG 回退为
  Unreleased。release workflow 本身保留且已验证可用，等用户真机验证后重新打 tag。
  工件格式决定：CLI 阶段维持 tar.gz/zip 内置裸二进制（ripgrep/gh 等同款惯例；
  Windows zip 里就是 cliptype.exe）；.pkg/.msi 安装器需要付费签名证书否则
  Gatekeeper/SmartScreen 警告更吓人，列为远期可选项。
- **Phase 4 发布准备完成（基础设施）**：
  - `--speed fast|normal|slow` 预设（映射 0/20/50ms，与托盘菜单一致；与 `--interval`
    互斥，clap conflicts_with，带单元测试）。
  - [release.yml](.github/workflows/release.yml)：`v*` tag 触发，四个 target
    （macOS arm64/x64 + Windows x64 + Linux x64），macOS/Windows 带 tray，Linux 带
    hotkey；tar.gz/zip + sha256，softprops/action-gh-release 建 Release。
  - CHANGELOG Unreleased → 0.1.0。crates.io / Homebrew 暂缓（计划里本来就是可选）。
- **Phase 3.5 状态栏/托盘 UI 实装完成并 macOS 全链路真机验证**（`--features tray`）。
  用户决策：macOS/Windows 各自原生界面、打包互不包含对方——用 tray-icon（各平台
  原生 API 薄封装）+ Cargo target-specific dependencies 天然满足；Linux 不支持托盘
  （GTK 依赖太重），CLI/热键模式不受影响。实现要点：
  1. **菜单状态必须主线程改**：引入 tao 事件循环（tray 特性专用依赖），
     `MenuEvent::set_event_handler` → `EventLoopProxy::send_event` 回主线程处理；
     托盘图标须在 `StartCause::Init` 后创建；`ActivationPolicy::Accessory` 隐藏 Dock。
  2. global-hotkey 在 tao 的 NSApp 事件循环下正常触发（与 Carbon
     RunApplicationEventLoop 等效，验证过）。
  3. 菜单：热键显示 / Pause（CheckMenuItem 点击自动翻转，读 is_checked 即可）/
     速度预设 Fastest·20ms·50ms（手动 radio）/ Quit。图标是代码画的 32x32 键盘
     glyph（macOS template image 自动适配深浅色，无外部资源）。
  4. 设置持久化 [src/config.rs](src/config.rs)：std 手写 key=value（带单元测试），
     `~/.config/cliptype/config.toml`；interval 决定顺序 = CLI 非零值 > 配置 > 0。
  验证（AppleScript UI automation）：图标出现、菜单结构、Pause 后热键无输出、
  恢复后正常、切速度写盘、Quit 干净退出。Windows 侧编译由 CI 覆盖，待实机验证。
- **Phase 3 常驻热键模式实装完成并真机验证**（`--features hotkey`）。
  `cliptype --hotkey [COMBO]`，默认 `ctrl+shift+v`，组合键字符串用 global-hotkey 的
  FromStr（支持 `ctrl+shift+v` 简写）。结构：主线程注册 + 跑平台事件循环，worker
  线程收 crossbeam channel 事件，每次按下现读剪贴板→键入；单次失败只打日志不退出。
  两个关键实现点：
  1. **macOS 事件循环必须用 Carbon 的 `RunApplicationEventLoop()`**，不能用裸
     `CFRunLoopRun()`——global-hotkey 把 handler 装在 `GetApplicationEventTarget()`
     上，裸 run loop 不分发应用目标事件（实测：CFRunLoopRun 下热键完全无响应）。
  2. **键入前等修饰键松开**：macOS 轮询 `CGEventSourceFlagsState`（HID 状态，上限
     2s + 50ms 余量），其他平台固定等 300ms，避免用户还按着 Ctrl/Shift 时合成事件
     被物理修饰键污染。
  验证：AppleScript System Events 模拟 ctrl+shift+v（合成按键能触发
  RegisterEventHotKey），TextEdit 中两次触发均正确键入（含日文/emoji）。
  CI 增加 `--features hotkey` 构建与 `--all-features` clippy/test。
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
