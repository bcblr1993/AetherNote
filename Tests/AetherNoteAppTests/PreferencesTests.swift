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
