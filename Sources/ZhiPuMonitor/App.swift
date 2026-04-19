import SwiftUI
import Combine
import IOKit
import ServiceManagement

@main
struct ZhiPuMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

class PanelState: ObservableObject {
    @Published var isExpanded = false
    @Published var isHovered = false
    @Published var showSettings = false
}

class IslandState: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var isBarVisible: Bool = true
    @Published var isHovered: Bool = false
    @Published var isExpanded: Bool = false
}

// MARK: - Notch Detection

struct NotchInfo {
    let width: CGFloat
    let height: CGFloat
    let centerX: CGFloat
    let screenTopY: CGFloat
    let menuBarHeight: CGFloat

    static func detect() -> NotchInfo? {
        guard let screen = NSScreen.main else { return nil }
        let safeTop = screen.safeAreaInsets.top
        guard safeTop > 0 else { return nil }
        let frame = screen.frame
        let visibleTop = screen.visibleFrame.origin.y + screen.visibleFrame.height
        let menuBarH = frame.maxY - visibleTop
        return NotchInfo(
            width: detectWidth(screen: screen),
            height: safeTop,
            centerX: frame.midX,
            screenTopY: frame.maxY,
            menuBarHeight: menuBarH
        )
    }

    static func fallback() -> NotchInfo {
        guard let screen = NSScreen.main else {
            return NotchInfo(width: 186, height: 32, centerX: 960, screenTopY: 800, menuBarHeight: 24)
        }
        let frame = screen.frame
        let visibleTop = screen.visibleFrame.origin.y + screen.visibleFrame.height
        let menuBarH = frame.maxY - visibleTop
        return NotchInfo(
            width: 186,
            height: 32,
            centerX: frame.midX,
            screenTopY: frame.maxY,
            menuBarHeight: menuBarH
        )
    }

    private static func detectWidth(screen: NSScreen) -> CGFloat {
        let model = getModelIdentifier()
        if let w = modelMap[model] { return w }
        let sw = screen.frame.width
        if sw < 1460 { return 186 }
        if sw < 1500 { return 154 }
        if sw < 1600 { return 186 }
        return 204
    }

    private static func getModelIdentifier() -> String {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice")
        )
        defer { IOObjectRelease(service) }
        guard let ref = IORegistryEntryCreateCFProperty(
            service, "model" as CFString, kCFAllocatorDefault, 0
        ) else { return "" }
        if let data = ref.takeRetainedValue() as? Data,
           let str = String(data: data, encoding: .utf8) {
            return str.trimmingCharacters(in: .controlCharacters)
        }
        return ""
    }

    private static let modelMap: [String: CGFloat] = [
        "MacBookPro18,3": 186, "MacBookPro18,4": 186,
        "Mac14,5": 186, "Mac14,6": 186,
        "Mac15,3": 186, "Mac15,4": 186, "Mac15,5": 186, "Mac16,1": 186,
        "MacBookPro18,1": 204, "MacBookPro18,2": 204,
        "Mac14,3": 204, "Mac14,4": 204,
        "Mac15,6": 204, "Mac15,7": 204, "Mac15,8": 204, "Mac16,2": 204,
        "Mac14,2": 154, "Mac15,12": 154, "Mac16,12": 154,
        "Mac14,15": 186, "Mac15,13": 186,
    ]
}

// MARK: - Clipping Container

private class ClipView: NSView {
    override var clipsToBounds: Bool { get { true } set { } }
}

// MARK: - Key Panel (allows text input without stealing app focus)

private class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: KeyPanel!
    private var viewModel: UsageViewModel!
    private let state = PanelState()
    private var notchInfo: NotchInfo!

    // Island mode
    private var islandState = IslandState()
    private var islandPanel: KeyPanel?

    private var refreshTimer: Timer?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    // Hotkey
    private var hotkeyGlobalMonitor: Any?
    private var hotkeyLocalMonitor: Any?

    private let expandedWidth: CGFloat = 420
    /// Compact width = notch width + space for ring indicators on each side
    private var compactWidth: CGFloat { notchInfo.width + 88 }
    /// Hover width = compact + space for percentage labels on each side
    private var hoverWidth: CGFloat { notchInfo.width + 160 }
    private let curvePadding: CGFloat = 12  // horizontal breathing room for curves
    private let expandedContentHeight: CGFloat = 300
    private let noKeyContentHeight: CGFloat = 100
    private let topExtra: CGFloat = 12

    // Island dimensions
    private let islandBarWidth: CGFloat = 180
    private let islandBarHeight: CGFloat = 32
    private let islandGap: CGFloat = 4
    private let islandExpandedContentHeight: CGFloat = 260
    private let islandNoKeyContentHeight: CGFloat = 100

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        viewModel = UsageViewModel()

        // Read island mode setting
        islandState.isEnabled = UserDefaults.standard.bool(forKey: "island_mode_enabled")

        if islandState.isEnabled {
            // Island mode: notch detection optional
            notchInfo = NotchInfo.detect() ?? NotchInfo.fallback()
            setupIslandPanel()
        } else {
            guard let info = NotchInfo.detect() else { return }
            notchInfo = info
            setupPanel()
        }

        setupMouseMonitoring()
        registerGlobalHotkey()
        startAutoRefresh()

        // Listen for mode/hotkey changes from settings
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleIslandModeChanged),
            name: .init("IslandModeChanged"), object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleHotkeyChanged),
            name: .init("HotkeyChanged"), object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleIslandCollapse),
            name: .init("IslandCollapse"), object: nil
        )

        if viewModel.hasApiKey {
            Task { await viewModel.fetchUsage() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let m = globalMouseMonitor { NSEvent.removeMonitor(m) }
        if let m = localMouseMonitor { NSEvent.removeMonitor(m) }
        if let m = hotkeyGlobalMonitor { NSEvent.removeMonitor(m) }
        if let m = hotkeyLocalMonitor { NSEvent.removeMonitor(m) }
        refreshTimer?.invalidate()
    }

    // MARK: - Notch Panel

    private func setupPanel() {
        let info = notchInfo!
        let pw = compactWidth + curvePadding * 2

        let origin = NSPoint(
            x: info.centerX - pw / 2,
            y: info.screenTopY - info.menuBarHeight
        )
        let compactSize = NSSize(width: pw, height: topExtra + info.menuBarHeight)

        panel = KeyPanel(
            contentRect: NSRect(origin: origin, size: compactSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: 26)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let container = ClipView(frame: NSRect(origin: .zero, size: compactSize))
        container.wantsLayer = true
        container.layer?.backgroundColor = .clear

        let rootView = NotchRootView(
            viewModel: viewModel, state: state,
            notchInfo: info,
            sideInset: curvePadding,
            topExtra: topExtra,
            compactHeight: info.menuBarHeight,
            expandedContentHeight: expandedContentHeight,
            noKeyContentHeight: noKeyContentHeight
        )
        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = NSRect(origin: .zero, size: compactSize)
        hosting.autoresizingMask = [.minYMargin, .width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        container.addSubview(hosting)

        panel.contentView = container
        panel.orderFront(nil)
    }

    // MARK: - Island Panel

    private func setupIslandPanel() {
        let info = notchInfo!
        let frame = islandBarFrame()

        islandPanel = KeyPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        islandPanel!.isFloatingPanel = true
        islandPanel!.level = NSWindow.Level(rawValue: 26)
        islandPanel!.isOpaque = false
        islandPanel!.backgroundColor = .clear
        islandPanel!.hasShadow = false
        islandPanel!.ignoresMouseEvents = true
        islandPanel!.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let container = ClipView(frame: NSRect(origin: .zero, size: frame.size))
        container.wantsLayer = true
        container.layer?.backgroundColor = .clear

        let rootView = IslandRootView(
            viewModel: viewModel,
            islandState: islandState,
            notchInfo: info
        )
        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        hosting.autoresizingMask = [.minYMargin, .width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        container.addSubview(hosting)

        islandPanel!.contentView = container
        islandPanel!.orderFront(nil)
    }

    // MARK: - Mouse

    private func setupMouseMonitoring() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.handleMouseMoved()
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseMoved()
            return event
        }
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            self?.handleClick()
            return event
        }
    }

    private func handleMouseMoved() {
        let mouse = NSEvent.mouseLocation
        Task { @MainActor in
            if islandState.isEnabled {
                handleIslandMouseMoved(mouse: mouse)
            } else {
                handleNotchMouseMoved(mouse: mouse)
            }
        }
    }

    @MainActor private func handleNotchMouseMoved(mouse: NSPoint) {
        let noKey = !viewModel.hasApiKey
        if state.isExpanded {
            if panel.frame.insetBy(dx: -10, dy: -10).contains(mouse) { return }
            collapseAll()
        } else if state.isHovered {
            if !panel.frame.insetBy(dx: -4, dy: -4).contains(mouse) { unhover() }
        } else {
            if panel.frame.contains(mouse) {
                if noKey {
                    expand()
                } else {
                    hover()
                }
            }
        }
    }

    @MainActor private func handleIslandMouseMoved(mouse: NSPoint) {
        guard islandState.isBarVisible, let ip = islandPanel else { return }

        // Capsule hit area within the panel
        let capsuleHitFrame = NSRect(
            x: ip.frame.midX - islandBarWidth / 2,
            y: ip.frame.minY,
            width: islandBarWidth,
            height: islandBarHeight
        )

        if islandState.isExpanded {
            if ip.frame.insetBy(dx: -10, dy: -10).contains(mouse) { return }
            islandCollapseAll()
        } else if islandState.isHovered {
            if !capsuleHitFrame.insetBy(dx: -4, dy: -4).contains(mouse) { islandUnhover() }
        } else {
            if capsuleHitFrame.contains(mouse) {
                if !viewModel.hasApiKey {
                    islandExpand()
                } else {
                    islandHover()
                }
            }
        }
    }

    private func handleClick() {
        Task { @MainActor in
            if islandState.isEnabled {
                guard !islandState.isExpanded, islandState.isHovered, viewModel.hasApiKey else { return }
                islandExpand()
            } else {
                guard !state.isExpanded, state.isHovered, viewModel.hasApiKey else { return }
                expand()
            }
        }
    }

    // MARK: - Notch State transitions

    private func hover() {
        state.isHovered = true
        panel.ignoresMouseEvents = false
        let frame = hoverFrame()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.panel.animator().setFrame(frame, display: true)
        }
    }

    private func unhover() {
        state.isHovered = false
        let frame = compactFrame()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.panel.animator().setFrame(frame, display: true)
        } completionHandler: {
            self.panel.ignoresMouseEvents = true
        }
    }

    private func expand() {
        state.isExpanded = true
        panel.ignoresMouseEvents = false
        panel.hasShadow = true

        let ef = expandedFrame()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            self.panel.animator().setFrame(ef, display: true)
        }
    }

    private func collapseAll() {
        state.isExpanded = false
        state.isHovered = false
        let cf = compactFrame()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 1, 1)
            self.panel.animator().setFrame(cf, display: true)
        }, completionHandler: {
            self.panel.ignoresMouseEvents = true
            self.panel.hasShadow = false
        })
    }

    // MARK: - Island State transitions

    private func islandHover() {
        islandState.isHovered = true
        islandPanel?.ignoresMouseEvents = false
        // No frame change — percentages show within existing capsule space
    }

    private func islandUnhover() {
        islandState.isHovered = false
        // No frame change — just hide percentages
        islandPanel?.ignoresMouseEvents = true
    }

    private func islandExpand() {
        islandState.isExpanded = true
        islandState.isHovered = true
        islandPanel?.ignoresMouseEvents = false
        islandPanel?.hasShadow = true

        let frame = islandExpandedFrame()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            self.islandPanel?.animator().setFrame(frame, display: true)
        }
    }

    private func islandCollapseAll() {
        islandState.isExpanded = false
        islandState.isHovered = false
        let frame = islandBarFrame()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 1, 1)
            self.islandPanel?.animator().setFrame(frame, display: true)
        }, completionHandler: {
            self.islandPanel?.ignoresMouseEvents = true
            self.islandPanel?.hasShadow = false
        })
    }

    // MARK: - Island Bar Toggle (hotkey)

    private func toggleIslandBar() {
        if islandState.isBarVisible {
            // Slide up: hide
            let info = notchInfo!
            let hideY = info.screenTopY - info.menuBarHeight + islandGap
            let hideFrame = NSRect(
                x: info.centerX - islandBarWidth / 2,
                y: hideY,
                width: islandBarWidth,
                height: islandBarHeight
            )
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                self.islandPanel?.animator().setFrame(hideFrame, display: true)
            }, completionHandler: {
                self.islandPanel?.orderOut(nil)
                self.islandState.isBarVisible = false
            })
        } else {
            // Slide down: show
            let barFrame = islandBarFrame()
            let info = notchInfo!
            let startFrame = NSRect(
                x: info.centerX - islandBarWidth / 2,
                y: info.screenTopY - info.menuBarHeight + islandGap,
                width: islandBarWidth,
                height: islandBarHeight
            )
            islandState.isExpanded = false
            islandState.isHovered = false
            islandState.isBarVisible = true
            islandPanel?.setFrame(startFrame, display: true)
            islandPanel?.orderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.islandPanel?.animator().setFrame(barFrame, display: true)
            }
        }
    }

    // MARK: - Notch Frame helpers

    private func compactFrame() -> NSRect {
        let pw = compactWidth + curvePadding * 2
        return NSRect(
            x: notchInfo.centerX - pw / 2,
            y: notchInfo.screenTopY - notchInfo.menuBarHeight,
            width: pw,
            height: topExtra + notchInfo.menuBarHeight
        )
    }

    private func hoverFrame() -> NSRect {
        let hw = hoverWidth + curvePadding * 2
        return NSRect(
            x: notchInfo.centerX - hw / 2,
            y: notchInfo.screenTopY - notchInfo.menuBarHeight,
            width: hw,
            height: topExtra + notchInfo.menuBarHeight
        )
    }

    private func expandedFrame() -> NSRect {
        let ew = expandedWidth + curvePadding * 2
        let hasKey = !(UserDefaults.standard.string(forKey: "zhipu_api_key") ?? "").isEmpty
        let ch: CGFloat = hasKey ? expandedContentHeight : noKeyContentHeight
        return NSRect(
            x: notchInfo.centerX - ew / 2,
            y: notchInfo.screenTopY - notchInfo.menuBarHeight - ch,
            width: ew,
            height: topExtra + notchInfo.menuBarHeight + ch
        )
    }

    // MARK: - Island Frame helpers

    private func islandBarFrame() -> NSRect {
        let info = notchInfo!
        return NSRect(
            x: info.centerX - islandBarWidth / 2,
            y: info.screenTopY - info.menuBarHeight - islandGap - islandBarHeight,
            width: islandBarWidth,
            height: islandBarHeight
        )
    }

    private func islandExpandedFrame() -> NSRect {
        let info = notchInfo!
        let hasKey = !(UserDefaults.standard.string(forKey: "zhipu_api_key") ?? "").isEmpty
        let ch: CGFloat = hasKey ? islandExpandedContentHeight : islandNoKeyContentHeight
        let totalHeight = islandBarHeight + 4 + ch  // bar + connector + content
        return NSRect(
            x: info.centerX - expandedWidth / 2,
            y: info.screenTopY - info.menuBarHeight - islandGap - totalHeight,
            width: expandedWidth,
            height: totalHeight
        )
    }

    // MARK: - Auto Refresh

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.viewModel.hasApiKey else { return }
                await self.viewModel.fetchUsage()
            }
        }
    }

    // MARK: - Global Hotkey

    private func registerGlobalHotkey() {
        let modsRaw = UserDefaults.standard.integer(forKey: "island_hotkey_modifiers")
        let kcRaw = UserDefaults.standard.integer(forKey: "island_hotkey_keycode")
        let effectiveMods: NSEvent.ModifierFlags = modsRaw == 0
            ? [.control, .option]
            : NSEvent.ModifierFlags(rawValue: UInt(modsRaw))
        let effectiveKC: UInt16 = kcRaw == 0 ? 0x1D : UInt16(kcRaw)

        hotkeyGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == effectiveMods,
               event.keyCode == effectiveKC {
                self?.handleHotkey()
            }
        }

        hotkeyLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == effectiveMods,
               event.keyCode == effectiveKC {
                self?.handleHotkey()
                return nil  // consume
            }
            return event
        }
    }

    private func unregisterGlobalHotkey() {
        if let m = hotkeyGlobalMonitor { NSEvent.removeMonitor(m); hotkeyGlobalMonitor = nil }
        if let m = hotkeyLocalMonitor { NSEvent.removeMonitor(m); hotkeyLocalMonitor = nil }
    }

    private func handleHotkey() {
        Task { @MainActor in
            guard islandState.isEnabled else { return }
            if islandState.isExpanded {
                islandCollapseAll()
            } else {
                toggleIslandBar()
            }
        }
    }

    // MARK: - Notification Handlers

    @objc private func handleIslandModeChanged() {
        let enabled = UserDefaults.standard.bool(forKey: "island_mode_enabled")
        islandState.isEnabled = enabled

        if enabled {
            // Switch to island mode
            if notchInfo == nil {
                notchInfo = NotchInfo.detect() ?? NotchInfo.fallback()
            }
            panel?.orderOut(nil)
            if islandPanel == nil {
                setupIslandPanel()
            }
            islandPanel?.setFrame(islandBarFrame(), display: true)
            islandPanel?.orderFront(nil)
            islandState.isBarVisible = true
            islandState.isHovered = false
            islandState.isExpanded = false
        } else {
            // Switch to notch mode
            islandPanel?.orderOut(nil)
            islandState.isBarVisible = false
            islandState.isHovered = false
            islandState.isExpanded = false
            panel?.orderFront(nil)
        }
    }

    @objc private func handleHotkeyChanged() {
        unregisterGlobalHotkey()
        registerGlobalHotkey()
    }

    @objc private func handleIslandCollapse() {
        islandCollapseAll()
    }

    // MARK: - Settings Window

    private var settingsPanel: NSPanel?

    func openSettingsWindow() {
        if let panel = settingsPanel {
            panel.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsPanelContent(viewModel: viewModel)
        let hosting = NSHostingView(rootView: settingsView)
        hosting.frame = NSRect(x: 0, y: 0, width: 320, height: 520)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 520),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.title = L.settings
        panel.contentView = hosting
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.center()
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        self.settingsPanel = panel
        panel.orderFront(nil)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window == settingsPanel else { return }
        settingsPanel = nil
    }
}
