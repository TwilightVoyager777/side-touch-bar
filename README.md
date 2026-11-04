# Side Touch Bar

把以前 MacBook Touch Bar 的体验搬到屏幕左右两侧，为将来的触屏 MacBook 准备。采用 macOS 26 的液态玻璃（Liquid Glass）风格。

## 功能

- **布局**：仅左侧 / 左右两侧 / 仅右侧，在设置里切换
  - 两侧：一侧是系统控制条，另一侧是 esc、fn 和当前应用的按钮（可以选控制条在哪一侧）
  - 单侧：应用按钮和控制条合并在同一条里，和原来的 Touch Bar 一样；展开控制条或打开 fn 时会暂时占满整条
- **控制条（Control Strip）**
  - 收起时：默认亮度、音量、静音、Siri，可在设置里自定义（最多 6 个）
  - 展开后（Touch Bar 默认完整控制条）：亮度 ±、调度中心、启动台、键盘背光 ±、上一首/播放/下一首、音量 ±、静音、Siri
  - 点亮度、音量、键盘背光会变成竖向滑条
  - 可选按钮：截屏、锁屏、显示桌面、聚焦搜索、夜览、深色模式、切换输入法、表情与符号、快捷指令、睡眠、播放/暂停
- **应用区域**：esc、fn（F1–F12），以及跟随当前应用变化的按钮：浏览器、Finder、终端、VS Code/Cursor/Zed、Xcode、音乐类、邮件、日历、预览、信息、备忘录、文本编辑、Keynote/PowerPoint，其他应用显示通用按钮
- **交互**：平时自动隐藏，屏幕边缘只露一条细把手；鼠标或手指碰到边缘就滑出，离开或闲置后收起。点击不会抢走当前应用的焦点。
- **外观**：玻璃效果（常规 / 清透），颜色（跟随系统 / 浅色 / 深色）

## 构建与运行

需要 macOS 26 或更高版本，只需要 Command Line Tools（不需要 Xcode）：

```bash
scripts/build-app.sh          # 生成 build/SideTouchBar.app
open build/SideTouchBar.app
```

首次启动会打开设置窗口。之后可以从菜单栏图标进入"设置…"（⌘,）。

## 权限

发送快捷键、媒体键和 esc 需要 **辅助功能** 权限：系统设置 → 隐私与安全性 → 辅助功能 → 打开 SideTouchBar。
没有权限时，侧边栏会显示一个橙色警告按钮，设置窗口里也有授权入口。

> 用 ad-hoc 签名时，每次重新构建签名都会变，系统可能会认为是新应用，导致权限失效。
> 遇到这种情况，在设置里删除 SideTouchBar 再重新添加，或者执行
> `tccutil reset Accessibility com.dest1ny.SideTouchBar`。
> 如果有开发者证书，可以用 `SIGN_IDENTITY="Apple Development: …" scripts/build-app.sh` 避免这个问题。

## 自定义按钮

- 应用按钮、完整控制条、F 键：`Sources/SideTouchBar/Actions/AppPresets.swift`
  - 每个 `AppPreset` 用 `bundleIDs` 匹配应用（查看 bundle ID：`osascript -e 'id of app "Safari"'`），新增后加到 `all` 数组
- 收起控制条的可选按钮：`ControlItem`（`Sources/SideTouchBar/Actions/BarItem.swift`）

## 目录结构

```
Sources/SideTouchBar/
  App/       应用入口、菜单栏、设置数据
  Settings/  设置窗口
  Bar/       侧边面板（NSPanel）、展开/收起逻辑
  UI/        液态玻璃风格的 SwiftUI 视图
  Actions/   按钮定义、各应用预设与执行
  System/    快捷键、媒体键、音量（CoreAudio）、亮度、键盘背光、夜览、深色模式、权限
```

## 说明

- 侧边栏显示在主屏幕（带菜单栏的那块屏）上。
- macOS 不允许给侧边栏"预留"屏幕区域，所以它浮在窗口上方，并默认自动隐藏。
- 程序坞放在左侧或右侧时会和侧边栏冲突，建议把程序坞放在底部。
- 亮度、键盘背光、夜览、深色模式用到了系统私有接口（和系统自带按键走同一套），不同 macOS 版本可能失效，失效时会退回到模拟按键。
- 代码没有使用 SwiftUI 的 `@State`：Command Line Tools 缺少它所需的宏插件，视图状态都放在 `BarState` 等 `ObservableObject` 里。
