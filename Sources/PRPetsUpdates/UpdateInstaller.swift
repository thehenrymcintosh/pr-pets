import CryptoKit
import Foundation

/// Downloads a release, checks it against its published SHA-256, and swaps it in for the running app.
public struct UpdateInstaller: Sendable {
    public static let bundleIdentifier = "dev.prpets.PRPets"
    private static let appName = "PR Pets.app"

    private let http: any HTTPClient
    private let installedApp: URL

    /// `installedApp` is the `.app` to replace, normally `Bundle.main.bundleURL`.
    public init(installedApp: URL, http: any HTTPClient = URLSessionHTTPClient()) {
        self.installedApp = installedApp
        self.http = http
    }

    /// Replaces the installed app with `release`. On return the new version is on disk; relaunch to run it.
    public func install(_ release: Release) async throws {
        guard installedApp.pathExtension == "app" else { throw UpdateError.notInstalledAsApp(path: installedApp.path) }
        let workspace = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: installedApp, create: true)
        defer { try? FileManager.default.removeItem(at: workspace) }

        let archive = try await download(release.archiveURL)
        let expectedChecksum = try await publishedChecksum(release.checksumURL)
        try Self.verify(archive, matches: expectedChecksum)

        let archiveFile = workspace.appending(path: Release.archiveAssetName)
        try archive.write(to: archiveFile)
        let unpacked = try Self.unpack(archiveFile, into: workspace.appending(path: "unpacked", directoryHint: .isDirectory))
        try Self.checkIsPRPets(unpacked)
        try replaceInstalledApp(with: unpacked)
    }

    /// Opens the app again once this process has exited.
    public func relaunch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", installedApp.path]
        try? process.run()
    }

    static func verify(_ data: Data, matches expectedChecksum: String) throws {
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual == expectedChecksum.lowercased() else {
            throw UpdateError.checksumMismatch(expected: expectedChecksum, actual: actual)
        }
    }

    /// `shasum` output is `<hex>  <file name>`; only the hex matters.
    static func parseChecksum(_ text: String) -> String? {
        let hex = text.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        let isSHA256 = hex.count == 64 && hex.allSatisfy(\.isHexDigit)
        return isSHA256 ? hex : nil
    }

    private func download(_ url: URL) async throws -> Data {
        let (data, status) = try await http.data(from: url)
        guard status == 200 else { throw UpdateError.requestFailed(status: status) }
        return data
    }

    private func publishedChecksum(_ url: URL) async throws -> String {
        let text = String(decoding: try await download(url), as: UTF8.self)
        guard let checksum = Self.parseChecksum(text) else { throw UpdateError.archiveInvalid("checksum file is malformed") }
        return checksum
    }

    private static func unpack(_ archive: URL, into directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", archive.path, directory.path]
        try ditto.run()
        ditto.waitUntilExit()
        guard ditto.terminationStatus == 0 else { throw UpdateError.archiveInvalid("couldn't unzip (ditto exited \(ditto.terminationStatus))") }
        let app = directory.appending(path: appName, directoryHint: .isDirectory)
        guard FileManager.default.fileExists(atPath: app.path) else { throw UpdateError.archiveInvalid("\(appName) not found in archive") }
        return app
    }

    private static func checkIsPRPets(_ app: URL) throws {
        let identifier = Bundle(url: app)?.bundleIdentifier
        guard identifier == bundleIdentifier else {
            throw UpdateError.archiveInvalid("bundle identifier is \(identifier ?? "missing")")
        }
    }

    private func replaceInstalledApp(with newApp: URL) throws {
        do {
            _ = try FileManager.default.replaceItemAt(installedApp, withItemAt: newApp)
        } catch {
            throw UpdateError.cannotReplaceApp(error.localizedDescription)
        }
    }
}
