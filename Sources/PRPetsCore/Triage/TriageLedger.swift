import Foundation

/// A user's decision to hide a PR's pet.
public enum Suppression: Hashable, Codable, Sendable {
    /// Hidden for good.
    case muted(at: Date)
    /// Hidden until the author pushes new commits.
    case dismissed(at: Date, headCommit: String)

    public func isActive(for pullRequest: PullRequest) -> Bool {
        switch self {
        case .muted: true
        case .dismissed(_, let dismissedHeadCommit): pullRequest.headCommit == dismissedHeadCommit
        }
    }
}

/// The user's mute/dismiss decisions, keyed by PR.
public struct TriageLedger: Hashable, Codable, Sendable {
    public private(set) var suppressionByID: [PullRequestID: Suppression]

    public init(suppressionByID: [PullRequestID: Suppression] = [:]) {
        self.suppressionByID = suppressionByID
    }

    public func activeSuppression(for pullRequest: PullRequest) -> Suppression? {
        suppressionByID[pullRequest.id].flatMap { $0.isActive(for: pullRequest) ? $0 : nil }
    }

    public func isSuppressed(_ pullRequest: PullRequest) -> Bool {
        activeSuppression(for: pullRequest) != nil
    }

    public func muting(_ pullRequest: PullRequest, at date: Date) -> TriageLedger {
        with(pullRequest.id, .muted(at: date))
    }

    public func dismissing(_ pullRequest: PullRequest, at date: Date) -> TriageLedger {
        with(pullRequest.id, .dismissed(at: date, headCommit: pullRequest.headCommit))
    }

    public func restoring(_ pullRequest: PullRequest) -> TriageLedger {
        with(pullRequest.id, nil)
    }

    /// Drops entries for PRs that are no longer open so the ledger doesn't grow forever.
    public func pruned(keeping openPullRequests: [PullRequest]) -> TriageLedger {
        let openIDs = Set(openPullRequests.map(\.id))
        return TriageLedger(suppressionByID: suppressionByID.filter { openIDs.contains($0.key) })
    }

    private func with(_ id: PullRequestID, _ suppression: Suppression?) -> TriageLedger {
        var updated = suppressionByID
        updated[id] = suppression
        return TriageLedger(suppressionByID: updated)
    }
}
