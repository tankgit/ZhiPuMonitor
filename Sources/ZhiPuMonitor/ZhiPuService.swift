import Foundation
import SwiftUI

// MARK: - Safety Estimate

enum SafetyEstimate {
    case safe
    case unsafe(remainingTime: String)
    case unknown
}

// MARK: - API Models

struct ZhiPuResponse: Codable {
    let code: Int
    let msg: String
    let data: ZhiPuData?
    let success: Bool
}

struct ZhiPuData: Codable {
    let limits: [QuotaLimit]
    let level: String
}

struct QuotaLimit: Codable {
    let type: String
    let unit: Int
    let number: Int
    let usage: Int?
    let currentValue: Int?
    let remaining: Int?
    let percentage: Int
    let nextResetTime: Int64?
    let usageDetails: [UsageDetail]?
}

struct UsageDetail: Codable {
    let modelCode: String
    let usage: Int
}

// MARK: - Helper Extensions

extension QuotaLimit {
    var resetTimeString: String? {
        guard let ts = nextResetTime else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(ts) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }

    var progressColor: Color {
        let orange = UserDefaults.standard.integer(forKey: "threshold_orange")
        let red = UserDefaults.standard.integer(forKey: "threshold_red")
        let tOrange = (orange > 0 && orange <= 100) ? orange : 60
        let tRed = (red > 0 && red <= 100) ? red : 85
        if percentage < tOrange { return .green }
        if percentage < max(tRed, tOrange) { return .orange }
        return .red
    }
}

// MARK: - ViewModel

@MainActor
class UsageViewModel: ObservableObject {
    @Published var fiveHourLimit: QuotaLimit?
    @Published var weeklyLimit: QuotaLimit?
    @Published var mcpLimit: QuotaLimit?
    @Published var level: String = "-"
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    @Published var errorMessage: String?
    @Published var hasApiKey: Bool

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "zhipu_api_key") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "zhipu_api_key")
            hasApiKey = !newValue.isEmpty
        }
    }

    var maxPercentage: Int {
        let values = [fiveHourLimit?.percentage ?? 0, weeklyLimit?.percentage ?? 0, mcpLimit?.percentage ?? 0]
        return values.max() ?? 0
    }

    // MARK: - Safety Estimates (calculated from resetTime)

    var fiveHourSafety: SafetyEstimate {
        estimateSafety(limit: fiveHourLimit, cycleDuration: 5 * 3600, useDays: false)
    }

    var weeklySafety: SafetyEstimate {
        estimateSafety(limit: weeklyLimit, cycleDuration: 7 * 86400, useDays: true)
    }

    var mcpSafety: SafetyEstimate {
        estimateSafety(limit: mcpLimit, cycleDuration: 7 * 86400, useDays: true)
    }

    private func estimateSafety(limit: QuotaLimit?, cycleDuration: TimeInterval, useDays: Bool) -> SafetyEstimate {
        guard let limit = limit, let resetTs = limit.nextResetTime else { return .unknown }
        let now = Date()
        let resetDate = Date(timeIntervalSince1970: TimeInterval(resetTs) / 1000)
        let timeToReset = now.distance(to: resetDate)
        guard timeToReset > 0 else { return .unknown }

        if limit.percentage == 0 { return .safe }

        // Calculate last reset time by subtracting cycle duration from next reset
        let lastResetDate = resetDate.addingTimeInterval(-cycleDuration)
        let elapsed = now.timeIntervalSince(lastResetDate)
        guard elapsed > 0 else { return .safe }

        // Don't judge rate in the first 10% of the cycle — too little data to extrapolate
        let cycleProgress = elapsed / cycleDuration
        guard cycleProgress > 0.05 else { return .safe }

        let rate = Double(limit.percentage) / elapsed // percentage points per second
        let remaining = Double(100 - limit.percentage)
        let timeToExhaust = remaining / rate // seconds

        if timeToExhaust >= timeToReset {
            return .safe
        } else {
            return .unsafe(remainingTime: formatDuration(seconds: timeToExhaust, useDays: useDays))
        }
    }

    private func formatDuration(seconds: TimeInterval, useDays: Bool) -> String {
        if useDays {
            let days = Int(seconds) / 86400
            if days > 0 {
                let hours = Int(seconds) % 86400 / 3600
                return days == 1 ? L.days(days) : L.daysHours(days, hours)
            }
        }
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        if hours > 0 {
            return L.hoursMinutes(hours, minutes)
        } else {
            return L.minutes(minutes)
        }
    }

    var lastUpdatedString: String {
        guard let date = lastUpdated else { return "-" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }

    init() {
        let key = UserDefaults.standard.string(forKey: "zhipu_api_key") ?? ""
        hasApiKey = !key.isEmpty
    }

    func fetchUsage() async {
        let key = apiKey
        guard !key.isEmpty else {
            errorMessage = L.apiKeyNotSet
            return
        }

        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "https://open.bigmodel.cn/api/monitor/usage/quota/limit") else {
            errorMessage = L.invalidURL
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = L.invalidResponse
                isLoading = false
                return
            }

            guard httpResponse.statusCode == 200 else {
                errorMessage = "HTTP \(httpResponse.statusCode)"
                isLoading = false
                return
            }

            let result = try JSONDecoder().decode(ZhiPuResponse.self, from: data)

            guard result.success, let usageData = result.data else {
                errorMessage = result.msg
                isLoading = false
                return
            }

            level = usageData.level
            for limit in usageData.limits {
                switch limit.type {
                case "TOKENS_LIMIT":
                    if limit.unit == 3, limit.number == 5 {
                        fiveHourLimit = limit
                    } else {
                        weeklyLimit = limit
                    }
                case "TIME_LIMIT":
                    mcpLimit = limit
                default:
                    break
                }
            }

            lastUpdated = Date()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
