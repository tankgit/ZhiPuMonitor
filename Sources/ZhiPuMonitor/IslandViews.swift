import SwiftUI

// MARK: - Island Root View

struct IslandRootView: View {
    @ObservedObject var viewModel: UsageViewModel
    @ObservedObject var islandState: IslandState
    let notchInfo: NotchInfo

    private let barHeight: CGFloat = 32
    private let expandedContentHeight: CGFloat = 300
    private let noKeyContentHeight: CGFloat = 100

    var body: some View {
        // ZStack isolates the bar layer from expanded content layer changes.
        // When expanded content appears via `if`, the bar layer is unaffected.
        ZStack(alignment: .topLeading) {
            // Bar layer — always at top, independent of expanded content
            IslandBarView(viewModel: viewModel, islandState: islandState)
                .frame(height: barHeight)
                .frame(maxWidth: .infinity)

            // Expanded content layer — starts below bar
            if islandState.isExpanded {
                let contentHeight = viewModel.hasApiKey ? expandedContentHeight : noKeyContentHeight
                VStack(spacing: 0) {
                    Spacer().frame(height: barHeight + 4)  // skip bar area + connector

                    ExpandedContentView(
                        viewModel: viewModel,
                        state: PanelState(),
                        onClose: {
                            NotificationCenter.default.post(name: .init("IslandCollapse"), object: nil)
                        },
                        hideMascot: true
                    )
                    .padding(.horizontal, 12)
                    .frame(height: contentHeight, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
        // cornerRadius 20 → naturally clamped to capsule (16) when short, grows with height
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Island Bar View

struct IslandBarView: View {
    @ObservedObject var viewModel: UsageViewModel
    @ObservedObject var islandState: IslandState

    private var noData: Bool { !viewModel.hasApiKey || viewModel.fiveHourLimit == nil }
    /// Fixed frame for each ring group — ring stays at the same spot whether text is shown or not.
    /// Ring center at 5+11 = 16px from edge (concentric with capsule corner radius 16).
    /// When expanded, 2px more inward and 2px down for breathing room.
    private var groupWidth: CGFloat { islandState.isExpanded ? 58 : 56 }
    private var edgePad: CGFloat { islandState.isExpanded ? 7 : 5 }
    private var yShift: CGFloat { islandState.isExpanded ? 2 : 0 }

    var body: some View {
        HStack(spacing: 0) {
            // Left group: ring anchored at left, text fills remaining space
            HStack(spacing: 4) {
                RingIndicator(
                    label: "5h",
                    percentage: noData ? 100 : (viewModel.fiveHourLimit?.percentage ?? 0),
                    color: noData ? .gray.opacity(0.25) : (viewModel.fiveHourLimit?.progressColor ?? .gray.opacity(0.3))
                )
                if islandState.isHovered || islandState.isExpanded, !noData, let lim = viewModel.fiveHourLimit {
                    Text("\(lim.percentage)%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: islandState.isHovered)
            .frame(width: groupWidth, alignment: .leading)
            .padding(.leading, edgePad)
            .offset(y: yShift)

            Spacer(minLength: 0)

            // Center: mascot
            PixelMascot(state: mascotState, percentage: viewModel.maxPercentage)

            Spacer(minLength: 0)

            // Right group: ring anchored at right, text fills remaining space
            HStack(spacing: 4) {
                if islandState.isHovered || islandState.isExpanded, !noData, let lim = viewModel.weeklyLimit {
                    Text("\(lim.percentage)%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .transition(.opacity)
                }
                RingIndicator(
                    label: "1w",
                    percentage: noData ? 100 : (viewModel.weeklyLimit?.percentage ?? 0),
                    color: noData ? .gray.opacity(0.25) : (viewModel.weeklyLimit?.progressColor ?? .gray.opacity(0.3))
                )
            }
            .animation(.easeInOut(duration: 0.15), value: islandState.isHovered)
            .frame(width: groupWidth, alignment: .trailing)
            .padding(.trailing, edgePad)
            .offset(y: yShift)
        }
    }

    private var mascotState: MascotState {
        if !viewModel.hasApiKey { return .noKey }
        if viewModel.fiveHourLimit?.percentage == 100 ||
            viewModel.weeklyLimit?.percentage == 100 ||
            viewModel.mcpLimit?.percentage == 100 {
            return .exhausted
        }
        if case .unsafe = viewModel.fiveHourSafety { return .warning }
        if case .unsafe = viewModel.weeklySafety { return .warning }
        if case .unsafe = viewModel.mcpSafety { return .warning }
        return .safe
    }
}

// MARK: - Hotkey Recorder View

struct HotkeyRecorderView: View {
    @AppStorage("app_language") private var appLanguage: String = "zh"
    @State private var isRecording = false
    @State private var displayText: String = ""
    @State private var localMonitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Text(isRecording ? L.hotkeyRecording : displayText)
                .font(.system(size: 11, weight: isRecording ? .medium : .regular, design: .monospaced))
                .foregroundColor(isRecording ? .orange : .secondary)
                .frame(minWidth: 120, alignment: .leading)

            Button(action: toggleRecording) {
                Text(isRecording ? "✕" : L.hotkeyRecord)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isRecording ? .red : .accentColor)
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            updateDisplayText()
        }
    }

    private func updateDisplayText() {
        let mods = UserDefaults.standard.integer(forKey: "island_hotkey_modifiers")
        let kc = UserDefaults.standard.integer(forKey: "island_hotkey_keycode")
        let effectiveMods: UInt = mods == 0 ? (NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue) : UInt(mods)
        let effectiveKC: UInt16 = kc == 0 ? 0x1D : UInt16(kc)
        displayText = HotkeyHelper.toString(modifiers: effectiveMods, keycode: effectiveKC)
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape cancels
            if event.keyCode == 0x35 {
                stopRecording()
                return nil
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Ignore bare modifier key presses
            if modifiers.isEmpty || event.keyCode == 0x3A /* Control */ || event.keyCode == 0x3D /* Option */
                || event.keyCode == 0x38 /* Shift */ || event.keyCode == 0x37 /* Command */ {
                return nil
            }

            // Record
            UserDefaults.standard.set(Int(modifiers.rawValue), forKey: "island_hotkey_modifiers")
            UserDefaults.standard.set(Int(event.keyCode), forKey: "island_hotkey_keycode")
            updateDisplayText()
            stopRecording()

            // Notify AppDelegate to re-register
            NotificationCenter.default.post(name: .init("HotkeyChanged"), object: nil)

            return nil
        }
    }

    private func stopRecording() {
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
        isRecording = false
    }
}

// MARK: - Hotkey Helper

struct HotkeyHelper {
    static func toString(modifiers: UInt, keycode: UInt16) -> String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.control) { parts.append("Ctrl") }
        if flags.contains(.option) { parts.append("Opt") }
        if flags.contains(.shift) { parts.append("Shift") }
        if flags.contains(.command) { parts.append("Cmd") }
        parts.append(keyToString(keycode))
        return parts.joined(separator: " + ")
    }

    static func keyToString(_ keycode: UInt16) -> String {
        switch keycode {
        case 0x00: return "A"; case 0x01: return "S"; case 0x02: return "D"; case 0x03: return "F"
        case 0x04: return "H"; case 0x05: return "G"; case 0x06: return "Z"; case 0x07: return "X"
        case 0x08: return "C"; case 0x09: return "V"; case 0x0B: return "B"; case 0x0C: return "Q"
        case 0x0D: return "W"; case 0x0E: return "E"; case 0x0F: return "R"
        case 0x10: return "Y"; case 0x11: return "T"; case 0x12: return "1"; case 0x13: return "2"
        case 0x14: return "3"; case 0x15: return "4"; case 0x16: return "6"; case 0x17: return "7"
        case 0x18: return "8"; case 0x19: return "9"; case 0x1A: return "0"; case 0x1B: return "-"
        case 0x1C: return "5"; case 0x1D: return "0"
        case 0x24: return "Enter"; case 0x25: return "Tab"; case 0x26: return "Space"
        case 0x27: return "Delete"; case 0x28: return "Esc"
        case 0x30: return "Tab"; case 0x31: return "Space"; case 0x33: return "Delete"
        case 0x35: return "Esc"
        case 0x7A: return "F1"; case 0x78: return "F2"; case 0x63: return "F3"; case 0x76: return "F4"
        case 0x60: return "F5"; case 0x61: return "F6"; case 0x62: return "F7"; case 0x64: return "F8"
        case 0x65: return "F9"; case 0x6D: return "F10"; case 0x67: return "F11"; case 0x6F: return "F12"
        default: return "Key(\(keycode))"
        }
    }
}
