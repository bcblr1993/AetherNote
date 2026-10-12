import Foundation

public enum JournalError: Error, LocalizedError, Equatable {
    case sealed, empty, tooLong, missingEntry, invalidDate, unsupportedSchema, invalidData
    public var errorDescription: String? {
        switch self {
        case .sealed: return "This day is sealed and cannot be changed."
        case .empty: return "Write at least one line."
        case .tooLong: return "An entry may contain at most 4,000 characters."
        case .missingEntry: return "The entry no longer exists."
        case .invalidDate: return "Invalid calendar date."
        case .unsupportedSchema: return "This journal was created by a newer app version."
        case .invalidData: return "The journal contains invalid data."
        }
    }
}

public struct Day: RawRepresentable, Codable, Hashable, Comparable, Identifiable, Sendable {
    public let rawValue: String
    public var id: String { rawValue }
    public init(rawValue: String) { self.rawValue = rawValue }
    public static func < (lhs: Day, rhs: Day) -> Bool { lhs.rawValue < rhs.rawValue }
    public init(_ date: Date, calendar: Calendar = .journal) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.rawValue = String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
    public func date(calendar: Calendar = .journal) -> Date? {
        let p = rawValue.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, rawValue.count == 10,
              let d = calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12)),
              Day(d, calendar: calendar) == self else { return nil }
        return d
    }
    public func adding(days: Int, calendar: Calendar = .journal) -> Day {
        guard let date = date(calendar: calendar), let next = calendar.date(byAdding: .day, value: days, to: date) else { return self }
        return Day(next, calendar: calendar)
    }
    public func week(calendar: Calendar = .journal) -> [Day] {
        guard let date = date(calendar: calendar) else { return [] }
        let weekday = calendar.component(.weekday, from: date)
        let monday = adding(days: -((weekday + 5) % 7), calendar: calendar)
        return (0..<7).map { monday.adding(days: $0, calendar: calendar) }
    }
}

public extension Calendar {
    static var journal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "en_US_POSIX")
        c.timeZone = .current
        c.firstWeekday = 2
        return c
    }
}

public struct Entry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var text: String
    public let createdAt: Date
    public var modifiedAt: Date
    public init(id: UUID = UUID(), text: String, at date: Date) {
        self.id = id; self.text = text; createdAt = date; modifiedAt = date
    }
}

public struct Journal: Codable, Equatable, Sendable {
    public private(set) var schemaVersion = 1
    public private(set) var entries: [String: [Entry]] = [:]
    public private(set) var arrangements: [String: [String]] = [:]
    /// High-water mark prevents a backward clock or timezone change from reopening a sealed day.
    public private(set) var latestObservedDay: Day?
    public init() {}

    public func validate(calendar: Calendar = .journal) throws {
        guard schemaVersion == 1 else { throw JournalError.unsupportedSchema }
        if let latestObservedDay, latestObservedDay.date(calendar: calendar) == nil { throw JournalError.invalidData }
        var ids = Set<UUID>()
        for (key, values) in entries {
            guard Day(rawValue: key).date(calendar: calendar) != nil else { throw JournalError.invalidData }
            for entry in values {
                guard ids.insert(entry.id).inserted, !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      entry.text.count <= 4_000, entry.createdAt.timeIntervalSince1970.isFinite,
                      entry.modifiedAt >= entry.createdAt else { throw JournalError.invalidData }
            }
        }
        for (week, order) in arrangements {
            let monday = Day(rawValue: week)
            guard monday.date(calendar: calendar) != nil, monday.week(calendar: calendar).first == monday,
                  order.count <= 7, Set(order).count == order.count,
                  order.allSatisfy({ monday.week(calendar: calendar).map(\.rawValue).contains($0) }) else { throw JournalError.invalidData }
        }
    }

    @discardableResult public mutating func observe(_ now: Date, calendar: Calendar = .journal) -> Bool {
        let day = Day(now, calendar: calendar)
        if latestObservedDay == nil || day > latestObservedDay! { latestObservedDay = day; return true }
        return false
    }
    public func canEdit(_ day: Day, now: Date, calendar: Calendar = .journal) -> Bool {
        let today = Day(now, calendar: calendar)
        return day == today && (latestObservedDay == nil || today >= latestObservedDay!)
    }
    public func records(on day: Day) -> [Entry] { entries[day.rawValue] ?? [] }

    public mutating func append(_ text: String, on day: Day, now: Date, calendar: Calendar = .journal) throws {
        guard canEdit(day, now: now, calendar: calendar) else { throw JournalError.sealed }
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !lines.isEmpty else { throw JournalError.empty }
        guard lines.allSatisfy({ $0.count <= 4_000 }) else { throw JournalError.tooLong }
        observe(now, calendar: calendar)
        entries[day.rawValue, default: []] += lines.map { Entry(text: $0, at: now) }
    }
    public mutating func edit(_ id: UUID, text: String, on day: Day, now: Date, calendar: Calendar = .journal) throws {
        guard canEdit(day, now: now, calendar: calendar) else { throw JournalError.sealed }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw JournalError.empty }
        guard value.count <= 4_000 else { throw JournalError.tooLong }
        guard let index = entries[day.rawValue]?.firstIndex(where: { $0.id == id }) else { throw JournalError.missingEntry }
        observe(now, calendar: calendar)
        entries[day.rawValue]![index].text = value
        entries[day.rawValue]![index].modifiedAt = max(now, entries[day.rawValue]![index].createdAt)
    }
    public mutating func remove(_ id: UUID, on day: Day, now: Date, calendar: Calendar = .journal) throws {
        guard canEdit(day, now: now, calendar: calendar) else { throw JournalError.sealed }
        guard let index = entries[day.rawValue]?.firstIndex(where: { $0.id == id }) else { throw JournalError.missingEntry }
        observe(now, calendar: calendar); entries[day.rawValue]!.remove(at: index)
    }
    public func arranged(_ days: [Day], week: Day) -> [Day] {
        let saved = arrangements[week.rawValue] ?? []
        return saved.compactMap { raw in days.first { $0.rawValue == raw } } + days.filter { !saved.contains($0.rawValue) }
    }
    public mutating func arrange(_ days: [Day], week: Day, calendar: Calendar = .journal) throws {
        let valid = week.week(calendar: calendar)
        guard valid.first == week, days.count <= 7, Set(days).count == days.count, days.allSatisfy(valid.contains) else { throw JournalError.invalidDate }
        arrangements[week.rawValue] = days.map(\.rawValue)
    }
    public mutating func tidy(week: Day) { arrangements.removeValue(forKey: week.rawValue) }
    public func markdown(week: Day, calendar: Calendar = .journal) -> String {
        let days = week.week(calendar: calendar)
        var blocks = ["# \(days.first?.rawValue ?? week.rawValue) — \(days.last?.rawValue ?? week.rawValue)"]
        for day in days where !records(on: day).isEmpty {
            blocks.append("## \(day.rawValue)\n\n" + records(on: day).map { "- " + $0.text.replacingOccurrences(of: "\n", with: "\n  ") }.joined(separator: "\n"))
        }
        return blocks.joined(separator: "\n\n") + "\n"
    }
}
