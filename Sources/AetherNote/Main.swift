import AppKit
import SwiftUI
import Carbon
import AetherNoteCore

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var model: AppModel!
    var status: NSStatusItem!
    var line: FloatingPanel!
    var editor: NSWindow?
    var review: NSWindow?
    var settings: NSWindow?
    var timer: Timer?
    var mouseMonitor: Any?
    var localMonitor: Any?
    var hotKeys: [EventHotKeyRef] = []
    var hotKeyHandler: EventHandlerRef?
    var sessionActive = true
    var lastEdge = Date.distantPast
    var hideWork: DispatchWorkItem?
    var journalLock: Int32 = -1

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let args = ProcessInfo.processInfo.arguments
        let explicitDirectory = args.firstIndex(of: "--data-dir").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
        let directory = explicitDirectory.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("AetherNote", isDirectory: true)
        let firstLaunch = !FileManager.default.fileExists(atPath: directory.appendingPathComponent("journal.json").path)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            journalLock = Darwin.open(directory.appendingPathComponent(".writer.lock").path, O_CREAT | O_RDWR, 0o600)
            guard journalLock >= 0, flock(journalLock, LOCK_EX | LOCK_NB) == 0 else {
                NSRunningApplication.runningApplications(withBundleIdentifier: "com.aethernative.AetherNote").first { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }?.activate(options: [])
                NSApp.terminate(nil); return
            }
            if args.contains("--demo"), explicitDirectory != nil { try seedDemo(directory) }
            model = try AppModel(directory: directory)
        } catch {
            let alert = NSAlert(); alert.messageText = "AetherNote"; alert.informativeText = error.localizedDescription + "\n" + directory.path
            alert.addButton(withTitle: "OK"); alert.runModal(); NSApp.terminate(nil); return
        }
        model.onOpenDay = { [weak self] day in self?.openDay(day) }
        model.onPreferencesChanged = { [weak self] in
            guard let self else { return }
            if !model.preferences.reminders { model.reminderPending = false }
            updateStatus()
            createApplicationMenu()
            review?.title = model.l("review"); settings?.title = model.l("settings")
        }
        model.onReminderChanged = { [weak self] in self?.updateStatus() }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.target = self; status.button?.action = #selector(statusClicked)
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateStatus()
        createLine(); registerShortcuts(); createApplicationMenu()
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in self?.mouseMoved() }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in self?.mouseMoved(); return event }
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(resume), name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(resume), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(suspend), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(suspend), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        if firstLaunch || args.contains("--show") || model.preferences.pinned { showLine() }
        if args.contains("--editor") { openDay(model.today) }
        if args.contains("--settings") { openSettings() }
        if args.contains("--review") { openReview() }
    }
    func createApplicationMenu() {
        let menu = NSMenu(), application = NSMenuItem(), submenu = NSMenu()
        submenu.addItem(withTitle: model.l("settings"), action: #selector(openSettings), keyEquivalent: ",").target = self
        submenu.addItem(.separator())
        submenu.addItem(withTitle: model.l("quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        application.submenu = submenu; menu.addItem(application)
        let edit = NSMenuItem(title: model.l("editMenu"), action: nil, keyEquivalent: ""), editMenu = NSMenu(title: model.l("editMenu"))
        for (name, action, key) in [("undo", Selector(("undo:")), "z"), ("cut", #selector(NSText.cut(_:)), "x"), ("copyMenu", #selector(NSText.copy(_:)), "c"), ("paste", #selector(NSText.paste(_:)), "v"), ("selectAll", #selector(NSText.selectAll(_:)), "a")] {
            editMenu.addItem(withTitle: model.l(name), action: action, keyEquivalent: key)
        }
        edit.submenu = editMenu; menu.addItem(edit); NSApp.mainMenu = menu
    }
    func createLine() {
        line = FloatingPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        line.isFloatingPanel = true; line.level = .floating; line.isOpaque = false; line.backgroundColor = .clear
        line.hasShadow = false; line.hidesOnDeactivate = false; line.acceptsMouseMovedEvents = true
        line.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        line.contentView = NSHostingView(rootView: LineView(openDay: { [weak self] in self?.openDay($0) }, review: { [weak self] in self?.openReview() }, settings: { [weak self] in self?.openSettings() }, hide: { [weak self] in self?.hideLine() }).environmentObject(model))
    }
    func showLine() {
        hideWork?.cancel()
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main!
        let width = min(1200, screen.visibleFrame.width - 32)
        line.setFrame(NSRect(x: screen.visibleFrame.midX - width / 2, y: screen.visibleFrame.maxY - 365, width: width, height: 365), display: true)
        line.alphaValue = model.reduceMotion ? 1 : 0
        line.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in context.duration = model.reduceMotion ? 0 : 0.25; line.animator().alphaValue = 1 }
    }
    func hideLine() { hideWork?.cancel(); line.orderOut(nil) }
    @objc func toggleLine() { line.isVisible ? hideLine() : showLine() }
    func mouseMoved() {
        guard let model, let line, sessionActive else { return }
        let point = NSEvent.mouseLocation
        if model.preferences.edgeReveal && !line.isVisible,
           let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }),
           point.y >= screen.frame.maxY - 2, abs(point.x - screen.frame.midX) < 180,
           Date().timeIntervalSince(lastEdge) > 1.5 {
            lastEdge = Date(); showLine()
        } else if line.isVisible && !model.preferences.pinned {
            if line.frame.insetBy(dx: -10, dy: -15).contains(point) { hideWork?.cancel(); hideWork = nil }
            else if hideWork == nil {
                let work = DispatchWorkItem { [weak self] in self?.hideLine(); self?.hideWork = nil }
                hideWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
            }
        }
    }
    func updateStatus() {
        guard let status else { return }
        status.button?.image = NSImage(systemSymbolName: model.reminderPending ? "note.text.badge.plus" : "note.text", accessibilityDescription: "AetherNote")
        status.button?.toolTip = model.reminderPending ? model.l("reminderPrompt") : "AetherNote · ⌃⌥N"
    }
    @objc func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            for (key, action) in [("add", #selector(quickAdd)), ("show", #selector(toggleLine)), ("review", #selector(openReview)), ("settings", #selector(openSettings))] {
                menu.addItem(withTitle: model.l(key), action: action, keyEquivalent: "").target = self
            }
            if model.reminderPending { menu.addItem(withTitle: model.l("dismiss"), action: #selector(dismissReminder), keyEquivalent: "").target = self }
            menu.addItem(.separator()); menu.addItem(withTitle: model.l("quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            status.menu = menu; status.button?.performClick(nil); status.menu = nil
        } else if model.reminderPending { quickAdd() }
        else { toggleLine() }
    }
    @objc func quickAdd() { openDay(Day(Date())) }
    @objc func dismissReminder() { model.dismissReminder() }
    func openDay(_ day: Day) {
        model.now = Date(); model.dismissReminder()
        model.flushDrafts()
        editor?.close()
        editor = makeWindow(title: "AetherNote · \(day.rawValue)", size: NSSize(width: 520, height: 620), root: DayEditor(day: day).environmentObject(model))
        present(editor!)
    }
    @objc func openReview() {
        if review == nil { review = makeWindow(title: model.l("review"), size: NSSize(width: 710, height: 720), root: ReviewView().environmentObject(model)) }
        present(review!)
    }
    @objc func openSettings() {
        if settings == nil { settings = makeWindow(title: model.l("settings"), size: NSSize(width: 550, height: 700), root: SettingsView(previewReminder: { [weak self] in
            guard let self else { return }; model.reminderPending = true; updateStatus(); model.showToast(model.l("reminderPrompt"))
        }).environmentObject(model)) }
        present(settings!)
    }
    func makeWindow<V: View>(title: String, size: NSSize, root: V) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = title; window.titlebarAppearsTransparent = true; window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false; window.delegate = self
        // Keep content below traffic lights while retaining the system's window glass.
        window.contentView = NSHostingView(rootView: root)
        window.minSize = NSSize(width: size.width, height: min(size.height, 590)); window.center()
        return window
    }
    func present(_ window: NSWindow) { NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil) }
    func windowWillClose(_ notification: Notification) { model.flushDrafts() }
    func tick() {
        let typing = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown) < 60
        model.tick(sessionActive: sessionActive, editing: editor?.isKeyWindow == true, recentlyTyping: typing)
    }
    @objc func resume() { sessionActive = true; model.reminder.resumed(at: Date()); tick() }
    @objc func suspend() { sessionActive = false; model.flushDrafts(); hideLine() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showLine(); return true }
    func applicationWillTerminate(_ notification: Notification) {
        model?.flushDrafts(); timer?.invalidate()
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }; if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        hotKeys.forEach { UnregisterEventHotKey($0) }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
        if journalLock >= 0 { flock(journalLock, LOCK_UN); Darwin.close(journalLock) }
    }
    func registerShortcuts() {
        var specification = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let delegate = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { if id.id == 1 { delegate.quickAdd() } else { delegate.toggleLine() } }
            return noErr
        }, 1, &specification, pointer, &hotKeyHandler)
        for (id, key) in [(UInt32(1), UInt32(kVK_ANSI_N)), (UInt32(2), UInt32(kVK_ANSI_L))] {
            var ref: EventHotKeyRef?
            if RegisterEventHotKey(key, UInt32(controlKey | optionKey), EventHotKeyID(signature: 0x41454E54, id: id), GetApplicationEventTarget(), 0, &ref) == noErr, let ref { hotKeys.append(ref) }
        }
    }
    func seedDemo(_ directory: URL) throws {
        let disk = JournalDisk(directory: directory)
        guard !FileManager.default.fileExists(atPath: disk.file.path) else { return }
        var journal = Journal()
        let today = Day(Date()), monday = today.week().first!
        let samples = ["梳理这一周的计划\n散步二十分钟", "完成一个小功能\n和朋友喝了杯咖啡", "把复杂的问题写清楚", "读了几页书\n整理桌面", "做完了第一版\n给自己留一点空白", "去了公园", "好好休息"]
        for i in -7..<1 {
            let day = monday.adding(days: i)
            if day <= today, let date = day.date() { try journal.append(samples[(i + 7) % 7], on: day, now: date) }
        }
        if today != monday { try journal.append("做过的小事，也值得记住。", on: today, now: Date()) }
        try disk.save(journal)
    }
}

@main enum AetherNoteMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
