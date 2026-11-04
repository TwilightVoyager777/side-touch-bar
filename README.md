# Side Touch Bar

把以前 MacBook Touch Bar 竖过来放到屏幕右侧，为将来的触屏 MacBook 准备。采用 macOS 26 的液态玻璃（Liquid Glass）风格。界面支持中文和英文。

> **English**: Side Touch Bar brings the MacBook Touch Bar back as a vertical Liquid Glass bar on the right edge of the screen, designed for touch screens: esc, app controls and the Control Strip, unified playback controls, AI coding helpers (approve agent prompts, voice input, status alerts), and per-app buttons. The interface is available in English and Chinese (Settings › Start › Language). Build with `scripts/build-app.sh`, test with `scripts/test.sh`.

## 功能

布局和原版 Touch Bar 一致，从左到右变成从上到下：**esc → 应用控件 → 控制条**。

- **控制条（Control Strip）**
  - 收起时：默认亮度、音量、静音、Siri，可在设置里自定义（最多 6 个）
  - 展开后（Touch Bar 默认完整控制条）：亮度 ±、调度中心、启动台、键盘背光 ±、上一首/播放/下一首、音量 ±、静音、Siri；展开时占用应用控件的位置
  - 点亮度、音量、键盘背光会变成竖向滑条
  - 可选按钮：截屏、锁屏、显示桌面、聚焦搜索、夜览、深色模式、切换输入法、表情与符号、快捷指令、屏幕保护程序、睡眠、播放/暂停
- **应用控件**：跟随当前应用变化，按钮多的应用分成几页，顶部的按钮切换页面；其他应用显示通用按钮
  - **表情**：点表情按钮，应用控件变成可滚动的表情列表，点一下直接输入到当前应用，最近用过的排在前面
- **编程工具**：VS Code / Cursor / Windsurf / Zed、JetBrains 全系（IDEA、WebStorm、PyCharm、GoLand、CLion、Rider、Android Studio…）、Xcode
  - 分页：运行（运行、调试、停止、断点、终端、发给 AI）/ 导航（快速打开、转到定义、查找引用、返回前进、下一个错误）/ 编辑（注释、格式化、重命名、快速修复、面板）/ Git（JetBrains）/ AI（Cursor、Copilot 对话）
  - **调试页**：调试时会根据菜单状态自动切换到继续、单步跳过/进入/跳出、断点
- **浏览器**：分页：浏览 / **标签页**（列出打开的标签页，点击切换）/ 页面（**触控滚动区**、顶部底部、缩放、查找）/ 工具（下载、历史、书签、阅读模式、开发者工具）/ 网站（设置里的常用网站）；可以把当前网页发给 AI
- **AI 编程**
  - 终端里运行 Claude Code、Codex、OpenCode、Gemini 时：**是 / 总是允许 / 否**、切换模式、语音输入、截图、快捷输入（提示词和斜杠命令），"更多"页有回退、切换模型、后台、任务清单等
  - Claude、OpenCode、ChatGPT 桌面版：新会话、搜索、切换会话、侧边栏、终端、改动（按菜单名称点击，不怕快捷键变化）
  - **语音输入**：按住麦克风说话，松开后转成文字输入（优先本机离线识别）
  - **把选中代码发给 AI**：带上文件路径和代码格式，粘贴到最近使用的 AI（不会自动发送）
  - **状态提醒**（需要在设置里安装）：边缘把手变色（橙色等你确认、绿色完成、蓝色运行中），需要确认时侧边栏自动滑出，可以直接点是/否；会话列表点击跳到对应终端；Claude Code 还能显示上下文用量
- **正在播放**（所有应用统一样式）：当前应用在播放视频或音乐时，应用控件自动换成播放控件：专辑封面、标题、可拖动的进度条和时间、上一首/播放/下一首（视频是快退/快进，步长可设置）、音量滑条
  - **更多**：倍速（0.5–2×）、全屏、画中画、字幕；音乐是随机、循环、喜欢
  - **音频输出**：切换扬声器、耳机、AirPods、显示器、AirPlay
  - 专门的播放器（音乐、Spotify、QuickTime、IINA、VLC、TV、播客等）暂停时也会显示
  - 其他应用在后台播放时，控制条里会出现"正在播放"按钮（显示该应用的图标），点开是同样的播放控件
- **自定义按钮**：在设置的"按钮"页给任意应用加按钮：从它的菜单里选、录一个快捷键，或者输入一段文字
- **触屏**
  - 危险操作要**长按 0.6 秒**才生效（锁屏、睡眠、删除、关闭标签页、Git 推送、"总是允许"…），按住时一圈进度环填满
  - 音量、亮度、缩放、快进快退、撤销等**按住连续触发**，越按越快
  - 控制条的亮度、音量、键盘背光：点一下打开滑条，**按住上下拖动直接调节**
  - **文字编辑页**：在输入框里自动出现，有光标触控区（像 iPhone 按住空格键那样拖动光标）、选择/按词开关、全选、删除一个词、拷贝粘贴撤销
  - 从屏幕边缘**往里滑**唤出，在栏上**往外滑**收起，点边缘的把手也能唤出
- **中英文界面**：设置 › 开始 › 语言，切换后立即生效
- **首次引导**：设置的"开始"页列出所有权限和用途、登录时启动、签名状态
- **触控栏显示**（和原版系统设置一样）：应用控件与控制条 / 展开的控制条 / 应用控件 / F1、F2 等键 / 快速操作（你的快捷指令）/ 空间（各个桌面，点击切换）
- **按住 fn（🌐）键**：临时切换到设置里选的模式（默认 F1–F12），松开恢复；侧边栏隐藏时会自动滑出
- **总是显示 F1–F12 的应用**：在这些应用里默认显示 F 键，按住 fn 显示应用控件
- **交互**：平时自动隐藏，屏幕边缘只露一条细把手；鼠标或手指碰到边缘就滑出，离开或闲置后收起。点击不会抢走当前应用的焦点。
- **外观**：玻璃效果（常规 / 清透），颜色（跟随系统 / 浅色 / 深色）
- **显示器适配**：可以选显示在主显示器、内建显示器，或者跟随鼠标

## 尺寸与显示器适配

尺寸以 14/16 英寸 MacBook Pro 的默认分辨率为基准：按钮 44pt，约 8.8mm，适合手指点按。

- **按物理尺寸换算**：读取每块显示器的实际尺寸，让按钮在不同屏幕和缩放设置下保持差不多的实际大小（14/16 寸选"更多空间"时按钮变成 52pt，选"更大字体"时是 38–39pt，实际都约 8.8mm）
- **按高度自动收缩**：在当前屏幕上测量侧边栏最高的状态（每种应用预设、展开的控制条、滑条、fn 键），放不下就整体缩小，不会被切掉
- **尺寸档位**：设置里可以在自动尺寸的基础上选小 / 标准 / 大

查看各种常见屏幕下的计算结果：

```bash
swift build && .build/debug/SideTouchBar --sizing-report
```

## 构建与运行

需要 macOS 26 或更高版本，只需要 Command Line Tools（不需要 Xcode）：

```bash
scripts/build-app.sh          # 生成 build/SideTouchBar.app
open build/SideTouchBar.app
```

首次启动会打开设置的"开始"页。之后可以从菜单栏图标进入"设置…"（⌘,）。

### 固定签名（推荐）

默认是临时签名，每次重新构建后系统可能要求重新授权。运行一次：

```bash
scripts/create-signing-identity.sh
```

它会在登录钥匙串里创建一个本机自签名证书"SideTouchBar Local Signing"，之后 `build-app.sh` 会自动用它签名，权限不再丢失。第一次用它签名时系统会询问是否允许 codesign 使用这个密钥，选"始终允许"。

### 测试

```bash
scripts/test.sh
```

先检查英文翻译表（没有重复、没有遗漏），再运行测试：状态提醒的安装与移除（全部在临时文件夹里，不碰真实配置）、会话状态变化、AI 程序识别、数据模型、尺寸计算、翻译占位符。

## 权限

发送快捷键、媒体键、esc、输入表情，以及识别 fn 键，都需要 **辅助功能** 权限：系统设置 → 隐私与安全性 → 辅助功能 → 打开 SideTouchBar。
没有权限时，侧边栏会显示一个橙色警告按钮，设置窗口里也有授权入口。

> 用 ad-hoc 签名时，每次重新构建签名都会变，系统可能会认为是新应用，导致权限失效。
> 遇到这种情况，在设置里删除 SideTouchBar 再重新添加，或者执行
> `tccutil reset Accessibility com.dest1ny.SideTouchBar`。
> 如果有开发者证书，可以用 `SIGN_IDENTITY="Apple Development: …" scripts/build-app.sh` 避免这个问题。

## 状态提醒的安装

在设置的"AI 编程"页按需安装，装之前会说明会改哪个文件，并先备份：

| 工具 | 改动 |
|---|---|
| Claude Code 状态 | 在 `~/.claude/settings.json` 的 `hooks` 里给 9 个事件各加一条后台命令（`async`，不拖慢 Claude Code） |
| Claude Code 上下文用量 | 把 `statusLine` 换成包装脚本，记录数据后照常输出你原来的状态栏 |
| OpenCode 状态 | 新建 `~/.config/opencode/plugins/sidetouchbar.js`，不改配置文件 |
| Codex 完成提醒 | 在 `~/.codex/config.toml` 开头加一行 `notify`（已有 notify 时不修改） |

这些命令只在 Side Touch Bar 运行时才写入事件，事件放在 `~/Library/Application Support/SideTouchBar/agents/`。随时可以在设置里移除。

## 开发者自定义

- 应用按钮、完整控制条、F 键：`Sources/SideTouchBar/Actions/AppPresets.swift`；编程工具：`IDEPresets.swift`；AI：`Sources/SideTouchBar/AI/AIPresets.swift`
  - 每个 `AppPreset` 用 `bundleIDs` 匹配应用（查看 bundle ID：`osascript -e 'id of app "Safari"'`），新增后加到 `all` 数组
- 收起控制条的可选按钮：`ControlItem`（`Sources/SideTouchBar/Actions/BarItem.swift`）

## 目录结构

```
Sources/SideTouchBar/
  App/       应用入口、菜单栏、设置数据
  Settings/  设置窗口
  Bar/       侧边面板（NSPanel）、展开/收起逻辑
  UI/        液态玻璃风格的 SwiftUI 视图
  Actions/   按钮定义、各应用预设（含编程工具）与执行
  AI/        AI 场景识别、AI 按钮、语音输入、会话状态与集成安装
  System/    快捷键、菜单点击、文字输入、进程、媒体键、音量与音频输出、亮度、键盘背光、夜览、深色模式、空间、快捷指令、表情、正在播放、浏览器标签页、权限
Helpers/     读取"正在播放"信息的小库（由 build-app.sh 编译进应用）
```

## 说明

- 选"跟随鼠标"时，两块显示器相邻的那条边不容易停住鼠标，所以那一侧比较难唤出侧边栏。
- macOS 不允许给侧边栏"预留"屏幕区域，所以它浮在窗口上方，并默认自动隐藏。
- 程序坞放在右侧时会和侧边栏冲突，建议把程序坞放在底部。
- 很多第三方外接键盘的 fn 键只在键盘内部起作用，不会通知系统，这类键盘上按住 fn 不会切换触控栏。
- "空间"切换桌面用的是 ⌃← / ⌃→（系统默认开启）；跳到较远的桌面时会连续切换几次。
- 原版 Touch Bar 的输入建议、文本格式、照片缩略图滑条，内容来自各个应用自己；没有 Touch Bar 硬件时应用不会生成这些内容，所以做不了。
- 这台 macOS 27 上，控制中心不再通过辅助功能接口暴露菜单栏图标，所以没有"通知中心""控制中心""勿扰模式"按钮。
- "正在播放"：macOS 15.4 起，系统只把播放信息提供给苹果签名的程序，所以应用会让系统自带的 `/usr/bin/perl` 加载 `Helpers/NowPlayingHelper.m` 编译出的小库来读取（播放/暂停、拖动进度不受限制，直接发送）。这是一种绕过办法，以后的 macOS 可能会封掉，或者移除自带的 perl。
- 亮度、键盘背光、夜览、深色模式用到了系统私有接口（和系统自带按键走同一套），不同 macOS 版本可能失效，失效时会退回到模拟按键。
- 编程工具的按钮按各工具 macOS 默认快捷键配置，开发机上没有安装这些 IDE，没有实测；调试页的自动切换依赖菜单的可用状态，有的应用只在打开菜单时才刷新，这时用顶部按钮手动切换。ChatGPT 桌面版同样没有实测。
- Codex 的按键（y / a）和状态提醒、OpenCode 终端里的确认按键（回车 / esc）没有实测。
- 触控滚动区是用 ↑ / ↓ 方向键滚动网页的；光标在输入框里时会移动光标而不是滚动。
- 截图发给 AI 用的是系统 `screencapture`，第一次使用时系统可能要求给 Side Touch Bar 屏幕录制权限。
- 侧边栏收起时，菜单状态、输入框、终端里的 AI 检查和音量读取都会暂停，以省电。
- 只用 Command Line Tools 时，SwiftPM 默认的构建系统偶尔加载不到测试用的宏插件，所以 `scripts/test.sh` 用原生构建系统并显式指定路径。
- 界面文字以中文为源语言，英文翻译在 `Sources/SideTouchBar/App/L10n+English.swift`；新增界面文字后运行 `scripts/check-l10n.py` 检查是否漏翻。
- 代码没有使用 SwiftUI 的 `@State`：Command Line Tools 缺少它所需的宏插件，视图状态都放在 `BarState` 等 `ObservableObject` 里。
