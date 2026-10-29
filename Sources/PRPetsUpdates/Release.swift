import Foundation

/// A published release that can be installed: the app archive plus the checksum that proves it arrived intact.
public struct Release: Hashable, Sendable {
    public let version: AppVersion
    public let pageURL: URL
    public let archiveURL: URL
    public let checksumURL: URL
    public let notes: String

    /// Names the release workflow and install script agree on.
    public static let archiveAssetName = "PR-Pets.zip"
    public static let checksumAssetName = "PR-Pets.zip.sha256"
}

public enum UpdateError: Error, Hashable, Sendable, CustomStringConvertible {
    case releaseUnreadable(String)
    case releaseMissingAssets(version: String)
    case requestFailed(status: Int)
    case checksumMismatch(expected: String, actual: String)
    case archiveInvalid(String)
    case cannotReplaceApp(String)
    case notInstalledAsApp(path: String)

    public var description: String {
        switch self {
        case .releaseUnreadable(let details): "Couldn't read the latest release from GitHub: \(details)"
        case .releaseMissingAssets(let version): "Release \(version) doesn't include \(Release.archiveAssetName) and its checksum yet."
        case .requestFailed(let status): "GitHub responded with HTTP \(status)."
        case .checksumMismatch: "The download didn't match its checksum, so it wasn't installed. Try again later."
        case .archiveInvalid(let details): "The downloaded update isn't a valid PR Pets app: \(details)"
        case .cannotReplaceApp(let details): "Couldn't replace the installed app: \(details)"
        case .notInstalledAsApp(let path): "Updates only work for an installed PR Pets.app (this is running from \(path))."
        }
    }
}

/// Wire shape of GitHub's `releases/latest` response, reduced to what's needed.
struct GitHubReleasePayload: Decodable {
    struct Asset: Decodable {
        let name: String
        let browser_download_url: URL
    }

    let tag_name: String
    let html_url: URL
    let body: String?
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]

    func toRelease() throws -> Release {
        guard let version = AppVersion(tag_name) else {
            throw UpdateError.releaseUnreadable("tag '\(tag_name)' isn't a version")
        }
        let assetURLByName = Dictionary(assets.map { ($0.name, $0.browser_download_url) }, uniquingKeysWith: { first, _ in first })
        guard let archive = assetURLByName[Release.archiveAssetName], let checksum = assetURLByName[Release.checksumAssetName] else {
            throw UpdateError.releaseMissingAssets(version: version.description)
        }
        return Release(version: version, pageURL: html_url, archiveURL: archive, checksumURL: checksum, notes: body ?? "")
    }
}
