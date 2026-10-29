import Foundation

/// The three columns of the dashboard.
public enum Lane: String, CaseIterable, Hashable, Codable, Sendable {
    case needsMyReview
    case needsMyAction
    case waitingOnOthers
}

public enum ReviewRequestRoute: String, Hashable, Codable, Sendable {
    case direct
    case team
}

/// Why one of the viewer's own PRs is waiting on the viewer.
public enum PendingAction: String, Hashable, Codable, Sendable {
    case addressChangesRequested
    case merge
    case finishDraft
    case requestReviewers
}

/// Where a PR sits in the viewer's queue, with the reason it's there.
public enum QueuePlacement: Hashable, Sendable {
    case needsMyReview(ReviewRequestRoute)
    case needsMyAction(PendingAction)
    case waitingOnOthers

    public var lane: Lane {
        switch self {
        case .needsMyReview: .needsMyReview
        case .needsMyAction: .needsMyAction
        case .waitingOnOthers: .waitingOnOthers
        }
    }
}

public struct QueuePolicy: Hashable, Codable, Sendable {
    public var includeTeamReviewRequests: Bool

    public init(includeTeamReviewRequests: Bool = true) {
        self.includeTeamReviewRequests = includeTeamReviewRequests
    }
}

/// A stack as shown in one lane: every member in order, with the ones belonging to the lane highlighted.
public struct QueueGroup: Identifiable, Hashable, Sendable {
    public let stack: PullRequestStack
    public let lane: Lane
    public let highlightedIDs: Set<PullRequestID>

    public var id: String { "\(lane.rawValue):\(stack.id)" }

    public func isHighlighted(_ pullRequest: PullRequest) -> Bool { highlightedIDs.contains(pullRequest.id) }

    public var highlightedMembers: [PullRequest] { stack.members.filter(isHighlighted) }
}

/// The single place that decides which lane each pull request belongs in.
public struct ReviewQueue: Sendable {
    public let snapshot: PullRequestSnapshot
    public let stackIndex: StackIndex
    private let placementByID: [PullRequestID: QueuePlacement]

    public init(snapshot: PullRequestSnapshot, policy: QueuePolicy) {
        self.snapshot = snapshot
        self.stackIndex = StackIndex(pullRequests: snapshot.pullRequests)
        self.placementByID = snapshot.pullRequests.reduce(into: [:]) { placements, pullRequest in
            placements[pullRequest.id] = Self.placement(of: pullRequest, in: snapshot, policy: policy)
        }
    }

    public var viewer: Login { snapshot.viewer }

    public func placement(of pullRequest: PullRequest) -> QueuePlacement? {
        placementByID[pullRequest.id]
    }

    public func pullRequests(in lane: Lane) -> [PullRequest] {
        snapshot.pullRequests.filter { placement(of: $0)?.lane == lane }
    }

    public func stack(containing pullRequest: PullRequest) -> PullRequestStack? {
        stackIndex.stack(containing: pullRequest)
    }

    public func groups(in lane: Lane) -> [QueueGroup] {
        stackIndex.stacks.compactMap { stack in
            let highlightedIDs = Set(stack.members.filter { placement(of: $0)?.lane == lane }.map(\.id))
            guard !highlightedIDs.isEmpty else { return nil }
            return QueueGroup(stack: stack, lane: lane, highlightedIDs: highlightedIDs)
        }
    }

    private static func placement(
        of pullRequest: PullRequest,
        in snapshot: PullRequestSnapshot,
        policy: QueuePolicy
    ) -> QueuePlacement? {
        let viewer = snapshot.viewer
        if snapshot.reviewRequestedOfViewer.contains(pullRequest.id) {
            let route: ReviewRequestRoute = pullRequest.isRequesting(reviewFrom: viewer) ? .direct : .team
            let isIgnoredTeamRequest = route == .team && !policy.includeTeamReviewRequests
            return isIgnoredTeamRequest ? nil : .needsMyReview(route)
        }
        guard pullRequest.isAuthored(by: viewer) else { return nil }
        return authoredPlacement(of: pullRequest, viewer: viewer)
    }

    private static func authoredPlacement(of pullRequest: PullRequest, viewer: Login) -> QueuePlacement {
        let hasChangesRequested = pullRequest.reviewDecision == .changesRequested
        let hasApprovalWithoutRequiredReviews = pullRequest.reviewDecision == nil
            && !pullRequest.approvers(excluding: viewer).isEmpty
        let isApproved = pullRequest.reviewDecision == .approved || hasApprovalWithoutRequiredReviews

        if hasChangesRequested { return .needsMyAction(.addressChangesRequested) }
        if isApproved { return .needsMyAction(.merge) }
        if pullRequest.isDraft { return .needsMyAction(.finishDraft) }
        if !pullRequest.hasRequestedReviewers { return .needsMyAction(.requestReviewers) }
        return .waitingOnOthers
    }
}
