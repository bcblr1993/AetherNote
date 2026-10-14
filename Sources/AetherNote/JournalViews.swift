import SwiftUI
import AppKit
import ServiceManagement
import AetherNoteCore

final class LineTextView: NSTextView {
    var submit: (() -> Void)?
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 {
            if !event.modifierFlags.contains(.shift) && !hasMarkedText() { submit?(); return }
        }
        super.keyDown(with: event)
    }
}
struct LineInput: NSViewRepresentable {
    @Binding var text: String
    var label: String
    var submit: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        let view = LineTextView()
        view.isRichText = false; view.font = .systemFont(ofSize: 15); view.drawsBackground = false
        view.textColor = .labelColor; view.insertionPointColor = .controlAccentColor
        view.textContainerInset = NSSize(width: 12, height: 12)
        view.isVerticallyResizable = true; view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]; view.textContainer?.widthTracksTextView = true
        view.delegate = context.coordinator; view.submit = submit
        view.setAccessibilityLabel(label); view.setAccessibilityIdentifier("entry-input")
        scroll.documentView = view
        DispatchQueue.main.async { if view.window?.isKeyWindow == true { view.window?.makeFirstResponder(view) } }
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? LineTextView else { return }
        context.coordinator.parent = self; view.submit = submit; view.setAccessibilityLabel(label)
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

struct DayEditor: View {
    @EnvironmentObject var model: AppModel
    let day: Day
    @State private var editing: Entry?
    @State private var editText = ""
    @State private var deleting: Entry?
    private var records: [Entry] { model.journal.records(on: day) }
    private var draft: Binding<String> { Binding(get: { model.drafts[day.rawValue] ?? "" }, set: { model.setDraft($0, day: day) }) }
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                PanelHeading(symbol: "square.and.pencil", title: model.weekday(day), subtitle: day.rawValue, tint: model.dayColor(day).tint)
                Spacer()
                StatusPill(text: model.l(day == model.today ? "today" : day < model.today ? "editable" : "future"), accent: day == model.today)
                DayColorButton(day: day)
                IconButton(symbol: "doc.on.doc", title: model.l("copy")) { model.copy(records.map(\.text).joined(separator: "\n")) }.disabled(records.isEmpty)
            }.padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 20)
            HStack {
                Text(model.l(day > model.today ? "futureHint" : "welcome")).font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Text(model.entryCount(records.count)).font(.system(size: 11, weight: .medium)).monospacedDigit().foregroundStyle(.secondary)
            }.padding(.horizontal, 26).padding(.bottom, 12)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if records.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "text.badge.plus").font(.system(size: 30, weight: .light)).foregroundStyle(Color.accentColor.opacity(0.7))
                                Text(model.l(day == model.today ? "empty" : "noEntries")).font(.system(size: 14, weight: .medium))
                            }.foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 52)
                        }
                        ForEach(records) { entry in entryRow(entry) }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding(.horizontal, 24).padding(.vertical, 4)
                }.onChange(of: records.count) { _, _ in
                    withAnimation(model.reduceMotion ? nil : .easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
            composer.padding(20)
        }.padding(.top, 28).noteSurface(tint: model.dayColor(day).tint).ignoresSafeArea().frame(minWidth: 520, minHeight: 540).errors(model)
        .onChange(of: editing?.id) { _, _ in updateEditingState() }
        .onChange(of: editText) { _, _ in updateEditingState() }
        .onDisappear { model.hasUnsavedEdit = false }
        .alert(model.l("deleteConfirm"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button(model.l("cancel"), role: .cancel) { deleting = nil }
            Button(model.l("delete"), role: .destructive) { if let deleting { model.remove(deleting, day: day) }; deleting = nil }
        }
    }
    private func updateEditingState() { model.hasUnsavedEdit = editing != nil && editText != editing?.text }
    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.canEdit(day) {
                HStack {
                    Label(model.l("add"), systemImage: "plus.circle").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    if !draft.wrappedValue.isEmpty { Text(model.l("draft")).font(.system(size: 10)).foregroundStyle(.secondary) }
                }
                ZStack(alignment: .topLeading) {
                    if draft.wrappedValue.isEmpty { Text(model.l("placeholder")).font(.system(size: 15)).foregroundStyle(.secondary).padding(.horizontal, 17).padding(.vertical, 12).allowsHitTesting(false) }
                    LineInput(text: draft, label: model.l("add")) { _ = model.append(draft.wrappedValue, day: day) }.frame(height: 82)
                }.background(.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 10))
                HStack {
                    Text(model.l("inputHint")).font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Button { _ = model.append(draft.wrappedValue, day: day) } label: { Label(model.l("append"), systemImage: "arrow.up") }
                        .buttonStyle(AccentButton()).disabled(draft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                Label(model.l("futureHint"), systemImage: "calendar").font(.system(size: 12)).foregroundStyle(.secondary)
                if !draft.wrappedValue.isEmpty {
                    Text(model.l("draft")).font(.caption)
                    Text(draft.wrappedValue).font(.caption).textSelection(.enabled).lineLimit(4)
                    Button(model.l("draftToday")) { model.bringDraftToToday(from: day) }.buttonStyle(GlassButton())
                }
            }
            if let toast = model.toast { Text(toast).font(.caption).foregroundStyle(Color.accentColor) }
        }.padding(16).insetSurface(selected: model.canEdit(day))
    }
    private func entryRow(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: editing?.id == entry.id ? "pencil" : "checkmark.circle.fill").foregroundStyle(Color.accentColor.opacity(0.7))
                Text(entry.createdAt.formatted(.dateTime.hour().minute())).monospacedDigit().foregroundStyle(.secondary)
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
                TextEditor(text: $editText).font(.system(size: 15)).scrollContentBackground(.hidden)
                    .padding(8).frame(minHeight: 86).background(.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel(model.l("edit"))
                HStack {
                    Spacer()
                    Button(model.l("cancel")) { editing = nil }.buttonStyle(GlassButton())
                    Button(model.l("save")) { if model.edit(entry, text: editText, day: day) { editing = nil } }
                        .buttonStyle(AccentButton()).disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                Text(entry.text).font(.system(size: 15)).lineSpacing(5).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(16).insetSurface(selected: editing?.id == entry.id)
    }
}

struct ReviewView: View {
    @EnvironmentObject var model: AppModel
    private var total: Int { model.allWeekDays.reduce(0) { $0 + model.journal.records(on: $1).count } }
    private var recordedDays: Int { model.allWeekDays.filter { !model.journal.records(on: $0).isEmpty }.count }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                PanelHeading(symbol: "rectangle.stack", title: model.l("review"), subtitle: model.l("weekOverview"))
                Spacer()
                IconButton(symbol: "chevron.left", title: model.l("previous")) { model.navigateWeek(-1) }
                IconButton(symbol: "chevron.right", title: model.l("next")) { model.navigateWeek(1) }
            }.padding(24)
            HStack(spacing: 10) {
                Button(model.weekLabel) { model.returnToCurrentWeek() }.buttonStyle(GlassButton()).help(model.l("thisWeek"))
                CurrentWeekButton()
                Spacer()
                StatusPill(text: model.entryCount(total), accent: true)
                StatusPill(text: "\(model.l("recordedDays")) · \(recordedDays) / 7")
            }.padding(.horizontal, 24).padding(.bottom, 16)
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
                            ForEach(model.allWeekDays) { day in reviewDay(day).id(day.id) }
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
        }.padding(.top, 28).noteSurface().ignoresSafeArea().frame(minWidth: 680, minHeight: 570).errors(model)
    }
    private func reviewDay(_ day: Day) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 4) {
                Text(String(day.rawValue.suffix(2))).font(.system(size: 25, weight: .medium, design: .rounded))
                Text(model.weekday(day)).font(.system(size: 10)).foregroundStyle(.secondary)
            }.frame(width: 46).padding(.vertical, 8).background(model.dayColor(day).tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 12) {
                if model.journal.records(on: day).isEmpty {
                    Text(model.l(day > model.today ? "future" : "noEntries")).font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical, 14)
                }
                ForEach(model.journal.records(on: day)) { entry in
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
                        HStack {
                            Button(model.l("openData")) { NSWorkspace.shared.open(model.disk.directory) }.buttonStyle(GlassButton())
                            Button(model.l("backup")) { model.exportBackup() }.buttonStyle(GlassButton())
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
        }.toggleStyle(.switch).controlSize(.small).padding(.top, 28).noteSurface().ignoresSafeArea().frame(minWidth: 550, minHeight: 580).errors(model)
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
