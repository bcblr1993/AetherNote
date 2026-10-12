import Foundation

public struct JournalDisk {
    public let directory: URL
    public var file: URL { directory.appendingPathComponent("journal.json") }
    public var backup: URL { directory.appendingPathComponent("journal.previous.json") }
    public init(directory: URL) { self.directory = directory }
    public func load() throws -> Journal {
        guard FileManager.default.fileExists(atPath: file.path) else { return Journal() }
        let journal = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: file))
        try journal.validate()
        return journal
    }
    public func save(_ journal: Journal) throws {
        try journal.validate()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let next = try encoder.encode(journal)
        // Never silently replace a corrupted existing file with an empty journal.
        if FileManager.default.fileExists(atPath: file.path) {
            let old = try Data(contentsOf: file)
            let validated = try JSONDecoder().decode(Journal.self, from: old)
            try validated.validate()
            try old.write(to: backup, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        }
        try next.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}

public struct ReminderPolicy: Sendable {
    public var interval: TimeInterval = 3600
    public var lastActivity: Date
    public var lastReminder: Date?
    public var enabled = true
    public init(startedAt: Date) { lastActivity = startedAt }
    public func isDue(at now: Date, sessionActive: Bool, isEditing: Bool, recentlyTyping: Bool) -> Bool {
        guard enabled, sessionActive, !isEditing, !recentlyTyping else { return false }
        let anchor = max(lastActivity, lastReminder ?? .distantPast)
        return now.timeIntervalSince(anchor) >= interval
    }
    public mutating func recorded(at now: Date) { lastActivity = now }
    public mutating func reminded(at now: Date) { lastReminder = now }
    public mutating func resumed(at now: Date) { lastReminder = now }
}
