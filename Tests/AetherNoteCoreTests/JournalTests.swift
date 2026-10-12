import Foundation
import Testing
@testable import AetherNoteCore

private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
private var utc: Calendar { var c = Calendar.journal; c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }

@Test func multilineAppendAndUnicode() throws {
    var j = Journal(); let now = date("2026-10-12T10:00:00Z"), day = Day(now, calendar: utc)
    try j.append("第一件事\n\n 日本語の記録 \r\nDone ✅", on: day, now: now, calendar: utc)
    #expect(j.records(on: day).map(\.text) == ["第一件事", "日本語の記録", "Done ✅"])
    #expect(Set(j.records(on: day).map(\.id)).count == 3)
}

@Test func midnightSealsAppendEditAndDeleteEvenIfEditorIsOpen() throws {
    let before = date("2026-10-12T23:59:59Z"), after = date("2026-10-13T00:00:00Z"), day = Day(before, calendar: utc)
    var j = Journal(); try j.append("immutable after midnight", on: day, now: before, calendar: utc)
    let id = j.records(on: day)[0].id, snapshot = j
    #expect(throws: JournalError.sealed) { try j.append("late", on: day, now: after, calendar: utc) }
    #expect(throws: JournalError.sealed) { try j.edit(id, text: "changed", on: day, now: after, calendar: utc) }
    #expect(throws: JournalError.sealed) { try j.remove(id, on: day, now: after, calendar: utc) }
    #expect(j == snapshot)
    try j.append("new day", on: Day(after, calendar: utc), now: after, calendar: utc)
    #expect(j.records(on: day)[0].text == "immutable after midnight")
}

@Test func clockRollbackDoesNotReopenPastDay() throws {
    let now = date("2026-10-13T10:00:00Z"), old = date("2026-10-12T10:00:00Z")
    var j = Journal(); j.observe(now, calendar: utc)
    #expect(!j.canEdit(Day(old, calendar: utc), now: old, calendar: utc))
    #expect(throws: JournalError.sealed) { try j.append("rollback", on: Day(old, calendar: utc), now: old, calendar: utc) }
    let reopened = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(j))
    #expect(!reopened.canEdit(Day(old, calendar: utc), now: old, calendar: utc))
}

@Test func futureDatesCannotBeWritten() throws {
    let now = date("2026-10-12T10:00:00Z"); var j = Journal()
    #expect(throws: JournalError.sealed) { try j.append("future", on: Day(rawValue: "2026-10-13"), now: now, calendar: utc) }
}

@Test func arrangingSealedDaysNeverChangesRecords() throws {
    let now = date("2026-10-12T10:00:00Z"), day = Day(now, calendar: utc); var j = Journal()
    try j.append("keep", on: day, now: now, calendar: utc)
    j.observe(date("2026-10-13T10:00:00Z"), calendar: utc)
    let records = j.entries, week = day.week(calendar: utc), reversed = Array(week.reversed())
    try j.arrange(reversed, week: day, calendar: utc)
    #expect(j.arranged(week, week: day) == reversed)
    #expect(j.entries == records)
    j.tidy(week: day)
    #expect(j.arranged(week, week: day) == week)
    #expect(j.entries == records)
    #expect(throws: JournalError.invalidDate) { try j.arrange([day, day], week: day, calendar: utc) }
}

@Test func weekAlwaysHasSevenConsecutiveDaysAcrossYearAndDST() {
    let week = Day(rawValue: "2027-01-01").week(calendar: utc)
    #expect(week.first?.rawValue == "2026-12-28")
    #expect(week.last?.rawValue == "2027-01-03")
    var la = utc; la.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    let dst = Day(rawValue: "2026-11-01").week(calendar: la)
    #expect(dst.count == 7 && Set(dst).count == 7)
    #expect(dst.first?.rawValue == "2026-10-26")
    #expect(Day(rawValue: "2026-02-30").date(calendar: utc) == nil)
}

@Test func oversizedBatchIsAtomic() throws {
    let now = date("2026-10-12T10:00:00Z"), day = Day(now, calendar: utc); var j = Journal()
    #expect(throws: JournalError.tooLong) { try j.append("valid\n" + String(repeating: "a", count: 4001), on: day, now: now, calendar: utc) }
    #expect(j.entries.isEmpty)
    #expect(throws: JournalError.empty) { try j.append(" \n\t", on: day, now: now, calendar: utc) }
}

@Test func diskRoundTripBackupAndCorruptionProtection() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let disk = JournalDisk(directory: dir), now = date("2026-10-12T10:00:00Z"), day = Day(now)
    var j = Journal(); try j.append("first", on: day, now: now); try disk.save(j)
    let original = j; try j.append("second", on: day, now: now); try disk.save(j)
    #expect(try disk.load() == j)
    #expect(try JSONDecoder().decode(Journal.self, from: Data(contentsOf: disk.backup)) == original)
    let corrupt = Data("not a journal".utf8); try corrupt.write(to: disk.file)
    #expect(throws: (any Error).self) { try disk.load() }
    #expect(throws: (any Error).self) { try disk.save(Journal()) }
    #expect(try Data(contentsOf: disk.file) == corrupt)
}

@Test func remindersRespectActivityAndDoNotCatchUpAfterSleep() {
    let now = date("2026-10-12T10:00:00Z"); var p = ReminderPolicy(startedAt: now)
    let later = now.addingTimeInterval(3600)
    #expect(!p.isDue(at: now.addingTimeInterval(3599), sessionActive: true, isEditing: false, recentlyTyping: false))
    #expect(p.isDue(at: later, sessionActive: true, isEditing: false, recentlyTyping: false))
    #expect(!p.isDue(at: later, sessionActive: false, isEditing: false, recentlyTyping: false))
    #expect(!p.isDue(at: later, sessionActive: true, isEditing: true, recentlyTyping: false))
    #expect(!p.isDue(at: later, sessionActive: true, isEditing: false, recentlyTyping: true))
    p.reminded(at: later)
    #expect(!p.isDue(at: later.addingTimeInterval(1), sessionActive: true, isEditing: false, recentlyTyping: false))
    p.resumed(at: later.addingTimeInterval(7200))
    #expect(!p.isDue(at: later.addingTimeInterval(7201), sessionActive: true, isEditing: false, recentlyTyping: false))
    p.enabled = false
    #expect(!p.isDue(at: later.addingTimeInterval(20000), sessionActive: true, isEditing: false, recentlyTyping: false))
}

@Test func exportIgnoresVisualOrder() throws {
    let a = date("2026-10-12T10:00:00Z"), b = date("2026-10-13T10:00:00Z"), mon = Day(a, calendar: utc); var j = Journal()
    try j.append("Monday", on: mon, now: a, calendar: utc)
    try j.append("Tuesday", on: Day(b, calendar: utc), now: b, calendar: utc)
    try j.arrange(Array(mon.week(calendar: utc).reversed()), week: mon, calendar: utc)
    let output = j.markdown(week: mon, calendar: utc)
    #expect(output.range(of: "Monday")!.lowerBound < output.range(of: "Tuesday")!.lowerBound)
}

@Test func todaysEditDeleteAndMissingEntryAreSafe() throws {
    let now = date("2026-10-12T10:00:00Z"), day = Day(now, calendar: utc); var j = Journal()
    try j.append("original", on: day, now: now, calendar: utc)
    let id = j.records(on: day)[0].id
    try j.edit(id, text: "edited 日本語", on: day, now: now.addingTimeInterval(60), calendar: utc)
    #expect(j.records(on: day)[0].id == id)
    #expect(j.records(on: day)[0].text == "edited 日本語")
    #expect(j.records(on: day)[0].modifiedAt > j.records(on: day)[0].createdAt)
    let snapshot = j
    #expect(throws: JournalError.missingEntry) { try j.edit(UUID(), text: "missing", on: day, now: now, calendar: utc) }
    #expect(j == snapshot)
    try j.remove(id, on: day, now: now, calendar: utc)
    #expect(j.records(on: day).isEmpty)
}

@Test func travelingWestDoesNotReopenYesterday() {
    let instant = date("2026-10-13T01:00:00Z")
    var shanghai = utc; shanghai.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    var la = utc; la.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    var j = Journal(); j.observe(instant, calendar: shanghai)
    #expect(Day(instant, calendar: la).rawValue == "2026-10-12")
    #expect(!j.canEdit(Day(instant, calendar: la), now: instant, calendar: la))
}

@Test func recordedActivityDefersReminder() {
    let now = date("2026-10-12T10:00:00Z"); var p = ReminderPolicy(startedAt: now)
    p.recorded(at: now.addingTimeInterval(3590))
    #expect(!p.isDue(at: now.addingTimeInterval(3601), sessionActive: true, isEditing: false, recentlyTyping: false))
    #expect(p.isDue(at: now.addingTimeInterval(7190), sessionActive: true, isEditing: false, recentlyTyping: false))
}
