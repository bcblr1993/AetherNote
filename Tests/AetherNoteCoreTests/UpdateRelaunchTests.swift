import Foundation
import Testing
@testable import AetherNoteCore

@Test func updateRelaunchPreservesOnlyTheMatchingInstallAndConsumesOnce() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("relaunch.json"), now = Date()
    try UpdateRelaunch(applicationPath: "/qa/AetherNote.app", dataDirectory: "/qa/data", now: now).save(to: file)
    #expect(try UpdateRelaunch.consume(from: file, applicationPath: "/Applications/AetherNote.app", now: now) == nil)
    #expect(try UpdateRelaunch.consume(from: file, applicationPath: "/qa/AetherNote.app", now: now) == "/qa/data")
    #expect(try UpdateRelaunch.consume(from: file, applicationPath: "/qa/AetherNote.app", now: now) == nil)
}

@Test func expiredUpdateRelaunchCannotRedirectData() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("relaunch.json"), now = Date()
    try UpdateRelaunch(applicationPath: "/qa/AetherNote.app", dataDirectory: "/qa/data", now: now).save(to: file)
    #expect(try UpdateRelaunch.consume(from: file, applicationPath: "/qa/AetherNote.app", now: now.addingTimeInterval(601)) == nil)
    #expect(!FileManager.default.fileExists(atPath: file.path))
}
