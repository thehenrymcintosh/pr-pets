import Foundation

/// Fetches bytes over HTTP. A protocol so tests don't hit the network.
public protocol HTTPClient: Sendable {
    func data(from url: URL) async throws -> (Data, Int)
}

public struct URLSessionHTTPClient: HTTPClient {
    public init() {}

    public func data(from url: URL) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("PR-Pets-Updater", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}

/// The latest published release of a GitHub repository. Unauthenticated: releases are public,
/// and a check a day is far inside GitHub's anonymous rate limit.
public struct GitHubReleaseFeed: Sendable {
    public let repository: String
    private let http: any HTTPClient

    public init(repository: String, http: any HTTPClient = URLSessionHTTPClient()) {
        self.repository = repository
        self.http = http
    }

    /// nil when the repository has no releases yet.
    public func latestRelease() async throws -> Release? {
        let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
        let (data, status) = try await http.data(from: url)
        if status == 404 { return nil }
        guard status == 200 else { throw UpdateError.requestFailed(status: status) }
        let payload: GitHubReleasePayload
        do {
            payload = try JSONDecoder().decode(GitHubReleasePayload.self, from: data)
        } catch {
            throw UpdateError.releaseUnreadable(String(describing: error))
        }
        return try payload.toRelease()
    }

    /// The newer release if there is one, otherwise nil.
    public func update(after installed: AppVersion) async throws -> Release? {
        guard let latest = try await latestRelease(), latest.version > installed else { return nil }
        return latest
    }
}
