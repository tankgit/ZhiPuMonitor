import Foundation

// MARK: - Language

enum AppLanguage: String, CaseIterable {
    case zh = "zh"
    case en = "en"

    var displayName: String {
        switch self {
        case .zh: return "中文"
        case .en: return "English"
        }
    }
}

// MARK: - Localization

struct L {
    static var lang: String {
        UserDefaults.standard.string(forKey: "app_language") ?? "zh"
    }

    static var isEN: Bool { lang == "en" }

    // MARK: - General

    static var appName: String { isEN ? "ZBar" : "ZBar" }
    static var settings: String { isEN ? "ZBar Settings" : "ZBar 设置" }
    static var general: String { isEN ? "General" : "通用" }
    static var about: String { isEN ? "About" : "关于" }

    // MARK: - Main Panel

    static var titleText: String { isEN ? "Z.AI Coding Plan" : "智谱编码套餐" }
    static var refreshing: String { isEN ? "Refreshing…" : "刷新中…" }
    static func updatedAt(_ time: String) -> String { isEN ? "Updated \(time)" : "更新于 \(time)" }
    static var noApiKeyPrompt: String { isEN ? "Please configure API Key in Settings" : "请在设置中配置 API Key" }

    // MARK: - Quota Cards

    static var fiveHourQuota: String { isEN ? "5-Hour Quota" : "5小时额度" }
    static var weeklyQuota: String { isEN ? "Weekly Quota" : "一周额度" }
    static var mcpCalls: String { isEN ? "MCP Calls" : "MCP 调用" }

    // MARK: - Quota Info

    static func resetAt(_ time: String) -> String { isEN ? "Reset \(time)" : "重置 \(time)" }
    static var atCurrentRate: String { isEN ? "At current rate " : "按当前速率 " }

    // MARK: - Safety Badge

    static var safeLabel: String { isEN ? "SAFE" : "SAFE" }
    static var alarmLabel: String { isEN ? "ALARM" : "ALARM" }
    static var safeHover: String { isEN ? "Can last until next reset" : "可支撑到下次重置" }
    static func unsafeHover(_ remaining: String) -> String { isEN ? "Will exhaust in \(remaining)" : "预计 \(remaining)内用完" }
    static var unknownHover: String { isEN ? "Insufficient data" : "数据不足" }

    // MARK: - Time Duration (ZhiPuService)

    static func days(_ d: Int) -> String { isEN ? "\(d) d" : "\(d) 天" }
    static func daysHours(_ d: Int, _ h: Int) -> String { isEN ? "\(d) d \(h) h" : "\(d) 天 \(h) 小时" }
    static func hoursMinutes(_ h: Int, _ m: Int) -> String { isEN ? "\(h) h \(m) min" : "\(h) 小时 \(m) 分钟" }
    static func minutes(_ m: Int) -> String { isEN ? "\(m) min" : "\(m) 分钟" }

    // MARK: - Settings: API Key

    static var apiKey: String { isEN ? "API Key" : "API Key" }
    static var apiKeyPlaceholder: String { isEN ? "Enter ZhiPu API Key" : "输入智谱 API Key" }
    static var update: String { isEN ? "Update" : "更新" }
    static var saving: String { isEN ? "Saving…" : "保存中…" }
    static var connectFailed: String { isEN ? "Connection failed, check Key" : "连接失败，请检查 Key" }
    static var updateSuccess: String { isEN ? "Updated" : "更新成功" }
    static var noApiKey: String { isEN ? "No API Key?" : "没有 API Key？" }
    static var getOne: String { isEN ? "Get one →" : "前往获取 →" }

    // MARK: - Settings: Thresholds

    static var thresholdTitle: String { isEN ? "Usage Alert Thresholds" : "用量预警阈值" }
    static var safe: String { isEN ? "Safe" : "安全" }
    static var orangeAlert: String { isEN ? "Orange Alert" : "橙色预警" }
    static var redAlert: String { isEN ? "Red Alert" : "红色预警" }
    static var thresholdDesc: String {
        isEN ? "Mascot changes color when any quota reaches threshold" : "当任意配额用量达到阈值时，吉祥物将变为对应颜色"
    }
    static var orangeRangeError: String { isEN ? "Orange threshold: 1–100" : "橙色阈值需为 1–100" }
    static var redRangeError: String { isEN ? "Red threshold: 1–100" : "红色阈值需为 1–100" }
    static var redGeOrangeError: String { isEN ? "Red threshold must be ≥ Orange" : "红色阈值需 ≥ 橙色阈值" }

    // MARK: - Settings: Launch at Login

    static var launchAtLogin: String { isEN ? "Launch at Login" : "开机自启动" }

    // MARK: - Settings: Language

    static var language: String { isEN ? "Language" : "语言" }

    // MARK: - About

    static var appDescription: String { isEN ? "ZhiPu Coding Plan Monitor" : "智谱编码套餐用量监控" }
    static var author: String { isEN ? "Author" : "作者" }
    static var buyCoffee: String { isEN ? "Buy me a coffee" : "请我喝杯咖啡 ☕" }
    static var wechatTip: String { isEN ? "Scan to tip via WeChat" : "微信扫码打赏" }

    // MARK: - Island Mode

    static var islandMode: String { isEN ? "Island Mode" : "离岛模式" }
    static var islandModeDesc: String {
        isEN ? "Show capsule bar below menu bar instead of notch overlay" : "在菜单栏下方显示胶囊条，替代刘海覆盖"
    }
    static var hotkey: String { isEN ? "Hotkey" : "快捷键" }
    static var hotkeyRecord: String { isEN ? "Record" : "录制" }
    static var hotkeyRecording: String { isEN ? "Press new shortcut…" : "请按下新快捷键…" }
    static var hotkeyDefault: String { isEN ? "Ctrl + Opt + 0" : "Ctrl + Opt + 0" }

    // MARK: - Error Messages (ZhiPuService)

    static var apiKeyNotSet: String { isEN ? "API Key not set" : "未设置 API Key" }
    static var invalidURL: String { isEN ? "Invalid URL" : "URL 无效" }
    static var invalidResponse: String { isEN ? "Invalid response" : "无效响应" }

    // MARK: - Help Tab

    static var help: String { isEN ? "Help" : "帮助" }

    // Monster descriptions
    static var helpMonsterTitle: String { isEN ? "Meet the Little Monsters" : "认识小怪兽们" }
    static var helpMonsterDesc: String {
        isEN
            ? "Different monsters appear based on your usage status. Watch them dance, panic, or collapse!"
            : "根据用量状态，不同的小怪兽会出现在标题栏旁。看它们跳舞、慌张还是瘫倒！"
    }

    static var helpSleepyName: String { isEN ? "Sleepy Monster" : "瞌睡兽" }
    static var helpSleepyColor: String { isEN ? "Gray" : "灰色" }
    static var helpSleepyDesc: String {
        isEN ? "No API Key configured. It's dozing off with slow breathing, waiting for you to wake it up." : "还没有配置 API Key。它在打瞌睡，缓慢呼吸，等你来唤醒它。"
    }

    static var helpHappyName: String { isEN ? "Happy Monster" : "开心兽" }
    static var helpHappyColor: String { isEN ? "Green / Orange / Red" : "绿色 / 橙色 / 红色" }
    static var helpHappyDesc: String {
        isEN ? "All quotas are safe. It happily dances around! Color changes with usage percentage." : "所有配额都很安全。它开心地蹦蹦跳跳！颜色随用量百分比变化。"
    }

    static var helpNervousName: String { isEN ? "Nervous Monster" : "慌张兽" }
    static var helpNervousColor: String { isEN ? "Green / Orange / Red" : "绿色 / 橙色 / 红色" }
    static var helpNervousDesc: String {
        isEN ? "At current rate, quota will exhaust before reset. It's panicking with sweat drops flying everywhere!" : "按当前速率，配额将在重置前用完。它慌得不行，汗珠到处飞溅！"
    }

    static var helpDeadName: String { isEN ? "Exhausted Monster" : "躺平兽" }
    static var helpDeadColor: String { isEN ? "Red" : "红色" }
    static var helpDeadDesc: String {
        isEN ? "Some quota is fully exhausted (100%). It can't move anymore, just standing there flickering..." : "有配额已经完全用完了（100%）。它动弹不得，只能站在原地闪烁…"
    }

    // Other help
    static var helpUsageTitle: String { isEN ? "Usage Guide" : "使用指南" }
    static var helpUsage1: String { isEN ? "Hover over the notch to see usage percentages" : "将鼠标悬停在刘海区域可查看用量百分比" }
    static var helpUsage2: String { isEN ? "Click to expand the full monitoring panel" : "点击可展开完整的监控面板" }
    static var helpUsage3: String { isEN ? "Hover over SAFE / WARN badge to see detailed prediction" : "将鼠标悬停在 SAFE / WARN 标记上可查看详细预测" }
    static var helpUsage4: String { isEN ? "Data refreshes every 5 minutes automatically" : "数据每 5 分钟自动刷新一次" }
    static var helpUsage5: String { isEN ? "Click the refresh button for manual refresh" : "点击刷新按钮可手动刷新" }

    // Color legend
    static var helpColorTitle: String { isEN ? "Color Legend" : "颜色含义" }
    static var helpColorSafe: String { isEN ? "Below orange threshold — safe zone" : "低于橙色阈值 — 安全区" }
    static var helpColorWarn: String { isEN ? "Between orange and red threshold — warning zone" : "介于橙色和红色阈值之间 — 警告区" }
    static var helpColorDanger: String { isEN ? "Above red threshold — danger zone" : "超过红色阈值 — 危险区" }

    // MARK: - Help: Island Mode

    static var helpIslandTitle: String { isEN ? "Island Mode" : "离岛模式" }
    static var helpIslandDesc: String {
        isEN
            ? "If other notch-based apps overlap with ZBar, switch to Island Mode — a capsule bar floating below the menu bar."
            : "如果其他刘海附近的应用与 ZBar 冲突，可以开启离岛模式 — 在菜单栏下方显示独立的胶囊条。"
    }
    static var helpIslandToggle: String { isEN ? "Enable in Settings → General" : "在 设置 → 通用 中开启" }
    static var helpIslandHotkey: String { isEN ? "Press the shortcut to show / hide the capsule bar" : "按下快捷键可显示或隐藏胶囊条" }
    static var helpIslandClick: String { isEN ? "Click the capsule to expand full details" : "点击胶囊条可展开完整详情" }
}
