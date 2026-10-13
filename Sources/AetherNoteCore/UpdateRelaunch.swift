import Foundation

/// Sparkle relaunches without command-line arguments. Keep an explicitly selected
/// data directory for this installation's next launch only, never for another copy.
public struct UpdateRelaunch: Codable, Equatable {
    public let applicationPath: String
    public let dataDirectory: String
    public let expiresAt: Date

    public init(applicationPath: String, dataDirectory: String, now: Date) {
        self.applicationPath = applicationPath
        self.dataDirectory = dataDirectory
        expiresAt = now.addingTimeInterval(600)
    }

    public func save(to file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(self).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }

    public static func consume(from file: URL, applicationPath: String, now: Date) throws -> String? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let context = try JSONDecoder().decode(Self.self, from: Data(contentsOf: file))
        guard now < context.expiresAt else { try FileManager.default.removeItem(at: file); return nil }
        guard context.applicationPath == applicationPath else { return nil }
        try FileManager.default.removeItem(at: file)
        return context.dataDirectory
    }
}
