import Foundation

/// RGB only: opacity belongs to the material, never to the stored day color.
public struct DayColor: Codable, Equatable, Sendable {
    public let rgb: UInt32
    public let isCustom: Bool
    public init(rgb: UInt32, isCustom: Bool = true) { self.rgb = rgb; self.isCustom = isCustom }

    public init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, value.allSatisfy({ $0.isASCII && $0.isHexDigit }), let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(rgb: rgb)
    }
    public var hex: String { String(format: "#%06X", rgb) }

    public static let palette: [UInt32] = [0x709DB9, 0x83A797, 0xA393BD, 0xC58F9F, 0xC3A56C, 0xC99D85, 0x7EAEB1, 0x939DAE]
    public static let names = ["colorSea", "colorSage", "colorIris", "colorRose", "colorHoney", "colorPeach", "colorLagoon", "colorSlate"]

    /// Stable pseudo-random weekly palette. Unlike Hasher, this survives process restarts.
    /// Each weekday gets a distinct color; navigating weeks does not write empty records.
    public static func automatic(for day: Day, calendar: Calendar = .journal) -> DayColor {
        let week = day.week(calendar: calendar)
        var seed: UInt64 = 14695981039346656037
        for byte in (week.first ?? day).rawValue.utf8 { seed = (seed ^ UInt64(byte)) &* 1099511628211 }
        var colors = palette
        for index in stride(from: colors.count - 1, through: 1, by: -1) {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            colors.swapAt(index, Int((seed >> 32) % UInt64(index + 1)))
        }
        return DayColor(rgb: colors[week.firstIndex(of: day) ?? 0], isCustom: false)
    }
}
