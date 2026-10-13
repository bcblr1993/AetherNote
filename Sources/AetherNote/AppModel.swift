import AppKit
import SwiftUI
import AetherNoteCore

enum MaterialStyle: String, Codable, CaseIterable, Identifiable {
    case glass, paper, white
    var id: String { rawValue }
}
struct Preferences: Codable {
    var language = Language.system
    var material = MaterialStyle.glass
    var showWeekends = false
    var motion = true
    var edgeReveal = true
    var reminders = true
    var pinned = false
}

@MainActor final class AppModel: ObservableObject {
    let disk: JournalDisk
    let clock: () -> Date
    @Published private(set) var journal: Journal
    @Published var preferences: Preferences { didSet { savePreferences(); onPreferencesChanged?() } }
    @Published var now: Date
    @Published var week: Day
    @Published var errorMessage: String?
    @Published var toast: String?
    @Published var reminderPending = false
    @Published var drafts: [String: String] = [:]
    var hasUnsavedEdit = false
    var reminder: ReminderPolicy
    var onPreferencesChanged: (() -> Void)?
    var onReminderChanged: (() -> Void)?
    var onOpenDay: ((Day) -> Void)?
    private var draftSave: DispatchWorkItem?
    private var toastTask: Task<Void, Never>?

    init(directory: URL, clock: @escaping () -> Date = Date.init) throws {
        disk = JournalDisk(directory: directory); self.clock = clock
        let initial = clock(); now = initial; week = Day(initial).week().first!
        reminder = ReminderPolicy(startedAt: initial)
        journal = try disk.load()
        let prefsURL = directory.appendingPathComponent("preferences.json")
        preferences = (try? JSONDecoder().decode(Preferences.self, from: Data(contentsOf: prefsURL))) ?? Preferences()
        drafts = (try? JSONDecoder().decode([String: String].self, from: Data(contentsOf: directory.appendingPathComponent("drafts.json")))) ?? [:]
        if journal.observe(initial) { try disk.save(journal) }
    }
    var today: Day { Day(now) }
    var l: (String) -> String { { Copy.text($0, self.preferences.language) } }
    var reduceMotion: Bool { !preferences.motion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var allWeekDays: [Day] { week.week() }
    var visibleDays: [Day] { journal.arranged(allWeekDays.filter { preferences.showWeekends || (allWeekDays.firstIndex(of: $0) ?? 0) < 5 || !journal.records(on: $0).isEmpty || $0 == today }, week: week) }
    func weekday(_ day: Day) -> String {
        guard let date = day.date() else { return day.rawValue }
        let f = DateFormatter(); f.locale = preferences.language.locale; f.dateFormat = "EEE"; return f.string(from: date)
    }
    func entryCount(_ count: Int) -> String { "\(count) \(l(count == 1 ? "entry" : "entries"))" }
    func shortDate(_ day: Day) -> String { String(day.rawValue.suffix(5)).replacingOccurrences(of: "-", with: "/") }
    var weekLabel: String { "\(shortDate(allWeekDays[0])) — \(shortDate(allWeekDays[6]))" }
    func canEdit(_ day: Day) -> Bool { journal.canEdit(day, now: clock()) }
    func tick(sessionActive: Bool, editing: Bool, recentlyTyping: Bool) {
        let current = clock(), oldToday = today
        now = current
        if journal.latestObservedDay == nil || today > journal.latestObservedDay! {
            transact { $0.observe(current) }
        }
        if today != oldToday, week == oldToday.week().first { week = today.week().first! }
        reminder.enabled = preferences.reminders
        if reminder.isDue(at: current, sessionActive: sessionActive, isEditing: editing, recentlyTyping: recentlyTyping) {
            reminder.reminded(at: current); reminderPending = true; onReminderChanged?()
        }
    }
    @discardableResult func transact(_ change: (inout Journal) throws -> Void) -> Bool {
        do {
            var next = journal; try change(&next); try disk.save(next); journal = next; return true
        } catch let error as JournalError {
            switch error { case .futureDate: errorMessage = l("futureError"); case .empty: errorMessage = l("emptyError"); case .tooLong: errorMessage = l("longError"); default: errorMessage = error.localizedDescription }
        } catch { errorMessage = l("saveError") + "\n" + error.localizedDescription }
        return false
    }
    @discardableResult func append(_ text: String, day: Day) -> Bool {
        let date = clock()
        guard transact({ try $0.append(text, on: day, now: date) }) else { return false }
        now = date; drafts[day.rawValue] = nil; flushDrafts(); didRecord(); return true
    }
    @discardableResult func edit(_ entry: Entry, text: String, day: Day) -> Bool {
        guard transact({ try $0.edit(entry.id, text: text, on: day, now: clock()) }) else { return false }
        didRecord(); return true
    }
    func remove(_ entry: Entry, day: Day) { _ = transact { try $0.remove(entry.id, on: day, now: clock()) } }
    func didRecord() { reminder.recorded(at: clock()); reminderPending = false; onReminderChanged?() }
    func dismissReminder() { reminder.reminded(at: clock()); reminderPending = false; onReminderChanged?() }
    func setDraft(_ value: String, day: Day) {
        drafts[day.rawValue] = value.isEmpty ? nil : value
        draftSave?.cancel(); let task = DispatchWorkItem { [weak self] in self?.flushDrafts() }; draftSave = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
    }
    @discardableResult func flushDrafts() -> Bool { writePrivate(drafts, name: "drafts.json") }
    func savePreferences() { writePrivate(preferences, name: "preferences.json") }
    @discardableResult private func writePrivate<T: Encodable>(_ value: T, name: String) -> Bool {
        do {
            try FileManager.default.createDirectory(at: disk.directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let url = disk.directory.appendingPathComponent(name)
            try JSONEncoder().encode(value).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return true
        } catch { errorMessage = l("saveError"); return false }
    }
    func dayColor(_ day: Day) -> DayColor { journal.color(on: day) }
    func setColor(_ rgb: UInt32, day: Day) { _ = transact { try $0.setColor(DayColor(rgb: rgb), on: day) } }
    func randomizeColor(_ day: Day) { _ = transact { try $0.randomizeColor(on: day) } }
    func reorder(_ day: Day, to target: Day) {
        var order = visibleDays
        guard let a = order.firstIndex(of: day), let b = order.firstIndex(of: target), a != b else { return }
        order.remove(at: a); order.insert(day, at: b)
        _ = transact { try $0.arrange(order, week: week) }
    }
    func move(_ day: Day, by offset: Int) {
        let days = visibleDays; guard let i = days.firstIndex(of: day), days.indices.contains(i + offset) else { return }
        reorder(day, to: days[i + offset])
    }
    func tidy() { if transact({ $0.tidy(week: week) }) { showToast(l("tidied")) } }
    func navigateWeek(_ offset: Int) { week = week.adding(days: 7 * offset) }
    func copy(_ text: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string); showToast(l("copied")) }
    func showToast(_ text: String) { toastTask?.cancel(); toast = text; toastTask = Task { try? await Task.sleep(for: .seconds(2)); if !Task.isCancelled { toast = nil } } }
    func exportWeek() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "AetherNote-\(week.rawValue).md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try journal.markdown(week: week).write(to: url, atomically: true, encoding: .utf8) } catch { errorMessage = error.localizedDescription }
    }
    func exportBackup() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "AetherNote-backup-\(today.rawValue).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; try encoder.encode(journal).write(to: url, options: .atomic) } catch { errorMessage = error.localizedDescription }
    }
    func bringDraftToToday(from day: Day) {
        guard let draft = drafts[day.rawValue], !draft.isEmpty else { return }
        let current = Day(clock()); now = clock()
        let existing = drafts[current.rawValue] ?? ""
        setDraft(existing.isEmpty ? draft : existing + "\n" + draft, day: current)
        onOpenDay?(current)
    }
}
