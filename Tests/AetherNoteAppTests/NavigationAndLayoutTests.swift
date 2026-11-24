import AppKit
import SwiftUI
import Testing
import AetherNoteCore
@testable import AetherNote

@MainActor
private func renderPreview<V: View>(_ view: V, size: NSSize, appearance: NSAppearance.Name = .darkAqua, outputPath: String? = nil) throws {
    let container = NSView(frame: NSRect(origin: .zero, size: size))
    container.wantsLayer = true
    container.layer?.backgroundColor = (appearance == .darkAqua ? NSColor(white: 0.14, alpha: 1) : NSColor(white: 0.94, alpha: 1)).cgColor
    container.appearance = NSAppearance(named: appearance)

    let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
    host.frame = container.bounds
    host.appearance = NSAppearance(named: appearance)
    container.addSubview(host)
    container.layoutSubtreeIfNeeded()
    host.layoutSubtreeIfNeeded()

    #expect(host.fittingSize.width <= size.width + 2)
    let rep = container.bitmapImageRepForCachingDisplay(in: container.bounds)
    #expect(rep != nil)
    if let rep {
        container.cacheDisplay(in: container.bounds, to: rep)
        #expect(rep.pixelsWide > 0 && rep.pixelsHigh > 0)
        if let outputPath, let png = rep.representation(using: .png, properties: [:]) {
            try png.write(to: URL(fileURLWithPath: outputPath))
        }
    }
}

@Test @MainActor func modelMultilineSearchAndDateJumpFlows() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let now = Calendar.journal.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 12))!
    let model = try AppModel(directory: dir, clock: { now })

    #expect(model.append("first line\nsecond line", day: model.today, splitLines: false))
    #expect(model.journal.records(on: model.today).count == 1)
    #expect(model.journal.records(on: model.today).first?.text == "first line\nsecond line")

    #expect(model.append("alpha\nbeta", day: model.today, splitLines: true))
    #expect(model.journal.records(on: model.today).count == 3)

    let past = model.today.adding(days: -14)
    #expect(model.append("older café memo", day: past, splitLines: false))
    let matches = model.journal.search("cafe")
    #expect(matches.count == 1 && matches.first?.day == past)

    model.jumpTo(date: past.date()!)
    #expect(model.week == past.week().first!)
    model.returnToCurrentWeek()
    #expect(model.week == model.today.week().first!)
}

@Test @MainActor func allViewsLayoutCleanlyAcrossLanguagesAndMaterials() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let now = Calendar.journal.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 12))!
    let model = try AppModel(directory: dir, clock: { now })
    let updates = AppUpdates()
    let previewDir = ProcessInfo.processInfo.environment["AETHERNOTE_PREVIEW_DIR"]
    if let previewDir {
        try FileManager.default.createDirectory(atPath: previewDir, withIntermediateDirectories: true)
    }

    let monday = model.today.week().first!
    #expect(model.append("梳理这一周的计划\n散步二十分钟", day: monday, splitLines: true))
    #expect(model.append("完成返回一周导航\n保留 Shift + 回车换行", day: model.today, splitLines: false))
    model.setDraft("草稿第一行\n草稿第二行", day: model.today)

    for language in [Language.zh, .en, .ja] {
        model.preferences.language = language
        for material in [MaterialStyle.glass, .paper] {
            model.preferences.material = material
            let tag = "\(language.rawValue)-\(material.rawValue)"
            let linePath = (previewDir != nil && material == .glass) ? "\(previewDir!)/preview-line-\(tag).png" : nil
            let editorPath = (previewDir != nil && material == .glass) ? "\(previewDir!)/preview-editor-\(tag).png" : nil
            let reviewPath = (previewDir != nil && material == .glass) ? "\(previewDir!)/preview-review-\(tag).png" : nil
            let settingsPath = (previewDir != nil && material == .glass) ? "\(previewDir!)/preview-settings-\(tag).png" : nil

            try renderPreview(
                LineView(openDay: { _ in }, review: {}, settings: {}, hide: {}).environmentObject(model),
                size: NSSize(width: 1120, height: 365),
                outputPath: linePath
            )
            try renderPreview(
                DayEditor(day: model.today).environmentObject(model),
                size: NSSize(width: 500, height: 490)
            )
            try renderPreview(
                DayEditor(day: model.today).environmentObject(model),
                size: NSSize(width: 540, height: 590),
                outputPath: editorPath
            )
            try renderPreview(
                ReviewView().environmentObject(model),
                size: NSSize(width: 760, height: 720),
                outputPath: reviewPath
            )
            try renderPreview(
                SettingsView(updates: updates, previewReminder: {}).environmentObject(model),
                size: NSSize(width: 550, height: 580)
            )
            try renderPreview(
                SettingsView(updates: updates, previewReminder: {}).environmentObject(model),
                size: NSSize(width: 600, height: 760),
                outputPath: settingsPath
            )
        }
    }
}
