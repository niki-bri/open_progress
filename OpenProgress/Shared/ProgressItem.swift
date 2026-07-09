import Foundation
import SwiftUI

enum ProgressStyle: String, CaseIterable, Codable, Identifiable {
    case aqua
    case grid
    case glow
    case retro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aqua: "Default"
        case .grid: "Blocks"
        case .glow: "Glow"
        case .retro: "Icon Bar"
        }
    }
}

struct ProgressItem: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var icon: String
    var startDate: Date
    var endDate: Date
    var tintHex: String
    var backgroundHex: String
    var style: ProgressStyle
    var showIcon: Bool
    var createdAt: Date
    var modifiedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        icon: String,
        startDate: Date,
        endDate: Date,
        tintHex: String,
        backgroundHex: String,
        style: ProgressStyle,
        showIcon: Bool = true,
        createdAt: Date = Date(),
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.startDate = startDate
        self.endDate = endDate
        self.tintHex = tintHex
        self.backgroundHex = backgroundHex
        self.style = style
        self.showIcon = showIcon
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    static let sample = ProgressItem(
        title: "Japan trip",
        icon: "airplane.departure",
        startDate: Calendar.current.date(byAdding: .day, value: -24, to: .now) ?? .now,
        endDate: Calendar.current.date(byAdding: .day, value: 42, to: .now) ?? .now,
        tintHex: "#18A999",
        backgroundHex: "#F6F2EA",
        style: .aqua
    )

    var progress: Double {
        progress(at: .now)
    }

    func progress(at date: Date) -> Double {
        let total = endDate.timeIntervalSince(startDate)
        guard total > 0 else { return date >= endDate ? 1 : 0 }
        let elapsed = date.timeIntervalSince(startDate)
        return min(max(elapsed / total, 0), 1)
    }

    func daysRemaining(at date: Date = .now) -> Int {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.startOfDay(for: endDate)
        return max(Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0, 0)
    }

    func statusText(at date: Date = .now) -> String {
        if date >= endDate { return "Complete" }
        let days = daysRemaining(at: date)
        if days == 0 { return "Today" }
        if days == 1 { return "1 day left" }
        return "\(days) days left"
    }

    func homeTimeText(at date: Date = .now) -> String {
        let secondsPerDay: TimeInterval = 86_400
        let interval = endDate.timeIntervalSince(date)

        // Count whole days, rounded down, so an event less than 24h away
        // (e.g. tomorrow) reads as 0 days rather than being rounded up.
        if interval < 0 {
            let days = Int(-interval / secondsPerDay)
            return "\(days) \(days == 1 ? "day" : "days") ago"
        }

        let days = Int(interval / secondsPerDay)
        return "In \(days) \(days == 1 ? "day" : "days")"
    }
}

extension ProgressItem {
    /// True when the chosen background is dark enough that dark text on it
    /// would be hard to read, so themes should switch to light text.
    var hasDarkBackground: Bool {
        Color.perceivedLuminance(ofHex: backgroundHex) < 0.6
    }
}

extension Color {
    /// Perceived brightness of a hex color on a 0 (black) … 1 (white) scale.
    static func perceivedLuminance(ofHex hex: String) -> Double {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double

        switch cleaned.count {
        case 6:
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
        case 8:
            red = Double((value >> 24) & 0xFF) / 255
            green = Double((value >> 16) & 0xFF) / 255
            blue = Double((value >> 8) & 0xFF) / 255
        default:
            return 1
        }

        return 0.299 * red + 0.587 * green + 0.114 * blue
    }

    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        switch cleaned.count {
        case 3:
            red = Double((value >> 8) & 0xF) / 15
            green = Double((value >> 4) & 0xF) / 15
            blue = Double(value & 0xF) / 15
            alpha = 1
        case 6:
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
            alpha = 1
        case 8:
            red = Double((value >> 24) & 0xFF) / 255
            green = Double((value >> 16) & 0xFF) / 255
            blue = Double((value >> 8) & 0xFF) / 255
            alpha = Double(value & 0xFF) / 255
        default:
            red = 0.1
            green = 0.1
            blue = 0.1
            alpha = 1
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
