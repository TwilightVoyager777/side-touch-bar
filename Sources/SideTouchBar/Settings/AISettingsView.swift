import SwiftUI

struct AISettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var integration = AgentIntegration.shared

    var body: some View {
        Form {
            Section {
                Toggle("AI 编程按钮", isOn: $settings.aiEnabled)
                Picker("发送选中代码、网页、截图到", selection: $settings.aiSendTarget) {
                    ForEach(AISendTarget.allCases) { Text($0.title).tag($0) }
                }
                Picker("语音输入语言", selection: $settings.voiceLanguage) {
                    ForEach(VoiceLanguage.allCases) { Text($0.title).tag($0) }
                }
            } header: {
                Text("AI 编程")
            } footer: {
                Text("在 Claude、OpenCode、ChatGPT 桌面版，或终端里运行 Claude Code、Codex、OpenCode 时，应用控件会换成 AI 按钮：确认、中断、切换模式、语音输入、截图、快捷输入。")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("需要确认时自动弹出侧边栏", isOn: $settings.aiAutoReveal)
                Toggle("完成时播放提示音", isOn: $settings.aiSoundOnDone)

                integrationRow(
                    "Claude Code 状态",
                    detail: "在 ~/.claude/settings.json 里加入后台钩子",
                    installed: integration.claudeHooksInstalled,
                    available: integration.isClaudeAvailable,
                    install: {
                        guard confirm(
                            "安装 Claude Code 状态提醒？",
                            "会在 ~/.claude/settings.json 的 hooks 里为 \(AgentIntegration.claudeEvents.count) 个事件各加一条后台命令（async，不会拖慢 Claude Code），并先把原文件备份到同一目录。随时可以在这里移除。",
                            action: "安装"
                        ) else { return }
                        try integration.installClaudeHooks()
                    },
                    uninstall: integration.uninstallClaudeHooks
                )

                integrationRow(
                    "Claude Code 上下文用量",
                    detail: "替换状态栏，并保留你原来的状态栏输出",
                    installed: integration.claudeStatusLineInstalled,
                    available: integration.isClaudeAvailable,
                    install: {
                        guard confirm(
                            "安装上下文用量？",
                            "会把 ~/.claude/settings.json 的 statusLine 换成一个包装脚本：它记录模型、上下文用量和花费给侧边栏，然后照常输出你原来的状态栏（没有的话显示模型和上下文百分比）。会先备份原文件，移除时恢复原来的设置。",
                            action: "安装"
                        ) else { return }
                        try integration.installClaudeStatusLine()
                    },
                    uninstall: integration.uninstallClaudeStatusLine
                )

                integrationRow(
                    "OpenCode 状态",
                    detail: "在 ~/.config/opencode/plugins/ 放一个插件",
                    installed: integration.openCodeInstalled,
                    available: integration.isOpenCodeAvailable,
                    install: {
                        guard confirm(
                            "安装 OpenCode 状态提醒？",
                            "会新建 ~/.config/opencode/plugins/sidetouchbar.js，OpenCode 会自动加载它。不修改你的 OpenCode 配置文件。",
                            action: "安装"
                        ) else { return }
                        try integration.installOpenCode()
                    },
                    uninstall: integration.uninstallOpenCode
                )

                integrationRow(
                    "Codex 完成提醒",
                    detail: "在 ~/.codex/config.toml 加入 notify",
                    installed: integration.codexInstalled,
                    available: integration.isCodexAvailable,
                    install: {
                        guard confirm(
                            "安装 Codex 完成提醒？",
                            "会在 ~/.codex/config.toml 开头加一行 notify，并先备份原文件。如果你已经设置了 notify，则不会修改。",
                            action: "安装"
                        ) else { return }
                        try integration.installCodex()
                    },
                    uninstall: integration.uninstallCodex
                )
            } header: {
                Text("状态提醒")
            } footer: {
                Text("安装后，侧边栏收起时边缘的把手会变色：橙色是等你确认，绿色是完成了，蓝色闪烁是正在运行。需要确认时侧边栏会滑出，可以直接点“是 / 否”。")
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach($settings.aiSnippets) { $snippet in
                    HStack(spacing: 8) {
                        TextField("按钮", text: $snippet.title)
                            .frame(width: 90)
                        TextField("输入的内容", text: $snippet.text)
                        Toggle("回车", isOn: $snippet.submit)
                            .toggleStyle(.checkbox)
                        Button {
                            settings.aiSnippets.removeAll { $0.id == snippet.id }
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button("添加") {
                    settings.aiSnippets.append(AISnippet(title: "新按钮", text: "", submit: true))
                }
            } header: {
                HStack {
                    Text("快捷输入")
                    Spacer()
                    Button("恢复默认") { settings.aiSnippets = AISnippet.defaults }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            } footer: {
                Text("显示在 AI 页面底部，点一下就输入。勾选“回车”会顺便发送，适合 /compact 这类斜杠命令。")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { integration.refresh() }
    }

    private func integrationRow(
        _ title: String,
        detail: String,
        installed: Bool,
        available: Bool,
        install: @escaping () throws -> Void,
        uninstall: @escaping () throws -> Void
    ) -> some View {
        LabeledContent {
            if installed {
                HStack {
                    Label("已安装", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    Button("移除") { run(uninstall) }
                }
            } else if available {
                Button("安装…") { run(install) }
            } else {
                Text("未检测到").foregroundStyle(.secondary)
            }
        } label: {
            Text(title)
            Text(detail)
        }
    }

    private func run(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            showError(error)
        }
    }
}
