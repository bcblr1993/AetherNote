import Foundation
import Testing
@testable import AetherNoteCore

@Test func automaticColorsAreStableAndDistinctAcrossAWeek() throws {
    for date in ["2026-10-13", "2027-01-01", "2026-11-01"] {
        let week = Day(rawValue: date).week()
        let journal = Journal()
        let colors = week.map { journal.color(on: $0) }
        #expect(Set(colors.map(\.rgb)).count == 7)
        #expect(colors.allSatisfy { !$0.isCustom && DayColor.palette.contains($0.rgb) })
        let reopened = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(journal))
        #expect(colors == week.map { reopened.color(on: $0) })
        #expect(journal.entries.isEmpty && journal.dayColors == nil)
    }
}

@Test func colorChangesSurviveDiskAndNeverChangeRecordsOrDates() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let disk = JournalDisk(directory: dir), day = Day(rawValue: "2026-10-12")
    var journal = Journal()
    try journal.append("Keep my words", on: day, now: day.date()!)
    let entries = journal.entries, markdown = journal.markdown(week: day)
    try journal.setColor(DayColor(rgb: 0xCC2288), on: day)
    try journal.arrange(Array(day.week().reversed()), week: day)
    journal.tidy(week: day)
    try disk.save(journal)
    let reopened = try disk.load()
    #expect(reopened.color(on: day) == DayColor(rgb: 0xCC2288))
    #expect(reopened.entries == entries)
    #expect(reopened.markdown(week: day) == markdown)
    #expect(!reopened.color(on: day.adding(days: 1)).isCustom)
    let oldColor = journal.color(on: day).rgb
    try journal.randomizeColor(on: day)
    #expect(journal.color(on: day).rgb != oldColor)
    #expect(!journal.color(on: day).isCustom)
    try disk.save(journal)
    #expect(try disk.load().color(on: day) == journal.color(on: day))
    let previousRandom = journal.color(on: day)
    try journal.randomizeColor(on: day)
    #expect(journal.color(on: day) != previousRandom)
    #expect(journal.entries == entries)
}

@Test func legacyJournalWithoutColorsStillLoads() throws {
    let legacy = Data(#"{"schemaVersion":1,"entries":{},"arrangements":{},"latestObservedDay":"2026-10-12"}"#.utf8)
    let journal = try JSONDecoder().decode(Journal.self, from: legacy)
    try journal.validate()
    #expect(journal.dayColors == nil)
    #expect(!journal.color(on: Day(rawValue: "2026-10-12")).isCustom)
}

@Test func invalidColorsAndDatesAreRejectedWithoutMutation() throws {
    let day = Day(rawValue: "2026-10-12")
    var journal = Journal()
    #expect(throws: JournalError.invalidData) { try journal.setColor(DayColor(rgb: 0x1000000), on: day) }
    #expect(throws: JournalError.invalidDate) { try journal.setColor(DayColor(rgb: 0), on: Day(rawValue: "2026-02-30")) }
    #expect(journal == Journal())
    let corrupt = Data(#"{"schemaVersion":1,"entries":{},"arrangements":{},"dayColors":{"2026-10-12":{"rgb":4294967295,"isCustom":true}}}"#.utf8)
    let decoded = try JSONDecoder().decode(Journal.self, from: corrupt)
    #expect(throws: JournalError.invalidData) { try decoded.validate() }
    try journal.setColor(DayColor(rgb: 0), on: day)
    try journal.setColor(DayColor(rgb: 0xFFFFFF), on: day.adding(days: 1))
    try journal.validate()
}

@Test func customHexInputIsValidatedAndNormalized() {
    #expect(DayColor(hex: " #aBc123 ")?.hex == "#ABC123")
    #expect(DayColor(hex: "000000")?.rgb == 0)
    #expect(DayColor(hex: "#FFFFFF")?.rgb == 0xFFFFFF)
    for invalid in ["", "#123", "#00000000", "12#3456", "GGFFFF", "ＦＦＦＦＦＦ", "#12 3456"] {
        #expect(DayColor(hex: invalid) == nil)
    }
}

@Test func aFutureDayCanHaveAColorWithoutAllowingEntries() throws {
    let now = Day(rawValue: "2026-10-13").date()!, future = Day(rawValue: "2026-10-14")
    var journal = Journal()
    try journal.setColor(DayColor(rgb: 0x709DB9), on: future)
    #expect(!journal.canEdit(future, now: now))
    #expect(journal.entries.isEmpty && journal.latestObservedDay == nil)
    #expect(throws: JournalError.futureDate) { try journal.append("Not yet", on: future, now: now) }
}
