import Foundation
import Testing
import AetherNoteCore
@testable import AetherNote

@Test func legacyPreferencesKeepUserChoicesWhenAddingLineControl() throws {
    let data = Data(#"{"language":"ja","material":"paper","showWeekends":true,"motion":false,"edgeReveal":true,"reminders":false,"pinned":true}"#.utf8)
    let prefs = try JSONDecoder().decode(Preferences.self, from: data)
    #expect(prefs.lineEnabled)
    #expect(prefs.language == .ja && prefs.material == .paper)
    #expect(prefs.showWeekends && !prefs.motion && prefs.edgeReveal && !prefs.reminders && prefs.pinned)
    let fresh = try JSONDecoder().decode(Preferences.self, from: Data("{}".utf8))
    #expect(fresh.lineEnabled && !fresh.edgeReveal)
}

@Test @MainActor func disabledClotheslineSurvivesReloadAndKeepsPinChoice() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let model = try AppModel(directory: directory)
    model.preferences.pinned = true
    model.preferences.edgeReveal = true
    model.preferences.lineEnabled = false
    let restored = try AppModel(directory: directory)
    #expect(!restored.preferences.lineEnabled)
    #expect(restored.preferences.edgeReveal && restored.preferences.pinned)
}

@Test @MainActor func tidyOnlyChangesSelectedWeekOrderAndPreservesNotesColorsAndDrafts() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let now = ISO8601DateFormatter().date(from: "2026-10-14T12:00:00Z")!
    let model = try AppModel(directory: directory, clock: { now })
    let week = model.week, previous = week.adding(days: -7)
    #expect(model.append("keep this note", day: week))
    model.setColor(0x83A797, day: week)
    model.setDraft("keep this draft", day: week)
    model.flushDrafts()
    #expect(model.transact {
        try $0.arrange(Array(week.week().reversed()), week: week)
        try $0.arrange(Array(previous.week().reversed()), week: previous)
    })
    let before = model.journal, draftFile = directory.appendingPathComponent("drafts.json")
    let draft = try Data(contentsOf: draftFile)
    model.tidy()
    let reloaded = try model.disk.load()
    #expect(reloaded.arranged(week.week(), week: week) == week.week())
    #expect(reloaded.arrangements[previous.rawValue] == before.arrangements[previous.rawValue])
    #expect(reloaded.entries == before.entries)
    #expect(reloaded.color(on: week) == before.color(on: week))
    #expect(try Data(contentsOf: draftFile) == draft)
}

@Test @MainActor func bringDraftToTodayMovesDraftAndClearsSourceDay() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let now = ISO8601DateFormatter().date(from: "2026-10-14T12:00:00Z")!
    let model = try AppModel(directory: directory, clock: { now })
    let futureDay = model.today.adding(days: 2)
    var openedDay: Day?
    model.onOpenDay = { openedDay = $0 }
    model.setDraft("future idea", day: futureDay)
    model.bringDraftToToday(from: futureDay)
    #expect(model.drafts[model.today.rawValue] == "future idea")
    #expect(model.drafts[futureDay.rawValue] == nil)
    #expect(openedDay == model.today)
}

@Test @MainActor func weekLabelIncludesYearOnlyOutsideCurrentYearOrAcrossYears() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let now = Day(rawValue: "2026-10-14").date()!
    let model = try AppModel(directory: directory, clock: { now })
    #expect(model.weekLabel(for: Day(rawValue: "2026-10-12"), today: Day(rawValue: "2026-10-14")) == "10/12 — 10/18")
    #expect(model.weekLabel(for: Day(rawValue: "2025-10-13"), today: Day(rawValue: "2026-10-14")) == "2025/10/13 — 10/19")
    #expect(model.weekLabel(for: Day(rawValue: "2026-12-28"), today: Day(rawValue: "2026-10-14")) == "2026/12/28 — 2027/01/03")
}

@Test @MainActor func restoreJournalReplacesDataAndWritesRollingBackup() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let now = Day(rawValue: "2026-10-14").date()!
    let model = try AppModel(directory: directory, clock: { now })
    #expect(model.append("initial entry", day: model.today))
    let prior = model.journal

    var imported = Journal()
    let pastDay = Day(rawValue: "2026-10-01")
    try imported.append("restored entry", on: pastDay, now: pastDay.date()!)
    try imported.setColor(DayColor(rgb: 0x83A797), on: pastDay)

    #expect(model.restoreJournal(imported))
    #expect(try model.disk.load() == imported)
    let rolling = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: model.disk.backup))
    #expect(rolling == prior)
}

@Test @MainActor func tickAdvancesTodayAndWeekAcrossMidnight() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let firstDay = Day(rawValue: "2026-10-18")
    let secondDay = Day(rawValue: "2026-10-19")
    var current = Calendar.journal.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 23, minute: 59))!
    let model = try AppModel(directory: directory, clock: { current })
    #expect(model.today == firstDay)
    #expect(model.week == Day(rawValue: "2026-10-12"))

    current = Calendar.journal.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 0, minute: 1))!
    model.tick(sessionActive: true, editing: false, recentlyTyping: false)
    #expect(model.today == secondDay)
    #expect(model.week == Day(rawValue: "2026-10-19"))
}
