import CryptoKit
import Foundation
import Testing
@testable import PRPetsUpdates

private struct FakeHTTP: HTTPClient {
    var responses: [URL: (Data, Int)]

    func data(from url: URL) async throws -> (Data, Int) {
        responses[url] ?? (Data(), 404)
    }
}

private let latestURL = URL(string: "https://api.github.com/repos/someone/pr-pets/releases/latest")!
private let archiveURL = URL(string: "https://github.com/someone/pr-pets/releases/download/v0.2.0/PR-Pets.zip")!
private let checksumURL = URL(string: "https://github.com/someone/pr-pets/releases/download/v0.2.0/PR-Pets.zip.sha256")!

private func releaseJSON(tag: String = "v0.2.0", assets: [String] = [Release.archiveAssetName, Release.checksumAssetName]) -> Data {
    let assetJSON = assets.map { name in
        #"{"name": "\#(name)", "browser_download_url": "https://github.com/someone/pr-pets/releases/download/\#(tag)/\#(name)"}"#
    }.joined(separator: ",")
    return Data(#"""
    {"tag_name": "\#(tag)", "html_url": "https://github.com/someone/pr-pets/releases/tag/\#(tag)",
     "body": "Bunnies now hop.", "draft": false, "prerelease": false, "assets": [\#(assetJSON)]}
    """#.utf8)
}

@Suite("App versions")
struct AppVersionTests {
    @Test(arguments: [
        ("1.2.3", AppVersion(major: 1, minor: 2, patch: 3)),
        ("v0.4", AppVersion(major: 0, minor: 4, patch: 0)),
        ("2", AppVersion(major: 2, minor: 0, patch: 0)),
        ("0.1.0-3-gdeadbee", AppVersion(major: 0, minor: 1, patch: 0, suffix: "3-gdeadbee")),
    ])
    func parses(text: String, expected: AppVersion) {
        #expect(AppVersion(text) == expected)
        #expect(AppVersion(text)?.suffix == expected.suffix)
    }

    @Test func rejectsNonVersions() {
        #expect(AppVersion("nightly") == nil)
        #expect(AppVersion("") == nil)
    }

    @Test func comparesNumerically() {
        #expect(AppVersion("0.10.0")! > AppVersion("0.9.9")!)
        #expect(AppVersion("1.0.0")! > AppVersion("0.99.0")!)
        #expect(!(AppVersion("0.1.0-3-gabc")! < AppVersion("0.1.0")!), "a build after a release isn't older than it")
    }
}

@Suite("Release feed")
struct ReleaseFeedTests {
    @Test func readsTheLatestRelease() async throws {
        let feed = GitHubReleaseFeed(repository: "someone/pr-pets", http: FakeHTTP(responses: [latestURL: (releaseJSON(), 200)]))
        let release = try #require(try await feed.latestRelease())
        #expect(release.version == AppVersion("0.2.0"))
        #expect(release.archiveURL == archiveURL)
        #expect(release.checksumURL == checksumURL)
        #expect(release.notes == "Bunnies now hop.")
    }

    @Test func offersOnlyNewerReleases() async throws {
        let feed = GitHubReleaseFeed(repository: "someone/pr-pets", http: FakeHTTP(responses: [latestURL: (releaseJSON(), 200)]))
        #expect(try await feed.update(after: AppVersion("0.1.0")!) != nil)
        #expect(try await feed.update(after: AppVersion("0.2.0")!) == nil)
        #expect(try await feed.update(after: AppVersion("0.3.0")!) == nil)
    }

    @Test func noReleasesYetIsNotAnError() async throws {
        let feed = GitHubReleaseFeed(repository: "someone/pr-pets", http: FakeHTTP(responses: [:]))
        #expect(try await feed.latestRelease() == nil)
    }

    @Test func aReleaseStillUploadingIsReported() async throws {
        let feed = GitHubReleaseFeed(repository: "someone/pr-pets", http: FakeHTTP(responses: [latestURL: (releaseJSON(assets: []), 200)]))
        await #expect(throws: UpdateError.releaseMissingAssets(version: "0.2.0")) { try await feed.latestRelease() }
    }

    @Test func rateLimitsSurfaceTheStatus() async throws {
        let feed = GitHubReleaseFeed(repository: "someone/pr-pets", http: FakeHTTP(responses: [latestURL: (Data(), 403)]))
        await #expect(throws: UpdateError.requestFailed(status: 403)) { try await feed.latestRelease() }
    }
}

@Suite("Update installer")
struct UpdateInstallerTests {
    @Test func parsesShasumOutput() {
        let hex = String(repeating: "ab", count: 32)
        #expect(UpdateInstaller.parseChecksum("\(hex)  PR-Pets.zip\n") == hex)
        #expect(UpdateInstaller.parseChecksum("not a checksum") == nil)
    }

    @Test func replacesTheInstalledAppWithAVerifiedDownload() async throws {
        let sandbox = FileManager.default.temporaryDirectory.appending(path: "pr-pets-update-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let installed = try makeApp(in: sandbox.appending(path: "Applications"), version: "0.1.0")
        let archive = try zip(try makeApp(in: sandbox.appending(path: "build"), version: "0.2.0"))
        let release = try #require(try GitHubReleasePayload.decoded(releaseJSON()))
        let http = FakeHTTP(responses: [
            archiveURL: (archive, 200),
            checksumURL: (Data("\(sha256(archive))  PR-Pets.zip\n".utf8), 200),
        ])

        try await UpdateInstaller(installedApp: installed, http: http).install(release)

        #expect(Bundle(url: installed)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == "0.2.0")
    }

    @Test func refusesADownloadThatDoesntMatchItsChecksum() async throws {
        let sandbox = FileManager.default.temporaryDirectory.appending(path: "pr-pets-update-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let installed = try makeApp(in: sandbox.appending(path: "Applications"), version: "0.1.0")
        let archive = try zip(try makeApp(in: sandbox.appending(path: "build"), version: "0.2.0"))
        let release = try #require(try GitHubReleasePayload.decoded(releaseJSON()))
        let http = FakeHTTP(responses: [
            archiveURL: (archive, 200),
            checksumURL: (Data("\(String(repeating: "0", count: 64))  PR-Pets.zip".utf8), 200),
        ])

        await #expect(throws: UpdateError.self) { try await UpdateInstaller(installedApp: installed, http: http).install(release) }
        #expect(Bundle(url: installed)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == "0.1.0")
    }

    @Test func wontOverwriteSomethingThatIsntAnApp() async throws {
        let release = try #require(try GitHubReleasePayload.decoded(releaseJSON()))
        let installer = UpdateInstaller(installedApp: URL(fileURLWithPath: "/usr/local/bin/PRPets"), http: FakeHTTP(responses: [:]))
        await #expect(throws: UpdateError.notInstalledAsApp(path: "/usr/local/bin/PRPets")) { try await installer.install(release) }
    }

    private func makeApp(in directory: URL, version: String) throws -> URL {
        let app = directory.appending(path: "PR Pets.app", directoryHint: .isDirectory)
        let contents = app.appending(path: "Contents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleIdentifier": UpdateInstaller.bundleIdentifier, "CFBundleShortVersionString": version, "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: contents.appending(path: "Info.plist"))
        return app
    }

    private func zip(_ app: URL) throws -> Data {
        let archive = app.deletingLastPathComponent().appending(path: "PR-Pets.zip")
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-c", "-k", "--keepParent", app.path, archive.path]
        try ditto.run()
        ditto.waitUntilExit()
        return try Data(contentsOf: archive)
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

extension GitHubReleasePayload {
    static func decoded(_ data: Data) throws -> Release {
        try JSONDecoder().decode(GitHubReleasePayload.self, from: data).toRelease()
    }
}
