import Foundation

public struct CommandOutput: Sendable {
    public let exitCode: Int32
    public let standardOutput: Data
    public let standardError: String
}

/// Runs an external program. A protocol so tests can stand in for `gh`.
public protocol CommandRunner: Sendable {
    func run(_ executable: URL, arguments: [String]) async throws -> CommandOutput
}

public struct ProcessCommandRunner: CommandRunner {
    public init() {}

    public func run(_ executable: URL, arguments: [String]) async throws -> CommandOutput {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            let standardOutput = Pipe()
            let standardError = Pipe()
            process.standardOutput = standardOutput
            process.standardError = standardError
            // Read while running so a large response can't fill the pipe buffer and deadlock.
            let outputCollector = PipeCollector(standardOutput.fileHandleForReading)
            let errorCollector = PipeCollector(standardError.fileHandleForReading)
            process.terminationHandler = { finished in
                continuation.resume(returning: CommandOutput(
                    exitCode: finished.terminationStatus,
                    standardOutput: outputCollector.finish(),
                    standardError: String(decoding: errorCollector.finish(), as: UTF8.self)
                ))
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private final class PipeCollector: @unchecked Sendable {
    private let handle: FileHandle
    private let lock = NSLock()
    private var data = Data()

    init(_ handle: FileHandle) {
        self.handle = handle
        handle.readabilityHandler = { [weak self] readable in
            let chunk = readable.availableData
            guard let self, !chunk.isEmpty else { return }
            self.lock.withLock { self.data.append(chunk) }
        }
    }

    func finish() -> Data {
        handle.readabilityHandler = nil
        let remaining = handle.readDataToEndOfFile()
        return lock.withLock {
            data.append(remaining)
            return data
        }
    }
}
