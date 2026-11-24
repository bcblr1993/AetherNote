import SwiftUI
import AppKit
import ServiceManagement
import AetherNoteCore

enum InputMode { case compose, edit }

final class LineTextView: NSTextView {
    var mode: InputMode = .compose
    var submit: (() -> Void)?
    var cancel: (() -> Void)?
    private var focusObserver: NSObjectProtocol?
    private var needsInitialFocus = true
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let focusObserver { NotificationCenter.default.removeObserver(focusObserver); self.focusObserver = nil }
        guard let window, needsInitialFocus else { return }
        focusObserver = NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
            self?.focusInitially()
        }
        DispatchQueue.main.async { [weak self] in self?.focusInitially() }
    }
    private func focusInitially() {
        guard needsInitialFocus, let window, window.isKeyWindow else { return }
        if window.makeFirstResponder(self) {
            needsInitialFocus = false
            if mode == .edit { setSelectedRange(NSRange(location: (string as NSString).length, length: 0)) }
            if let focusObserver { NotificationCenter.default.removeObserver(focusObserver); self.focusObserver = nil }
        }
    }
    deinit { if let focusObserver { NotificationCenter.default.removeObserver(focusObserver) } }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 && !hasMarkedText() {
            cancel?(); return
        }
        if event.keyCode == 36 || event.keyCode == 76 {
            if !hasMarkedText() {
                switch mode {
                case .compose:
                    if !event.modifierFlags.contains(.shift) { submit?(); return }
                case .edit:
                    if event.modifierFlags.contains(.command) { submit?(); return }
                }
            }
        }
        super.keyDown(with: event)
    }
}
struct LineInput: NSViewRepresentable {
    @Binding var text: String
    var label: String
    var mode: InputMode = .compose
    var submit: () -> Void
    var cancel: (() -> Void)? = nil
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        let view = LineTextView()
        view.isRichText = false; view.font = .systemFont(ofSize: 15); view.drawsBackground = false
        view.textColor = .labelColor; view.insertionPointColor = .controlAccentColor
        view.textContainerInset = NSSize(width: mode == .edit ? 8 : 12, height: mode == .edit ? 10 : 12)
        view.isVerticallyResizable = true; view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]; view.textContainer?.widthTracksTextView = true
        view.delegate = context.coordinator; view.mode = mode; view.submit = submit; view.cancel = cancel
        view.setAccessibilityLabel(label); view.setAccessibilityIdentifier(mode == .compose ? "entry-input" : "entry-edit-input")
        scroll.documentView = view
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? LineTextView else { return }
        context.coordinator.parent = self
        view.mode = mode; view.submit = submit; view.cancel = cancel; view.setAccessibilityLabel(label)
        view.setAccessibilityIdentifier(mode == .compose ? "entry-input" : "entry-edit-input")
        view.appearance = NSAppearance(named: context.environment.colorScheme == .dark ? .darkAqua : .aqua)
        if view.string != text && !view.hasMarkedText() { view.string = text }
    }
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: LineInput
        init(_ parent: LineInput) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.text = view.string
        }
    }
}

struct DayEditorHost: View {
    @EnvironmentObject var model: AppModel
    var close: () -> Void
    var returnToWeek: (Day) -> Void
    var openReview: (Day) -> Void
    var body: some View {
        DayEditor(day: model.activeDay, close: close, returnToWeek: returnToWeek, openReview: openReview)
            .id(model.editorSession)
    }
}

struct DayEditor: View {
    @EnvironmentObject var model: AppModel
    let day: Day
    var close: () -> Void = {}
    var returnToWeek: (Day) -> Void = { _ in }
    var openReview: (Day) -> Void = { _ in }
    @State private var editing: Entry?
    @State private var editText = ""
    @State private var deleting: Entry?
    private var records: [Entry] { model.journal.records(on: day) }
    private var draft: Binding<String> { Binding(get: { model.drafts[day.rawValue] ?? "" }, set: { model.setDraft($0, day: day) }) }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { returnToWeek(day) } label: {
                    Label(model.l("backToWeek"), systemImage: "chevron.left").fixedSize()
                }.buttonStyle(GlassButton()).accessibilityIdentifier("back-to-week")
                Divider().frame(height: 16)
                Button { model.onOpenDay?(day.adding(days: -1)) } label: {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .medium)).frame(width: 32, height: 32)
                }.buttonStyle(GlassButton(compact: true)).help(model.l("prevDay")).accessibilityLabel(model.l("prevDay"))
                    .keyboardShortcut("[", modifiers: .command)
                if day != model.today {
                    Button(model.l("today")) { model.onOpenDay?(model.today) }.buttonStyle(GlassButton())
                }
                Button { model.onOpenDay?(day.adding(days: 1)) } label: {
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).frame(width: 32, height: 32)
                }.buttonStyle(GlassButton(compact: true)).disabled(day >= model.today)
                    .help(model.l("nextDay")).accessibilityLabel(model.l("nextDay"))
                    .keyboardShortcut("]", modifiers: .command)
                Spacer()
                IconButton(symbol: "book.closed", title: model.l("review")) { openReview(day) }
                    .accessibilityIdentifier("editor-open-review")
            }.padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 10)
            HStack(alignment: .top) {
                PanelHeading(symbol: "square.and.pencil", title: model.weekday(day), subtitle: day.rawValue, tint: model.dayColor(day).tint)
                Spacer()
                StatusPill(text: model.l(day == model.today ? "today" : day < model.today ? "editable" : "future"), accent: day == model.today)
                DayColorButton(day: day)
                IconButton(symbol: "doc.on.doc", title: model.l("copy")) { model.copy(records.map(\.text).joined(separator: "\n")) }.disabled(records.isEmpty)
            }.padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 16)
            VStack(spacing: 0) {
                HStack {
                    Text(model.l(day > model.today ? "future" : (day < model.today ? "historyHint" : "savedLocally"))).font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Text(model.entryCount(records.count)).font(.system(size: 11, weight: .medium)).monospacedDigit().foregroundStyle(.secondary)
                }.padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 12)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            if records.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: day > model.today ? "calendar.badge.clock" : "text.badge.plus").font(.system(size: 30, weight: .light)).foregroundStyle(Color.accentColor.opacity(0.7))
                                    Text(model.l(day == model.today ? "empty" : (day > model.today ? "futureHint" : "noEntries"))).font(.system(size: 14, weight: .medium))
                                }.foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 20)
                            }
                            ForEach(records) { entry in entryRow(entry).transition(.opacity) }
                            .animation(model.reduceMotion ? nil : .easeOut(duration: 0.18), value: records.count)
                            Color.clear.frame(height: 1).id("bottom")
                        }.padding(.horizontal, 20).padding(.vertical, 4)
                    }.onChange(of: records.count) { _, _ in
                        withAnimation(model.reduceMotion ? nil : .easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
                if editing == nil && (model.canEdit(day) || !draft.wrappedValue.isEmpty || model.toast != nil) {
                    composer.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 18)
                }
            }.background(Color(nsColor: .windowBackgroundColor).opacity(0.94), in: RoundedRectangle(cornerRadius: 20))
        }.padding(.top, 28).noteSurface().ignoresSafeArea().frame(minWidth: 500, minHeight: 490)
        .onChange(of: editing?.id) { _, _ in updateEditingState() }
        .onChange(of: editText) { _, _ in updateEditingState() }
        .onDisappear { model.hasUnsavedEdit = false }
        .onKeyPress(.escape) {
            if editing == nil { close(); return .handled }
            return .ignored
        }
        .alert(model.l("deleteConfirm"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button(model.l("cancel"), role: .cancel) { deleting = nil }
            Button(model.l("delete"), role: .destructive) { if let deleting { model.remove(deleting, day: day) }; deleting = nil }
        }
    }
    private func updateEditingState() { model.hasUnsavedEdit = editing != nil && editText != editing?.text }
    private func saveEdit(_ entry: Entry) {
        if model.edit(entry, text: editText, day: day) { editing = nil }
    }
    private var composer: some View {
        let trimmed = draft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let nonEmptyLines = draft.wrappedValue.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.count
        return VStack(alignment: .leading, spacing: 10) {
            if model.canEdit(day) {
                HStack {
                    Label(model.l("add"), systemImage: "plus.circle").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    if draft.wrappedValue.count >= 3_500 {
                        StatusPill(text: "\(draft.wrappedValue.count) / 4000", accent: draft.wrappedValue.count > 4_000)
                    }
                    if !draft.wrappedValue.isEmpty { Text(model.l("draft")).font(.system(size: 10)).foregroundStyle(.secondary) }
                }
                ZStack(alignment: .topLeading) {
                    if draft.wrappedValue.isEmpty { Text(model.l("placeholder")).font(.system(size: 15)).foregroundStyle(.secondary).padding(.horizontal, 17).padding(.vertical, 12).allowsHitTesting(false) }
                    LineInput(text: draft, label: model.l("add"), mode: .compose, submit: { _ = model.append(draft.wrappedValue, day: day, splitLines: false) }, cancel: close).frame(height: 68)
                }.background(.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 10))
                HStack(spacing: 8) {
                    Text(model.l("inputHint")).font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    if nonEmptyLines > 1 {
                        Button { _ = model.append(draft.wrappedValue, day: day, splitLines: true) } label: {
                            Text("\(model.l("splitAppend")) (\(nonEmptyLines))").fixedSize()
                        }.buttonStyle(GlassButton()).accessibilityIdentifier("split-append")
                    }
                    Button { _ = model.append(draft.wrappedValue, day: day, splitLines: false) } label: {
                        Label(model.l("append"), systemImage: "arrow.up").fixedSize()
                    }.buttonStyle(AccentButton()).disabled(trimmed.isEmpty)
                }
            } else if !draft.wrappedValue.isEmpty {
                Text(model.l("draft")).font(.caption)
                Text(draft.wrappedValue).font(.caption).textSelection(.enabled).lineLimit(4)
                Button(model.l("draftToday")) { model.bringDraftToToday(from: day) }.buttonStyle(GlassButton())
            }
            if let toast = model.toast { Text(toast).font(.caption).foregroundStyle(Color.accentColor) }
        }.padding(14).background(Color(nsColor: .textBackgroundColor).opacity(0.85), in: RoundedRectangle(cornerRadius: 16)).insetSurface(selected: model.canEdit(day), tint: model.dayColor(day).tint)
    }
    private func entryRow(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: editing?.id == entry.id ? "pencil" : "checkmark.circle.fill").foregroundStyle(Color.accentColor.opacity(0.7))
                Text(model.entryTime(entry.createdAt)).monospacedDigit().foregroundStyle(.secondary)
                if entry.modifiedAt > entry.createdAt.addingTimeInterval(60) {
                    Text("· \(model.l("edited"))").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                if model.canEdit(day) && editing?.id != entry.id {
                    Menu {
                        Button(model.l("edit")) { editing = entry; editText = entry.text }
                        Button(model.l("delete"), role: .destructive) { deleting = entry }
                    } label: { Image(systemName: "ellipsis").frame(width: 28, height: 20) }
                        .menuStyle(.borderlessButton).fixedSize().accessibilityLabel(model.l("more"))
                        .disabled(editing != nil)
                }
            }.font(.system(size: 11, weight: .medium))
            if editing?.id == entry.id {
                LineInput(text: $editText, label: model.l("edit"), mode: .edit, submit: { saveEdit(entry) }, cancel: { editing = nil })
                    .frame(height: 104)
                    .background(.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                HStack {
                    Text(model.l("editHint")).font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer()
                    Button(model.l("cancel")) { editing = nil }.buttonStyle(GlassButton())
                    Button(model.l("save")) { saveEdit(entry) }
                        .buttonStyle(AccentButton()).disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                Text(entry.text).font(.system(size: 15)).lineSpacing(5).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(14).background(Color(nsColor: .textBackgroundColor).opacity(0.75), in: RoundedRectangle(cornerRadius: 16)).insetSurface(selected: editing?.id == entry.id, tint: model.dayColor(day).tint)
    }
}

struct ReviewView: View {
    @EnvironmentObject var model: AppModel
    var showLine: () -> Void = {}
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @State private var showDatePicker = false
    @State private var jumpDate = Date()
    @State private var scrollTarget: Day?
    private var total: Int { model.allWeekDays.reduce(0) { $0 + model.journal.records(on: $1).count } }
    private var recordedDays: Int { model.allWeekDays.filter { !model.journal.records(on: $0).isEmpty }.count }
    private var searchQuery: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var searchMatches: [Journal.SearchMatch] { model.journal.search(searchQuery) }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                PanelHeading(symbol: "rectangle.stack", title: model.l("review"), subtitle: model.l("weekOverview"))
                Spacer()
                IconButton(symbol: "calendar", title: model.l("jumpToDate")) {
                    jumpDate = model.week.date() ?? model.now
                    showDatePicker.toggle()
                }.popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
                    VStack(spacing: 12) {
                        DatePicker(model.l("jumpToDate"), selection: $jumpDate, displayedComponents: [.date])
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .environment(\.locale, model.preferences.language.locale)
                        HStack {
                            Button(model.l("today")) {
                                jumpDate = model.now
                                model.returnToCurrentWeek()
                                scrollTarget = model.today
                                showDatePicker = false
                            }.buttonStyle(GlassButton())
                            Spacer()
                            Button(model.l("jumpToDate")) {
                                let picked = Day(jumpDate)
                                model.jumpTo(date: jumpDate)
                                scrollTarget = picked
                                showDatePicker = false
                            }.buttonStyle(AccentButton())
                        }
                    }.padding(16).frame(width: 280)
                }
                if model.preferences.lineEnabled {
                    IconButton(symbol: "line.3.horizontal.decrease", title: model.l("show"), action: showLine)
                        .accessibilityIdentifier("review-show-line")
                }
                IconButton(symbol: "chevron.left", title: model.l("previous")) { model.navigateWeek(-1) }
                IconButton(symbol: "chevron.right", title: model.l("next")) { model.navigateWeek(1) }
            }.padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 14)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.secondary)
                TextField(model.l("search"), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($searchFocused)
                    .accessibilityIdentifier("review-search")
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundStyle(.secondary)
                    }.buttonStyle(.plain).accessibilityLabel(model.l("clearSearch"))
                }
            }
            .padding(.horizontal, 12).frame(height: 34)
            .insetSurface()
            .padding(.horizontal, 24).padding(.bottom, 12)
            .background { Button("") { searchFocused = true }.keyboardShortcut("f", modifiers: .command).hidden() }
            if searchQuery.isEmpty {
                HStack(spacing: 10) {
                    Button(model.weekLabel) { model.returnToCurrentWeek() }.buttonStyle(GlassButton()).help(model.l("thisWeek"))
                    CurrentWeekButton()
                    Spacer()
                    StatusPill(text: model.entryCount(total), accent: true)
                    StatusPill(text: "\(model.l("recordedDays")) · \(recordedDays) / 7")
                }.padding(.horizontal, 24).padding(.bottom, 14)
                ScrollViewReader { proxy in
                    VStack(spacing: 16) {
                        HStack(spacing: 8) {
                            ForEach(model.allWeekDays) { day in
                                Button {
                                    withAnimation(model.reduceMotion ? nil : .easeInOut(duration: 0.25)) { proxy.scrollTo(day.id, anchor: .top) }
                                } label: {
                                    VStack(spacing: 6) {
                                        Text(model.weekday(day)).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                                        Text(String(day.rawValue.suffix(2))).font(.system(size: 20, weight: .medium, design: .rounded))
                                        Circle().fill(model.journal.records(on: day).isEmpty ? Color.primary.opacity(0.13) : model.dayColor(day).tint).frame(width: 4, height: 4)
                                    }.frame(maxWidth: .infinity).padding(.vertical, 12).insetSurface(selected: day == model.today, tint: model.dayColor(day).tint)
                                }.buttonStyle(.plain).help(day.rawValue)
                            }
                        }.padding(.horizontal, 24)
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(model.allWeekDays) { day in reviewDay(day, entries: model.journal.records(on: day)).id(day.id) }
                            }.padding(.horizontal, 24).padding(.bottom, 8)
                        }
                    }
                    .onChange(of: scrollTarget) { _, target in
                        guard let target else { return }
                        DispatchQueue.main.async {
                            withAnimation(model.reduceMotion ? nil : .easeInOut(duration: 0.25)) { proxy.scrollTo(target.id, anchor: .top) }
                            scrollTarget = nil
                        }
                    }
                }
            } else {
                let matchedEntries = searchMatches.reduce(0) { $0 + $1.entries.count }
                HStack(spacing: 10) {
                    StatusPill(text: model.entryCount(matchedEntries), accent: true)
                    StatusPill(text: "\(searchMatches.count)")
                    Spacer()
                }.padding(.horizontal, 24).padding(.bottom, 14)
                if searchMatches.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "magnifyingglass").font(.system(size: 28, weight: .light)).foregroundStyle(.secondary)
                        Text(model.l("noSearchResults")).font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
                        Spacer()
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(searchMatches) { match in
                                reviewDay(match.day, entries: match.entries, showFullDate: true)
                            }
                        }.padding(.horizontal, 24).padding(.bottom, 8)
                    }
                }
            }
            HStack {
                Label(model.toast ?? model.l("savedLocally"), systemImage: "checkmark.shield").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button { model.exportWeek() } label: { Label(model.l("export"), systemImage: "square.and.arrow.up") }.buttonStyle(GlassButton())
                Button { model.copy(model.journal.markdown(week: model.week)) } label: { Label(model.l("copyWeek"), systemImage: "doc.on.doc") }.buttonStyle(AccentButton())
            }.padding(20)
        }.padding(.top, 28).noteSurface().ignoresSafeArea().frame(minWidth: 680, minHeight: 570)
    }
    private func reviewDay(_ day: Day, entries: [Entry], showFullDate: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 4) {
                Text(String(day.rawValue.suffix(2))).font(.system(size: 25, weight: .medium, design: .rounded))
                Text(model.weekday(day)).font(.system(size: 10)).foregroundStyle(.secondary)
                if showFullDate {
                    Text(day.rawValue).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                }
            }.frame(width: showFullDate ? 68 : 46).padding(.vertical, 8).background(model.dayColor(day).tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 12) {
                if entries.isEmpty {
                    Text(model.l(day > model.today ? "future" : "noEntries")).font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical, 14)
                }
                ForEach(entries) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(model.dayColor(day).tint).frame(width: 4, height: 4).padding(.top, 8)
                        Text(entry.text).font(.system(size: 14)).lineSpacing(4).textSelection(.enabled)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if model.canEdit(day) {
                IconButton(symbol: "arrow.up.right", title: model.l("edit")) { model.onOpenDay?(day) }
            }
        }.padding(16).insetSurface(tint: model.dayColor(day).tint)
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var updates: AppUpdates
    var previewReminder: () -> Void
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                PanelHeading(symbol: "slider.horizontal.3", title: model.l("settings"), subtitle: model.l("settingsHint"))
                Spacer()
                StatusPill(text: "v\(AppUpdates.version)")
            }.padding(24)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("clothesline", symbol: "rectangle.topthird.inset.filled") {
                        settingToggle("lineEnabled", value: $model.preferences.lineEnabled)
                        Text(model.l("lineControlHint")).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).lineSpacing(3)
                        Divider().opacity(0.5)
                        settingToggle("edge", value: $model.preferences.edgeReveal).disabled(!model.preferences.lineEnabled)
                        Text(model.l("edgeHint")).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).lineSpacing(3)
                        HStack {
                            Text(model.weekLabel).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                            Spacer()
                            Button { model.tidy() } label: { Label(model.l("tidy"), systemImage: "sparkles") }
                                .buttonStyle(GlassButton()).help(model.l("tidyHint")).accessibilityIdentifier("tidy-line-settings")
                        }
                    }
                    section("appearance", symbol: "paintpalette") {
                        HStack {
                            Text(model.l("language"))
                            Spacer()
                            Picker(model.l("language"), selection: $model.preferences.language) { ForEach(Language.allCases) { Text($0.title).tag($0) } }
                                .labelsHidden().pickerStyle(.segmented).frame(width: 330)
                        }
                        Divider().opacity(0.5)
                        Text(model.l("theme")).font(.system(size: 11)).foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            ForEach(MaterialStyle.allCases) { style in
                                Button { model.preferences.material = style } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: style == .glass ? "drop.halffull" : style == .paper ? "doc.text" : "square").font(.system(size: 22, weight: .light))
                                        Text(model.l(style.rawValue)).font(.system(size: 11, weight: .medium))
                                        Image(systemName: model.preferences.material == style ? "checkmark.circle.fill" : "circle").font(.system(size: 12)).foregroundStyle(model.preferences.material == style ? Color.accentColor : .secondary)
                                    }.frame(maxWidth: .infinity).padding(.vertical, 13).insetSurface(selected: model.preferences.material == style)
                                }.buttonStyle(.plain).accessibilityAddTraits(model.preferences.material == style ? .isSelected : [])
                            }
                        }
                        Divider().opacity(0.5)
                        settingToggle("weekend", value: $model.preferences.showWeekends)
                        settingToggle("motion", value: $model.preferences.motion)
                    }
                    section("reminders", symbol: "bell.badge") {
                        settingToggle("hourly", value: $model.preferences.reminders)
                        Text(model.l("reminderInfo")).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).lineSpacing(3)
                        Button(model.l("previewReminder"), action: previewReminder).buttonStyle(GlassButton())
                    }
                    section("appUpdates", symbol: "arrow.triangle.2.circlepath") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AetherNote").font(.system(size: 13, weight: .semibold))
                                Text("\(model.l("version")) \(AppUpdates.version)").font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(model.l("checkUpdates")) { updates.check() }.buttonStyle(AccentButton()).disabled(!updates.canCheck)
                        }
                        Text(model.l("updateInfo")).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).lineSpacing(3)
                    }
                    section("data", symbol: "lock.shield") {
                        Text(model.l("localInfo")).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).lineSpacing(3)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                Button(model.l("openData")) { NSWorkspace.shared.open(model.disk.directory) }.buttonStyle(GlassButton()).fixedSize()
                                Button(model.l("backup")) { model.exportBackup() }.buttonStyle(GlassButton()).fixedSize()
                                Button(model.l("restore")) { model.importBackup() }.buttonStyle(GlassButton()).fixedSize().accessibilityIdentifier("restore-backup")
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Button(model.l("openData")) { NSWorkspace.shared.open(model.disk.directory) }.buttonStyle(GlassButton()).fixedSize()
                                    Button(model.l("backup")) { model.exportBackup() }.buttonStyle(GlassButton()).fixedSize()
                                }
                                Button(model.l("restore")) { model.importBackup() }.buttonStyle(GlassButton()).fixedSize().accessibilityIdentifier("restore-backup")
                            }
                        }
                        Divider().opacity(0.5)
                        settingToggle("launch", value: $launchAtLogin).onChange(of: launchAtLogin) { _, value in
                            do { if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                            catch { model.errorMessage = error.localizedDescription; launchAtLogin = SMAppService.mainApp.status == .enabled }
                        }
                    }
                    Text(model.l("shortcut")).font(.system(size: 10)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }.padding(.horizontal, 24).padding(.bottom, 20)
            }
            if let toast = model.toast { Text(toast).font(.system(size: 11)).foregroundStyle(Color.accentColor).padding(.horizontal, 24).padding(.bottom, 12) }
        }.toggleStyle(.switch).controlSize(.small).padding(.top, 28).noteSurface().ignoresSafeArea().frame(minWidth: 550, minHeight: 580)
        .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
    private func settingToggle(_ key: String, value: Binding<Bool>) -> some View {
        HStack(spacing: 20) {
            Text(model.l(key)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Toggle(model.l(key), isOn: value).labelsHidden().accessibilityLabel(model.l(key))
        }
    }
    private func section<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(model.l(title), systemImage: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 14, content: content).font(.system(size: 12)).padding(18).insetSurface()
        }
    }
}
