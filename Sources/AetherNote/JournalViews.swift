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
        view.isRichText = false; view.font = .systemFont(ofSize: 14); view.drawsBackground = false
        view.textColor = .labelColor; view.insertionPointColor = .controlAccentColor
        view.textContainerInset = NSSize(width: 10, height: 10)
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
    private var draft: Binding<String> { Binding(get: { model.drafts[day.rawValue] ?? "" }, set: { model.setDraft($0, day: day) }) }
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(day.rawValue).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                    Text(model.weekday(day)).font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text(model.l(day == model.today ? "welcome" : day < model.today ? "sealedHint" : "futureHint")).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                IconButton(symbol: "doc.on.doc", title: model.l("copy")) { model.copy(model.journal.records(on: day).map(\.text).joined(separator: "\n")) }
            }.padding(26)
            Divider().padding(.horizontal, 26)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if model.journal.records(on: day).isEmpty {
                            VStack(spacing: 14) { Image(systemName: day == model.today ? "pencil.and.scribble" : "leaf").font(.system(size: 30, weight: .ultraLight)); Text(model.l(day == model.today ? "empty" : "noEntries")).font(.system(size: 14)) }.foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 55)
                        }
                        ForEach(model.journal.records(on: day)) { entry in entryRow(entry) }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding(.horizontal, 26).padding(.vertical, 10)
                }.onChange(of: model.journal.records(on: day).count) { _, _ in
                    withAnimation(model.reduceMotion ? nil : .easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                if model.canEdit(day) {
                    ZStack(alignment: .topLeading) {
                        if draft.wrappedValue.isEmpty { Text(model.l("placeholder")).font(.system(size: 14)).foregroundStyle(.tertiary).padding(14).allowsHitTesting(false) }
                        LineInput(text: draft, label: model.l("add")) { _ = model.append(draft.wrappedValue, day: day) }.frame(height: 78)
                    }.background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                    HStack {
                        Text(model.l("inputHint")).font(.system(size: 10)).foregroundStyle(.secondary)
                        Spacer()
                        Button(model.l("append")) { _ = model.append(draft.wrappedValue, day: day) }.buttonStyle(.borderedProminent).disabled(draft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } else {
                    Label(model.l(day > model.today ? "futureHint" : "sealedHint"), systemImage: "lock").font(.system(size: 12)).foregroundStyle(.secondary)
                    if !draft.wrappedValue.isEmpty {
                        Text(model.l("draft")).font(.caption)
                        Text(draft.wrappedValue).font(.caption).textSelection(.enabled).lineLimit(4)
                        Button(model.l("draftToday")) { model.bringDraftToToday(from: day) }
                    }
                }
                if let toast = model.toast { Text(toast).font(.caption).foregroundStyle(Color.accentColor) }
            }.padding(22).background(.primary.opacity(0.025))
        }.noteSurface().frame(minWidth: 480, minHeight: 510).errors(model)
        .alert(model.l("deleteConfirm"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button(model.l("cancel"), role: .cancel) { deleting = nil }
            Button(model.l("delete"), role: .destructive) { if let deleting { model.remove(deleting, day: day) }; deleting = nil }
        }
        .onChange(of: model.today) { _, _ in
            if let entry = editing, editText != entry.text {
                let previous = model.drafts[day.rawValue] ?? ""
                model.setDraft(previous.isEmpty ? editText : previous + "\n" + editText, day: day)
            }
            editing = nil
        }
    }
    @ViewBuilder private func entryRow(_ entry: Entry) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(entry.createdAt.formatted(.dateTime.hour().minute())).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary).frame(width: 43, alignment: .leading).padding(.top, 4)
            VStack(alignment: .leading, spacing: 8) {
                if editing?.id == entry.id {
                    TextEditor(text: $editText).font(.system(size: 14)).frame(minHeight: 70)
                    HStack { Button(model.l("cancel")) { editing = nil }; Button(model.l("save")) { if model.edit(entry, text: editText, day: day) { editing = nil } }.buttonStyle(.borderedProminent) }
                } else {
                    Text(entry.text).font(.system(size: 14)).lineSpacing(5).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if model.canEdit(day) && editing?.id != entry.id {
                Menu { Button(model.l("edit")) { editing = entry; editText = entry.text }; Button(model.l("delete"), role: .destructive) { deleting = entry } } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel(model.l("edit"))
            }
        }.padding(.vertical, 15)
        Divider().opacity(0.5)
    }
}

struct ReviewView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AETHERNOTE / \(model.weekLabel)").font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(2).foregroundStyle(.secondary)
                    Text(model.l("review")).font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text(model.l("readonlyReview")).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                IconButton(symbol: "chevron.left", title: model.l("previous")) { model.navigateWeek(-1) }
                IconButton(symbol: "chevron.right", title: model.l("next")) { model.navigateWeek(1) }
            }.padding(30)
            Divider().padding(.horizontal, 30)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(model.allWeekDays) { day in
                        HStack(alignment: .top, spacing: 28) {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(String(day.rawValue.suffix(2))).font(.system(size: 29, weight: .light, design: .rounded))
                                Text(model.weekday(day)).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                                if day < model.today { Image(systemName: "lock").font(.system(size: 9)).foregroundStyle(.tertiary) }
                            }.frame(width: 54, alignment: .leading)
                            VStack(alignment: .leading, spacing: 13) {
                                if model.journal.records(on: day).isEmpty { Text(model.l(day > model.today ? "future" : "noEntries")).font(.system(size: 13)).foregroundStyle(.tertiary).padding(.top, 7) }
                                ForEach(model.journal.records(on: day)) { entry in
                                    HStack(alignment: .top, spacing: 10) { Circle().fill(Color.accentColor.opacity(0.5)).frame(width: 4, height: 4).padding(.top, 8); Text(entry.text).font(.system(size: 14)).lineSpacing(5).textSelection(.enabled) }
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.padding(.vertical, 24)
                        if day != model.allWeekDays.last { Divider().opacity(0.5) }
                    }
                }.padding(.horizontal, 32)
            }
            HStack {
                Text(model.toast ?? model.l("welcome")).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button(model.l("export")) { model.exportWeek() }
                Button(model.l("copyWeek")) { model.copy(model.journal.markdown(week: model.week)) }.buttonStyle(.borderedProminent)
            }.padding(22)
        }.noteSurface().frame(minWidth: 640, minHeight: 570).errors(model)
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    var previewReminder: () -> Void
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    var body: some View {
        Form {
            Section(model.l("appearance")) {
                Picker(model.l("language"), selection: $model.preferences.language) { ForEach(Language.allCases) { Text($0.title).tag($0) } }
                Picker(model.l("theme"), selection: $model.preferences.material) { ForEach(MaterialStyle.allCases) { Text(model.l($0.rawValue)).tag($0) } }
                Toggle(model.l("weekend"), isOn: $model.preferences.showWeekends)
                Toggle(model.l("motion"), isOn: $model.preferences.motion)
                Toggle(model.l("edge"), isOn: $model.preferences.edgeReveal)
            }
            Section(model.l("reminders")) {
                Toggle(model.l("hourly"), isOn: $model.preferences.reminders)
                Text(model.l("reminderInfo")).font(.caption).foregroundStyle(.secondary)
                Button(model.l("previewReminder"), action: previewReminder)
            }
            Section(model.l("data")) {
                Text(model.l("localInfo")).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(model.l("openData")) { NSWorkspace.shared.open(model.disk.directory) }
                    Button(model.l("backup")) { model.exportBackup() }
                }
                Toggle(model.l("launch"), isOn: $launchAtLogin).onChange(of: launchAtLogin) { _, value in
                    do { if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                    catch { model.errorMessage = error.localizedDescription; launchAtLogin = SMAppService.mainApp.status == .enabled }
                }
            }
            Section {
                Text(model.l("shortcut")).font(.caption).foregroundStyle(.secondary)
                HStack { Text("AetherNote 0.1.0"); Spacer(); Text("Made for little things.").foregroundStyle(.tertiary) }.font(.caption)
            }
        }.formStyle(.grouped).frame(minWidth: 520, minHeight: 650).errors(model)
    }
}
