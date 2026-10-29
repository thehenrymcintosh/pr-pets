import Foundation

/// Everything known about the viewer's open pull requests at one moment.
///
/// `pullRequests` also holds "context" PRs that don't involve the viewer but share a stack
/// with one that does, so stacks can be shown whole.
public struct PullRequestSnapshot: Hashable, Codable, Sendable {
    public let viewer: Login
    public let fetchedAt: Date
    public let pullRequests: [PullRequest]
    /// PRs where GitHub reports a pending review request for the viewer, directly or via a team.
    public let reviewRequestedOfViewer: Set<PullRequestID>

    public init(
        viewer: Login,
        fetchedAt: Date,
        pullRequests: [PullRequest],
        reviewRequestedOfViewer: Set<PullRequestID>
    ) {
        self.viewer = viewer
        self.fetchedAt = fetchedAt
        self.pullRequests = Self.uniqued(pullRequests)
        self.reviewRequestedOfViewer = reviewRequestedOfViewer
    }

    public func pullRequest(withID id: PullRequestID) -> PullRequest? {
        pullRequests.first { $0.id == id }
    }

    private static func uniqued(_ pullRequests: [PullRequest]) -> [PullRequest] {
        var seen = Set<PullRequestID>()
        return pullRequests.filter { seen.insert($0.id).inserted }
    }
}

/// Repository-pattern boundary for fetching pull requests. Implementations: `gh` CLI, demo scripts.
public protocol PullRequestSource: Sendable {
    func fetchSnapshot(_ query: PullRequestQuery) async throws -> PullRequestSnapshot
}

/// What the user wants fetched. Built from settings; sources translate it into their own query language.
public struct PullRequestQuery: Hashable, Codable, Sendable {
    /// Limit to these owners (orgs or users). Empty means everywhere.
    public var owners: [String]
    /// Repositories (`owner/name`) to ignore entirely.
    public var excludedRepositories: [String]
    /// Whether to fetch open PRs that share a stack with the viewer's PRs.
    public var includeStackContext: Bool

    public init(owners: [String] = [], excludedRepositories: [String] = [], includeStackContext: Bool = true) {
        self.owners = owners
        self.excludedRepositories = excludedRepositories
        self.includeStackContext = includeStackContext
    }
}
