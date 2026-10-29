import Foundation
import os

/// One Codable value persisted as a JSON file in Application Support. Unreadable files fall back to the default
/// (and are kept aside as `.corrupt`) rather than stopping the app from launching.
struct JSONFileStore<Value: Codable> {
    let url: URL
    let defaultValue: Value

    static func inApplicationSupport(_ fileName: String, default defaultValue: Value) -> JSONFileStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appending(path: "PR Pets", directoryHint: .isDirectory)
        return JSONFileStore(url: directory.appending(path: fileName), defaultValue: defaultValue)
    }

    func load() -> Value {
        guard let data = try? Data(contentsOf: url) else { return defaultValue }
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            Log.storage.error("Couldn't read \(url.lastPathComponent, privacy: .public), using defaults: \(String(describing: error), privacy: .public)")
            try? FileManager.default.moveItem(at: url, to: url.appendingPathExtension("corrupt"))
            return defaultValue
        }
    }

    func save(_ value: Value) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(value).write(to: url, options: .atomic)
        } catch {
            Log.storage.error("Couldn't save \(url.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }
}

enum Log {
    static let sync = Logger(subsystem: "dev.prpets", category: "sync")
    static let storage = Logger(subsystem: "dev.prpets", category: "storage")
    static let overlay = Logger(subsystem: "dev.prpets", category: "overlay")
    static let updates = Logger(subsystem: "dev.prpets", category: "updates")
}
