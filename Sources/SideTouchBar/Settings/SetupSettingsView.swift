import SwiftUI

/// Which settings tab is shown; first launch opens the setup checklist.
@MainActor
final class SettingsNavigation: ObservableObject {
    static let shared = SettingsNavigation()

    enum Tab: Hashable {
        case setup, general, ai, buttons, media
    }

    @Published var tab: Tab = .general
}

/// First-run checklist: language, permissions with what each is for, launch
/// at login, and whether the app's signature keeps permissions across rebuilds.
struct SetupSettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var center = PermissionCenter.shared
    @ObservedObject private var navigation = SettingsNavigation.shared

    var body: some View {
        Form {
            Section {
                Picker(tr("语言 / Language"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                row(
                    tr("辅助功能"),
                    detail: tr("必需：发送快捷键和媒体键、点击菜单、识别 fn 键、读取标签页"),
                    granted: permissions.isTrusted,
                    action: Permissions.openSettings
                )
                row(
                    tr("麦克风"),
                    detail: tr("语音输入：按住麦克风按钮说话"),
                    granted: center.microphone.isGranted,
                    action: center.requestMicrophone
                )
                row(
                    tr("语音识别"),
                    detail: tr("语音输入：把说的话转成文字，优先本机离线识别"),
                    granted: center.speech.isGranted,
                    action: center.requestSpeech
                )
                row(
                    tr("屏幕录制"),
                    detail: tr("截图发给 AI：框选屏幕区域"),
                    granted: center.screenRecording.isGranted,
                    action: center.requestScreenRecording
                )
            } header: {
                Text(tr("权限"))
            } footer: {
                Text(tr("只有辅助功能是必需的，其他权限在用到对应功能时再授权也可以。"))
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(isOn: Binding(get: { center.launchAtLogin }, set: { center.setLaunchAtLogin($0) })) {
                    Text(tr("登录时启动"))
                    if center.launchAtLoginNeedsApproval {
                        Text(tr("需要在系统设置的“登录项”里允许"))
                    }
                }
            } header: {
                Text(tr("启动"))
            }

            Section {
                LabeledContent {
                    if center.hasStableSignature {
                        Label(tr("已使用固定签名"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Text(tr("临时签名")).foregroundStyle(.orange)
                    }
                } label: {
                    Text(tr("应用签名"))
                    Text(tr("临时签名的应用每次重新构建后，系统可能要求重新授权。在项目目录运行 scripts/create-signing-identity.sh 一次即可固定签名。"))
                }
            } header: {
                Text(tr("开发"))
            }

            Section {
                Button(tr("设置 AI 状态提醒…")) { navigation.tab = .ai }
                Button(tr("自定义按钮…")) { navigation.tab = .buttons }
            } header: {
                Text(tr("接下来"))
            }
        }
        .formStyle(.grouped)
        .onAppear { center.startWatching() }
        .onDisappear { center.stopWatching() }
    }

    private func row(_ title: String, detail: String, granted: Bool, action: @escaping () -> Void) -> some View {
        LabeledContent {
            if granted {
                Label(tr("已授权"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button(tr("授权…"), action: action)
            }
        } label: {
            Text(title)
            Text(detail)
        }
    }
}
