import Carbon.HIToolbox
import SwiftUI

/// The browser's open tabs as a scrolling column; the current one is highlighted.
struct BrowserTabsView: View {
    @ObservedObject private var store = BrowserTabsStore.shared
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        VStack(spacing: metrics.spacing) {
            BarButton(icon: .symbol("plus"), help: "新标签页") {
                ActionRunner.run(.keys(KeyCombo(kVK_ANSI_T, .maskCommand)))
            }
            ScrollViewReader { proxy in
                ScrollingColumn {
                    if store.tabs.isEmpty {
                        Text("读取不到标签页")
                            .font(.system(size: metrics.captionSize))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, metrics.spacing * 2)
                    }
                    ForEach(store.tabs) { tab in
                        TextButton(title: tab.title.isEmpty ? "标签页" : tab.title, help: tab.title, tint: tab.isSelected ? .accentColor : nil) {
                            store.select(tab)
                        }
                        .id(tab.id)
                    }
                }
                .onChange(of: store.tabs.first(where: \.isSelected)?.id) { _, selected in
                    if let selected { withAnimation { proxy.scrollTo(selected, anchor: .center) } }
                }
            }
        }
        .onAppear { store.startWatching() }
        .onDisappear { store.stopWatching() }
    }
}

/// Drag up and down to scroll the page, for fingers on a touch screen.
/// Sends ↑/↓ key presses, which scroll the page in every browser.
struct ScrollPadView: View {
    @ObservedObject var state: BarState
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: metrics.buttonSize / 2, style: .continuous)
        VStack(spacing: 5 * metrics.scale) {
            Image(systemName: "chevron.up").font(.system(size: metrics.captionSize, weight: .semibold))
            ForEach(0..<3, id: \.self) { _ in
                Capsule().fill(Color.primary.opacity(0.25)).frame(width: metrics.buttonSize * 0.45, height: 2)
            }
            Image(systemName: "chevron.down").font(.system(size: metrics.captionSize, weight: .semibold))
        }
        .foregroundStyle(.secondary)
        .frame(width: metrics.buttonSize, height: metrics.buttonSize * 3)
        .background(shape.fill(Color.primary.opacity(0.07)))
        .contentShape(shape)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    state.isInteracting = true
                    let step = 14 * metrics.scale
                    let steps = Int((gesture.translation.height - state.scrollPadOffset) / step)
                    guard steps != 0 else { return }
                    state.scrollPadOffset += CGFloat(steps) * step
                    // Dragging up moves the page up, like a touch screen.
                    let key = steps > 0 ? kVK_UpArrow : kVK_DownArrow
                    for _ in 0..<min(abs(steps), 6) {
                        KeySender.send(KeyCombo(key))
                    }
                }
                .onEnded { _ in
                    state.isInteracting = false
                    state.scrollPadOffset = 0
                }
        )
        .help("上下拖动来滚动网页")
    }
}

/// Favorite sites from settings, opened in the current browser.
struct FavoriteSitesColumn: View {
    @ObservedObject private var settings = Settings.shared
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        ScrollingColumn {
            if settings.favoriteSites.isEmpty {
                Text("在设置的“按钮”里添加常用网站")
                    .font(.system(size: metrics.captionSize))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, metrics.spacing * 2)
            }
            ForEach(settings.favoriteSites) { site in
                TextButton(title: site.title.isEmpty ? site.url : site.title, help: site.url) {
                    ActionRunner.run(.openURL(site.url))
                }
            }
        }
    }
}

/// Moves the text cursor by dragging, like holding the space bar on iPhone:
/// sideways for characters (or words), up and down for lines. "Select"
/// holds Shift, "By word" holds Option.
struct CursorPadView: View {
    @ObservedObject var state: BarState
    @Environment(\.barMetrics) private var metrics

    var body: some View {
        VStack(spacing: metrics.spacing) {
            BarButton(icon: .symbol("selection.pin.in.out"), help: "选择（移动时选中文字）", tint: state.textSelecting ? .accentColor : nil) {
                state.textSelecting.toggle()
            }
            BarButton(icon: .text(L10n.isEnglish ? "Wd" : "词"), help: "按词移动", tint: state.textByWord ? .accentColor : nil) {
                state.textByWord.toggle()
            }
            pad
        }
    }

    private var pad: some View {
        let shape = RoundedRectangle(cornerRadius: metrics.buttonSize / 2, style: .continuous)
        return Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
            .font(.system(size: metrics.symbolSize, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: metrics.buttonSize, height: metrics.buttonSize * 2)
            .background(shape.fill(Color.primary.opacity(0.07)))
            .contentShape(shape)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        state.isInteracting = true
                        let step = 12 * metrics.scale
                        let dx = Int((gesture.translation.width - state.cursorPadOffset.width) / step)
                        let dy = Int((gesture.translation.height - state.cursorPadOffset.height) / (step * 1.6))
                        var flags: CGEventFlags = []
                        if state.textSelecting { flags.insert(.maskShift) }
                        if state.textByWord { flags.insert(.maskAlternate) }
                        if dx != 0 {
                            state.cursorPadOffset.width += CGFloat(dx) * step
                            send(dx > 0 ? kVK_RightArrow : kVK_LeftArrow, count: abs(dx), flags: flags)
                        }
                        if dy != 0 {
                            state.cursorPadOffset.height += CGFloat(dy) * step * 1.6
                            send(dy > 0 ? kVK_DownArrow : kVK_UpArrow, count: abs(dy), flags: flags.subtracting(.maskAlternate))
                        }
                    }
                    .onEnded { _ in
                        state.isInteracting = false
                        state.cursorPadOffset = .zero
                    }
            )
            .help(tr("拖动移动光标：左右按字（或按词），上下按行"))
    }

    private func send(_ key: Int, count: Int, flags: CGEventFlags) {
        guard Permissions.shared.isTrusted else { return }
        for _ in 0..<min(count, 8) { KeySender.send(KeyCombo(key, flags)) }
    }
}
