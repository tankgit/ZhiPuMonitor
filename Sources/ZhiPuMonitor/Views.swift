import SwiftUI
import ServiceManagement

// MARK: - Notch Shape

/// The top `headerHeight` px are full-width (hidden behind the screen notch).
/// At `headerHeight`, small fillet curves transition from horizontal to vertical,
/// then straight sides run down to concave bottom corners.
struct NotchShape: Shape {
    let topRadius: CGFloat
    let bottomRadius: CGFloat
    let sideInset: CGFloat
    let headerHeight: CGFloat   // portion that overlaps with the physical notch

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let tr = topRadius
        let br = bottomRadius
        let s = sideInset
        let hdr = headerHeight

        var path = Path()

        // ── Start at top-left (full width) ──
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: w, y: 0))              // top edge
        path.addLine(to: CGPoint(x: w, y: hdr))             // right side through header

        // Top-right curve: full width → narrowed body
        path.addQuadCurve(
            to: CGPoint(x: w - s, y: hdr + tr),
            control: CGPoint(x: w - s, y: hdr)
        )

        // Right side: straight down
        path.addLine(to: CGPoint(x: w - s, y: h - br))

        // Bottom-right concave corner
        path.addQuadCurve(to: CGPoint(x: w - s - br, y: h), control: CGPoint(x: w - s, y: h))

        // Bottom edge
        path.addLine(to: CGPoint(x: s + br, y: h))

        // Bottom-left concave corner
        path.addQuadCurve(to: CGPoint(x: s, y: h - br), control: CGPoint(x: s, y: h))

        // Left side: straight up to the curve start
        path.addLine(to: CGPoint(x: s, y: hdr + tr))

        // Top-left curve: narrowed body → full width
        path.addQuadCurve(
            to: CGPoint(x: 0, y: hdr),
            control: CGPoint(x: s, y: hdr)
        )

        // Close back to top-left
        path.addLine(to: CGPoint(x: 0, y: 0))

        return path
    }
}

// MARK: - Root View

struct NotchRootView: View {
    @ObservedObject var viewModel: UsageViewModel
    @ObservedObject var state: PanelState
    let notchInfo: NotchInfo
    let sideInset: CGFloat
    let topExtra: CGFloat
    let compactHeight: CGFloat
    let expandedContentHeight: CGFloat
    let noKeyContentHeight: CGFloat

    var body: some View {
        GeometryReader { geo in
            let contentWidth = geo.size.width - sideInset * 2
            let indicatorWidth = max(0, (contentWidth - notchInfo.width) / 2)

            VStack(spacing: 0) {
                Color.black.frame(height: topExtra)

                CompactIndicatorsBar(
                    viewModel: viewModel,
                    state: state,
                    notchInfo: notchInfo,
                    indicatorWidth: indicatorWidth
                )
                .frame(height: compactHeight)

                if state.isExpanded {
                    let contentHeight = viewModel.hasApiKey ? expandedContentHeight : noKeyContentHeight
                    ExpandedContentView(viewModel: viewModel, state: state)
                        .padding(.horizontal, 12)
                        .padding(.top, 14)
                        .frame(height: contentHeight, alignment: .topLeading)
                }
            }
            .padding(.horizontal, sideInset)
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color.black)
        .clipShape(NotchShape(
            topRadius: 16,
            bottomRadius: state.isExpanded ? 26 : 18,
            sideInset: sideInset,
            headerHeight: topExtra
        ))
    }
}

// MARK: - Ring Indicator

struct RingIndicator: View {
    let label: String
    let percentage: Int?
    let color: Color

    private let size: CGFloat = 22
    private let lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: progressFraction)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Center label
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }

    private var progressFraction: CGFloat {
        guard let p = percentage else { return 0 }
        return CGFloat(min(max(p, 0), 100)) / 100.0
    }
}

// MARK: - Compact Indicators

struct CompactIndicatorsBar: View {
    @ObservedObject var viewModel: UsageViewModel
    @ObservedObject var state: PanelState
    let notchInfo: NotchInfo
    let indicatorWidth: CGFloat

    private var noData: Bool { !viewModel.hasApiKey || viewModel.fiveHourLimit == nil }

    var body: some View {
        HStack(spacing: 0) {
            // Left: 5h ring + optional percentage
            HStack(spacing: 4) {
                RingIndicator(
                    label: "5h",
                    percentage: noData ? 100 : (viewModel.fiveHourLimit?.percentage ?? 0),
                    color: noData ? .gray.opacity(0.25) : (viewModel.fiveHourLimit?.progressColor ?? .gray.opacity(0.3))
                )
                if state.isHovered, !noData, let lim = viewModel.fiveHourLimit {
                    Text("\(lim.percentage)%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: state.isHovered)
            .padding(.leading, 6)
            .frame(width: indicatorWidth, alignment: .leading)

            Spacer(minLength: notchInfo.width)

            // Right: weekly ring + optional percentage
            HStack(spacing: 4) {
                if state.isHovered, !noData, let lim = viewModel.weeklyLimit {
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
            .animation(.easeInOut(duration: 0.15), value: state.isHovered)
            .padding(.trailing, 6)
            .frame(width: indicatorWidth, alignment: .trailing)
        }
    }
}

// MARK: - Expanded Content

struct ExpandedContentView: View {
    @ObservedObject var viewModel: UsageViewModel
    @ObservedObject var state: PanelState
    @AppStorage("app_language") private var appLanguage: String = "zh"
    var onClose: (() -> Void)? = nil
    var hideMascot: Bool = false

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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with mascot
            HStack(spacing: 8) {
                if !hideMascot {
                    PixelMascot(state: mascotState, percentage: viewModel.maxPercentage)
                }
                Text(L.titleText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                if viewModel.hasApiKey {
                    LevelBadge(level: viewModel.level)
                }
                Spacer()
                Button(action: { showSettingsWindow(viewModel: viewModel) }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
                Button(action: { onClose?() ?? NSApp.terminate(nil) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }

            // Sub-header: update time + refresh
            if viewModel.hasApiKey {
                HStack(spacing: 5) {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.mini)
                            .scaleEffect(0.5)
                            .frame(width: 10, height: 10)
                    }
                    Text(viewModel.isLoading ? L.refreshing : L.updatedAt(viewModel.lastUpdatedString))
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.25))
                    if !viewModel.isLoading {
                        Button(action: {
                            Task { await viewModel.fetchUsage() }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.25))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.top, 4)
                .padding(.bottom, 12)
            } else {
                Spacer().frame(height: 20)
            }

            // Content or placeholder
            if !viewModel.hasApiKey {
                // No API Key state
                Text(L.noApiKeyPrompt)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            } else {
                // 5-hour quota
                if let limit = viewModel.fiveHourLimit {
                    QuotaCard(
                        title: L.fiveHourQuota,
                        limit: limit,
                        safety: viewModel.fiveHourSafety
                    )
                }

                // Weekly quota
                if let limit = viewModel.weeklyLimit {
                    QuotaCard(
                        title: L.weeklyQuota,
                        limit: limit,
                        safety: viewModel.weeklySafety
                    )
                }

                // MCP
                if let limit = viewModel.mcpLimit {
                    MCPCard(limit: limit, safety: viewModel.mcpSafety)
                }
            }
        }
    }
}

// MARK: - App Version

let appVersion = "1.0.0"

// MARK: - Settings Tab Button

private struct SettingsTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Panel Content (independent floating window)

struct SettingsPanelContent: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var selectedTab = 0
    @AppStorage("app_language") private var appLanguage: String = "zh"

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                SettingsTabButton(title: L.general, icon: "gearshape", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                SettingsTabButton(title: L.help, icon: "questionmark.circle", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                SettingsTabButton(title: L.about, icon: "info.circle", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
            }
            .padding(.top, 12)

            Divider()

            // Tab content
            ScrollView {
                if selectedTab == 0 {
                    GeneralSettingsView(viewModel: viewModel)
                } else if selectedTab == 1 {
                    HelpView()
                } else {
                    AboutView()
                }
            }
        }
        .frame(minWidth: 320, minHeight: 420)
        .id(appLanguage)
        .onAppear { updateWindowTitle() }
        .onChange(of: appLanguage) { _ in updateWindowTitle() }
    }

    private func updateWindowTitle() {
        settingsWindowRef?.title = L.settings
    }
}

// MARK: - General Settings Tab

private struct GeneralSettingsView: View {
    @ObservedObject var viewModel: UsageViewModel
    @AppStorage("app_language") private var appLanguage: String = "zh"
    @AppStorage("launch_at_login") private var launchAtLogin: Bool = false
    @AppStorage("threshold_orange") private var thresholdOrange: Int = 60
    @AppStorage("threshold_red") private var thresholdRed: Int = 85
    @State private var inputKey = ""
    @State private var saveMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // API Key
            VStack(alignment: .leading, spacing: 6) {
                Text(L.apiKey)
                    .font(.system(size: 12, weight: .medium))
                HStack(spacing: 8) {
                    SecureField(L.apiKeyPlaceholder, text: $inputKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                    Button(L.update) {
                        guard !inputKey.isEmpty else { return }
                        viewModel.apiKey = inputKey
                        saveMessage = L.saving
                        Task {
                            await viewModel.fetchUsage()
                            if viewModel.errorMessage != nil {
                                saveMessage = L.connectFailed
                            } else if viewModel.hasApiKey {
                                saveMessage = L.updateSuccess
                            }
                        }
                    }
                    .disabled(inputKey.isEmpty)
                }
                HStack(spacing: 2) {
                    Text(L.noApiKey)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Button(action: {
                        if let url = URL(string: "https://bigmodel.cn/apikey/platform") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Text(L.getOne)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                if !saveMessage.isEmpty {
                    Text(saveMessage)
                        .font(.system(size: 10))
                        .foregroundColor(saveMessage == L.updateSuccess ? .green : .red)
                }
            }

            Divider()

            // Thresholds
            VStack(alignment: .leading, spacing: 8) {
                Text(L.thresholdTitle)
                    .font(.system(size: 12, weight: .medium))

                HStack(spacing: 0) {
                    VStack(alignment: .center, spacing: 2) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                        Text(L.safe)
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .center, spacing: 4) {
                        Text(L.orangeAlert)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                        TextField("", value: $thresholdOrange, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                            .frame(width: 52)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .center, spacing: 4) {
                        Text(L.redAlert)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.red)
                        TextField("", value: $thresholdRed, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                            .frame(width: 52)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 4)

                Text(L.thresholdDesc)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)

                if thresholdOrange <= 0 || thresholdOrange > 100 {
                    Text(L.orangeRangeError)
                        .font(.system(size: 9))
                        .foregroundColor(.red)
                } else if thresholdRed <= 0 || thresholdRed > 100 {
                    Text(L.redRangeError)
                        .font(.system(size: 9))
                        .foregroundColor(.red)
                } else if thresholdRed < thresholdOrange {
                    Text(L.redGeOrangeError)
                        .font(.system(size: 9))
                        .foregroundColor(.red)
                }
            }

            Divider()

            // Language
            HStack {
                Text(L.language)
                    .font(.system(size: 12))
                Spacer()
                Picker("", selection: $appLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            Divider()

            // Launch at login
            HStack {
                Text(L.launchAtLogin)
                    .font(.system(size: 12))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newVal in
                        launchAtLogin = newVal
                        do {
                            if newVal {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("LaunchAtLogin error: \(error)")
                        }
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            Divider()

            // Island Mode
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.islandMode)
                            .font(.system(size: 12))
                        Text(L.islandModeDesc)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { UserDefaults.standard.bool(forKey: "island_mode_enabled") },
                        set: { newVal in
                            UserDefaults.standard.set(newVal, forKey: "island_mode_enabled")
                            NotificationCenter.default.post(name: .init("IslandModeChanged"), object: nil)
                        }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }

                // Hotkey
                HStack {
                    Text(L.hotkey)
                        .font(.system(size: 12))
                    Spacer()
                    HotkeyRecorderView()
                }
            }

            Spacer()
        }
        .padding(20)
        .onAppear {
            inputKey = viewModel.apiKey
        }
    }
}

// MARK: - About Tab

private struct AboutView: View {
    @AppStorage("app_language") private var appLanguage: String = "zh"
    private var qrCodeImage: NSImage? {
        guard let path = Bundle.module.path(forResource: "qrcode", ofType: "jpg") else { return nil }
        return NSImage(contentsOfFile: path)
    }

    var body: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 8)

            // App icon
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 36))
                .foregroundColor(.accentColor)

            // App name
            Text("ZBar")
                .font(.system(size: 20, weight: .bold))

            // Version
            Text("v\(appVersion)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            // Description
            Text(L.appDescription)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer().frame(height: 4)

            // Info rows
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                    Text("GitHub")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        if let url = URL(string: "https://github.com/tankgit") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Text("tankgit")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 6) {
                    Image(systemName: "person")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                    Text(L.author)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Tank")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 4)

            // Tip separator
            HStack(spacing: 8) {
                Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 0.5)
                Text(L.buyCoffee)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 0.5)
            }
            .padding(.horizontal, 20)

            // QR code
            if let nsImage = qrCodeImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text(L.wechatTip)
                .font(.system(size: 9))
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Safety Badge

struct SafetyBadge: View {
    let safety: SafetyEstimate
    @State private var isHovered = false

    var body: some View {
        let badgeColor: Color = {
            switch safety {
            case .safe: return .green
            case .unsafe: return .orange
            case .unknown: return .gray
            }
        }()

        let badgeLabel: String = {
            switch safety {
            case .safe: return "SAFE"
            case .unsafe: return "WARN"
            case .unknown: return "—"
            }
        }()

        let hoverText: String = {
            switch safety {
            case .safe: return L.safeHover
            case .unsafe(let remaining): return L.unsafeHover(remaining)
            case .unknown: return L.unknownHover
            }
        }()

        Group {
            if isHovered {
                Text(hoverText)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(badgeColor.opacity(0.9))
                    .transition(.opacity)
            } else {
                Text(badgeLabel)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.black.opacity(0.85))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(badgeColor.opacity(0.85))
                    .cornerRadius(3)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Level Badge

struct LevelBadge: View {
    let level: String

    private var config: (icon: String?, color: Color, bg: Color) {
        let l = level.lowercased()
        if l.contains("max") {
            return ("crown.fill", Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.15))
        } else if l.contains("pro") {
            return ("flame.fill", .orange, .orange.opacity(0.15))
        } else {
            return (nil, .cyan, .cyan.opacity(0.12))
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            if let icon = config.icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
            }
            Text(level)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
        }
        .foregroundColor(config.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(config.bg)
        .cornerRadius(4)
    }
}

// MARK: - Quota Card

struct QuotaCard: View {
    let title: String
    let limit: QuotaLimit
    let safety: SafetyEstimate

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                Spacer()
                Text("\(limit.percentage)%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(limit.progressColor)
                    .monospacedDigit()
            }
            ProgressBar(value: Double(limit.percentage) / 100.0, color: limit.progressColor)
                .frame(height: 3)

            // Info line: reset time + safety badge
            HStack(spacing: 0) {
                if let reset = limit.resetTimeString {
                    Text(L.resetAt(reset))
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.35))
                }
                Spacer()
                Text(L.atCurrentRate)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.35))
                SafetyBadge(safety: safety)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 2)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
        .padding(.bottom, 6)
    }
}

// MARK: - MCP Card

struct MCPCard: View {
    let limit: QuotaLimit
    let safety: SafetyEstimate

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(L.mcpCalls)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                Spacer()
                if let cur = limit.currentValue, let total = limit.usage {
                    Text("\(cur)/\(total)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                }
                Text("\(limit.percentage)%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(limit.progressColor)
                    .monospacedDigit()
            }
            ProgressBar(value: Double(limit.percentage) / 100.0, color: limit.progressColor)
                .frame(height: 3)

            // Info line: reset time + safety badge
            HStack(spacing: 0) {
                if let reset = limit.resetTimeString {
                    Text(L.resetAt(reset))
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.35))
                }
                Spacer()
                Text(L.atCurrentRate)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.35))
                SafetyBadge(safety: safety)
            }

            if let details = limit.usageDetails, !details.isEmpty {
                FlowLayout(spacing: 5) {
                    ForEach(details, id: \.modelCode) { d in
                        Text("\(d.modelCode)·\(d.usage)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 2)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

// MARK: - Help Tab

private struct HelpView: View {
    @AppStorage("app_language") private var appLanguage: String = "zh"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Monster showcase
            VStack(alignment: .leading, spacing: 10) {
                Text(L.helpMonsterTitle)
                    .font(.system(size: 13, weight: .semibold))
                Text(L.helpMonsterDesc)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                monsterCard(
                    state: .noKey,
                    color: .gray.opacity(0.45),
                    colorName: L.helpSleepyColor,
                    name: L.helpSleepyName,
                    desc: L.helpSleepyDesc
                )
                monsterCard(
                    state: .safe,
                    color: .green,
                    colorName: L.helpHappyColor,
                    name: L.helpHappyName,
                    desc: L.helpHappyDesc
                )
                monsterCard(
                    state: .warning,
                    color: .orange,
                    colorName: L.helpNervousColor,
                    name: L.helpNervousName,
                    desc: L.helpNervousDesc,
                    percentage: 70
                )
                monsterCard(
                    state: .exhausted,
                    color: .red,
                    colorName: L.helpDeadColor,
                    name: L.helpDeadName,
                    desc: L.helpDeadDesc,
                    percentage: 95
                )
            }

            Divider()

            // Color legend
            VStack(alignment: .leading, spacing: 6) {
                Text(L.helpColorTitle)
                    .font(.system(size: 13, weight: .semibold))
                colorRow(color: .green, text: L.helpColorSafe)
                colorRow(color: .orange, text: L.helpColorWarn)
                colorRow(color: .red, text: L.helpColorDanger)
            }

            Divider()

            // Usage tips
            VStack(alignment: .leading, spacing: 10) {
                Text(L.helpUsageTitle)
                    .font(.system(size: 13, weight: .semibold))
                tipWithPreview(text: L.helpUsage1) {
                    miniNotchHover()
                }
                tipWithPreview(text: L.helpUsage2) {
                    miniExpandedPanel()
                }
                tipWithPreview(text: L.helpUsage3) {
                    miniBadgeHover()
                }
                tipWithPreview(text: L.helpUsage4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                tipWithPreview(text: L.helpUsage5) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(20)
    }

    private func monsterCard(state: MascotState, color: Color, colorName: String, name: String, desc: String, percentage: Int = 30) -> some View {
        HStack(spacing: 12) {
            PixelMascot(state: state, percentage: percentage)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 11, weight: .semibold))
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(colorName)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                Text(desc)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
    }

    private func colorRow(color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(text)
                .font(.system(size: 10))
        }
    }

    private func tipWithPreview<Preview: View>(text: String, @ViewBuilder preview: () -> Preview) -> some View {
        HStack(alignment: .center, spacing: 10) {
            preview()
                .frame(width: 100, height: 44)
            Text(text)
                .font(.system(size: 10))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(6)
    }

    // Mini mockup: notch with hover percentages
    private func miniNotchHover() -> some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            // Screen edge (dark bar)
            let bar = CGRect(x: 0, y: 0, width: w, height: h)
            ctx.fill(Path(bar), with: .color(Color.black))
            // Notch shape
            let notchW: CGFloat = 44
            let notchH: CGFloat = 16
            let nx = (w - notchW) / 2
            let notch = CGRect(x: nx, y: 0, width: notchW, height: notchH)
            ctx.fill(Path(roundedRect: notch, cornerRadius: 6), with: .color(Color(white: 0.08)))
            // Left ring
            let ringR: CGFloat = 5
            let lcx: CGFloat = nx - 14
            let lcy: CGFloat = notchH / 2
            let leftRing = Ellipse().path(in: CGRect(x: lcx - ringR, y: lcy - ringR, width: ringR * 2, height: ringR * 2))
            ctx.stroke(leftRing, with: .color(.green), lineWidth: 1.5)
            // Right ring
            let rcx: CGFloat = nx + notchW + 14
            let rightRing = Ellipse().path(in: CGRect(x: rcx - ringR, y: lcy - ringR, width: ringR * 2, height: ringR * 2))
            ctx.stroke(rightRing, with: .color(.orange), lineWidth: 1.5)
            // Percentage labels
            ctx.draw(Text("42%").font(.system(size: 7, weight: .bold, design: .rounded)).foregroundColor(.white),
                     at: CGPoint(x: lcx - 12, y: lcy + 10))
            ctx.draw(Text("67%").font(.system(size: 7, weight: .bold, design: .rounded)).foregroundColor(.white),
                     at: CGPoint(x: rcx + 12, y: lcy + 10))
        }
        .frame(width: 100, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // Mini mockup: expanded panel
    private func miniExpandedPanel() -> some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            // Background
            let bg = Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerRadius: 5)
            ctx.fill(bg, with: .color(Color(white: 0.12)))
            // Notch at top
            let nw: CGFloat = 28
            let nx = (w - nw) / 2
            ctx.fill(Path(roundedRect: CGRect(x: nx, y: 0, width: nw, height: 8), cornerRadius: 4),
                     with: .color(Color(white: 0.08)))
            // Title line
            ctx.fill(Path(roundedRect: CGRect(x: 8, y: 11, width: 50, height: 3), cornerRadius: 1),
                     with: .color(.white.opacity(0.5)))
            // Card 1
            ctx.fill(Path(roundedRect: CGRect(x: 6, y: 18, width: w - 12, height: 7), cornerRadius: 2),
                     with: .color(.white.opacity(0.08)))
            ctx.fill(Path(roundedRect: CGRect(x: 10, y: 21, width: w * 0.4, height: 1.5), cornerRadius: 0.5),
                     with: .color(.green))
            // Card 2
            ctx.fill(Path(roundedRect: CGRect(x: 6, y: 27, width: w - 12, height: 7), cornerRadius: 2),
                     with: .color(.white.opacity(0.08)))
            ctx.fill(Path(roundedRect: CGRect(x: 10, y: 30, width: w * 0.65, height: 1.5), cornerRadius: 0.5),
                     with: .color(.orange))
            // Card 3
            ctx.fill(Path(roundedRect: CGRect(x: 6, y: 36, width: w - 12, height: 7), cornerRadius: 2),
                     with: .color(.white.opacity(0.08)))
            ctx.fill(Path(roundedRect: CGRect(x: 10, y: 39, width: w * 0.3, height: 1.5), cornerRadius: 0.5),
                     with: .color(.green))
        }
        .frame(width: 100, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    // Mini mockup: badge hover
    private func miniBadgeHover() -> some View {
        VStack(spacing: 4) {
            Text("SAFE")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.85))
                .cornerRadius(2)
            Text(L.isEN ? "Can last until next reset" : "可支撑到下次重置")
                .font(.system(size: 6))
                .foregroundColor(.green.opacity(0.8))
        }
    }
}

// MARK: - Mascot State

enum MascotState {
    case noKey       // Gray, sleepy breathing
    case safe        // Color based on percentage, happy dance
    case warning     // Orange, fast jittery
    case exhausted   // Red, X eyes, barely moving
}

// MARK: - Pixel Mascot

struct PixelMascot: View {
    let state: MascotState
    let percentage: Int
    @State private var frame = 0
    @State private var offsetY: CGFloat = 0
    @State private var rotation: CGFloat = 0
    @State private var scale: CGFloat = 1.0
    @State private var mascotOpacity: CGFloat = 1.0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    // 0=empty, 1=body, 2=eye/accent, 3=sweat drop
    private var frames: [[[Int]]] {
        switch state {
        case .noKey: return noKeyFrames
        case .safe: return safeFrames
        case .warning: return warningFrames
        case .exhausted: return exhaustedFrames
        }
    }

    private var bodyColor: Color {
        switch state {
        case .noKey: return .gray.opacity(0.45)
        case .safe, .warning:
            let orange = UserDefaults.standard.integer(forKey: "threshold_orange")
            let red = UserDefaults.standard.integer(forKey: "threshold_red")
            let tOrange = (orange > 0 && orange <= 100) ? orange : 60
            let tRed = (red > 0 && red <= 100) ? red : 85
            if percentage < tOrange { return .green }
            if percentage < max(tRed, tOrange) { return .orange }
            return .red
        case .exhausted: return .red.opacity(0.9)
        }
    }

    private var eyeColor: Color {
        switch state {
        case .noKey: return .gray.opacity(0.2)
        case .safe: return .black.opacity(0.7)
        case .warning: return .black.opacity(0.8)
        case .exhausted: return .black.opacity(0.8)
        }
    }

    // NoKey: sleeping blob, closed eyes, rounder shape
    private var noKeyFrames: [[[Int]]] {
        let f0: [[Int]] = [
            [0,0,0,0,0,0,0,0,0,0,0],
            [0,0,0,1,1,1,1,1,0,0,0],
            [0,0,1,1,1,1,1,1,1,0,0],
            [0,1,1,2,2,1,2,2,1,1,0],
            [0,1,1,1,1,1,1,1,1,1,0],
            [0,0,1,1,1,0,1,1,1,0,0],
            [0,0,0,1,1,1,1,1,0,0,0],
            [0,0,0,0,1,0,1,0,0,0,0],
        ]
        let f1: [[Int]] = [
            [0,0,0,1,1,1,1,1,0,0,0],
            [0,0,1,1,1,1,1,1,1,0,0],
            [0,1,1,1,1,1,1,1,1,1,0],
            [0,1,1,2,2,1,2,2,1,1,0],
            [0,1,1,1,1,1,1,1,1,1,0],
            [0,0,1,1,1,0,1,1,1,0,0],
            [0,0,0,1,1,1,1,1,0,0,0],
            [0,0,0,0,1,0,1,0,0,0,0],
        ]
        return [f0, f1]
    }

    // Safe: happy invader with antenna
    private var safeFrames: [[[Int]]] {
        let f0: [[Int]] = [
            [0,0,1,0,0,0,0,1,0,0,0],
            [0,0,0,1,0,0,1,0,0,0,0],
            [0,0,1,1,1,1,1,1,1,0,0],
            [0,1,1,0,2,1,2,0,1,1,0],
            [1,1,1,1,1,1,1,1,1,1,1],
            [1,0,1,1,1,1,1,1,1,0,1],
            [1,0,1,0,0,0,0,0,1,0,1],
            [0,0,0,1,0,0,0,1,0,0,0],
        ]
        let f1: [[Int]] = [
            [0,0,1,0,0,0,0,1,0,0,0],
            [0,0,0,1,0,0,1,0,0,0,0],
            [0,0,1,1,1,1,1,1,1,0,0],
            [0,1,1,0,2,1,2,0,1,1,0],
            [1,1,1,1,1,1,1,1,1,1,1],
            [0,0,1,1,1,1,1,1,1,0,0],
            [0,0,1,0,0,0,0,0,1,0,0],
            [0,1,0,0,0,0,0,0,0,1,0],
        ]
        return [f0, f1]
    }

    // Warning: nervous, multiple sweat drops scattering, same body as safe
    private var warningFrames: [[[Int]]] {
        // Frame 0: sweat drops gathered near top-right
        let f0: [[Int]] = [
            [3,0,1,0,0,0,0,1,0,3,0],
            [0,0,0,1,0,0,1,0,0,0,0],
            [0,0,1,1,1,1,1,1,1,0,0],
            [0,1,1,2,2,1,2,2,1,1,0],
            [1,1,1,1,1,1,1,1,1,1,1],
            [1,0,1,1,1,1,1,1,1,0,1],
            [1,0,1,0,0,0,0,0,1,0,1],
            [0,0,0,1,0,0,0,1,0,0,0],
        ]
        // Frame 1: sweat drops spread outward
        let f1: [[Int]] = [
            [3,0,1,0,0,0,0,1,0,0,3],
            [0,3,0,1,0,0,1,3,0,0,0],
            [0,0,1,1,1,1,1,1,1,0,0],
            [0,1,1,2,2,1,2,2,1,1,0],
            [1,1,1,1,1,1,1,1,1,1,1],
            [0,0,1,1,1,1,1,1,1,0,0],
            [0,0,1,0,0,0,0,0,1,0,0],
            [0,1,0,0,0,0,0,0,0,1,0],
        ]
        // Frame 2: sweat drops flying further
        let f2: [[Int]] = [
            [0,3,1,0,0,0,0,1,3,0,0],
            [0,0,0,1,0,0,1,0,0,3,0],
            [0,0,1,1,1,1,1,1,1,0,0],
            [0,1,1,2,2,1,2,2,1,1,0],
            [1,1,1,1,1,1,1,1,1,1,1],
            [1,0,1,1,1,1,1,1,1,0,1],
            [1,0,1,0,0,0,0,0,1,0,1],
            [0,0,0,1,0,0,0,1,0,0,0],
        ]
        // Frame 3: sweat at max spread + new drops forming
        let f3: [[Int]] = [
            [3,0,1,0,0,0,0,1,0,0,3],
            [0,0,0,1,0,0,1,0,0,0,3],
            [0,0,1,1,1,1,1,1,1,0,0],
            [0,1,1,2,2,1,2,2,1,1,0],
            [1,1,1,1,1,1,1,1,1,1,1],
            [0,0,1,1,1,1,1,1,1,0,0],
            [0,0,1,0,0,0,0,0,1,0,0],
            [0,1,0,0,0,0,0,0,0,1,0],
        ]
        return [f0, f1, f2, f3]
    }

    // Exhausted: horizontal line eyes, collapsed, no animation
    private var exhaustedFrames: [[[Int]]] {
        // Eyes: 1x2 horizontal lines at row 3
        let f0: [[Int]] = [
            [0,0,0,0,0,0,0,0,0,0,0],
            [0,0,1,1,1,1,1,1,1,0,0],
            [0,1,1,1,1,1,1,1,1,1,0],
            [0,1,1,2,2,1,2,2,1,1,0],
            [1,1,1,1,1,1,1,1,1,1,1],
            [0,0,1,1,1,1,1,1,1,0,0],
            [0,0,0,1,0,0,0,1,0,0,0],
            [0,0,0,0,0,0,0,0,0,0,0],
        ]
        return [f0]
    }

    var body: some View {
        Canvas { ctx, size in
            let px: CGFloat = 2.5
            let currentFrame = frames[frame % frames.count]
            let cols = currentFrame[0].count
            let rows = currentFrame.count
            let ox = (size.width - CGFloat(cols) * px) / 2
            let oy = (size.height - CGFloat(rows) * px) / 2

            for r in 0..<rows {
                for c in 0..<cols {
                    let val = currentFrame[r][c]
                    guard val > 0 else { continue }
                    let rect = CGRect(
                        x: ox + CGFloat(c) * px,
                        y: oy + CGFloat(r) * px,
                        width: px, height: px
                    )
                    let color: Color
                    switch val {
                    case 2: color = eyeColor
                    case 3: color = .cyan.opacity(0.7)
                    default: color = bodyColor
                    }
                    ctx.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: 30, height: 26)
        .offset(y: offsetY)
        .rotationEffect(.degrees(rotation))
        .scaleEffect(scale)
        .opacity(mascotOpacity)
        .onReceive(timer) { _ in
            frame += 1
            animate()
        }
    }

    private func animate() {
        switch state {
        case .noKey: animateNoKey()
        case .safe: animateSafe()
        case .warning: animateWarning()
        case .exhausted: animateExhausted()
        }
    }

    private func animateNoKey() {
        let breathIn = frame % 2 == 0
        withAnimation(.easeInOut(duration: 0.4)) {
            scale = breathIn ? 1.06 : 0.94
            offsetY = breathIn ? -1 : 1
            rotation = 0
            mascotOpacity = 1.0
        }
    }

    private func animateSafe() {
        let moves: [(offsetY: CGFloat, rotation: CGFloat)] = [
            (-3, 0), (0, 5), (0, -5), (-5, -3),
            (-5, 3), (0, 0), (-2, 8), (-2, -8),
        ]
        let move = moves.randomElement() ?? (0, 0)
        withAnimation(.easeInOut(duration: 0.25)) {
            offsetY = move.offsetY
            rotation = move.rotation
            scale = 1.0
            mascotOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.2)) {
                offsetY = 0
                rotation = 0
            }
        }
    }

    private func animateWarning() {
        let jY = CGFloat.random(in: -2...2)
        let jR = CGFloat.random(in: -5...5)
        withAnimation(.easeInOut(duration: 0.1)) {
            offsetY = jY
            rotation = jR
            scale = 1.0
            mascotOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.1)) {
                offsetY = 0
                rotation = 0
            }
        }
    }

    private func animateExhausted() {
        // Stand still, only pulse opacity
        let pulse = frame % 2 == 0 ? 0.5 : 1.0
        withAnimation(.easeInOut(duration: 0.4)) {
            offsetY = 0
            rotation = 0
            scale = 1.0
            mascotOpacity = pulse
        }
    }
}

struct ProgressBar: View {
    let value: Double
    let color: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.07))
                RoundedRectangle(cornerRadius: 2).fill(color)
                    .frame(width: max(0, geo.size.width * CGFloat(min(value, 1.0))))
            }
        }
    }
}

// MARK: - Settings Window (standalone)

private var settingsWindowRef: NSWindow?

func showSettingsWindow(viewModel: UsageViewModel) {
    // Close existing window so a fresh one is created on the current Space
    if let existing = settingsWindowRef {
        existing.close()
        settingsWindowRef = nil
    }

    // Activate app so window lands on the current Space
    NSApp.activate(ignoringOtherApps: true)

    let view = SettingsPanelContent(viewModel: viewModel)
    let hosting = NSHostingView(rootView: view)

    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 320, height: 460),
        styleMask: [.titled, .closable, .fullSizeContentView],
        backing: .buffered, defer: false
    )
    window.titlebarAppearsTransparent = true
    window.title = L.settings
    window.contentView = hosting
    window.isReleasedWhenClosed = false

    // Center on the screen where the mouse currently is
    let mouse = NSEvent.mouseLocation
    let targetScreen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    if let screen = targetScreen {
        let visible = screen.visibleFrame
        window.setFrameOrigin(NSPoint(
            x: visible.midX - 160,
            y: visible.midY - 230
        ))
    }

    settingsWindowRef = window

    window.orderFrontRegardless()
    window.makeKey()
}
