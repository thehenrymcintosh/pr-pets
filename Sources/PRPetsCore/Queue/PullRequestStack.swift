import Foundation

/// 1-based position of a PR within its stack, e.g. 2/10.
public struct StackPosition: Hashable, Codable, Sendable, CustomStringConvertible {
    public let index: Int
    public let count: Int

    public init(index: Int, count: Int) {
        self.index = index
        self.count = count
    }

    public var description: String { "\(index)/\(count)" }
}

/// A chain of open PRs where each one's base branch is the previous one's head branch.
/// Most PRs are a stack of one.
public struct PullRequestStack: Identifiable, Hashable, Sendable {
    /// The bottom-most PR (the one based on a branch that isn't another open PR).
    public var id: PullRequestID { members[0].id }
    /// Ordered bottom to top.
    public let members: [PullRequest]

    init(members: [PullRequest]) {
        precondition(!members.isEmpty, "A stack always has at least one member")
        self.members = members
    }

    public var isStacked: Bool { members.count > 1 }

    public func contains(_ pullRequest: PullRequest) -> Bool {
        members.contains { $0.id == pullRequest.id }
    }

    public func position(of pullRequest: PullRequest) -> StackPosition? {
        guard let offset = members.firstIndex(where: { $0.id == pullRequest.id }) else { return nil }
        return StackPosition(index: offset + 1, count: members.count)
    }
}

/// Groups pull requests into stacks by following base -> head branch links within a repository.
public struct StackIndex: Sendable {
    public let stacks: [PullRequestStack]
    private let stackIDByMember: [PullRequestID: PullRequestID]

    public init(pullRequests: [PullRequest]) {
        let stacks = Self.buildStacks(pullRequests)
        self.stacks = stacks
        self.stackIDByMember = Dictionary(
            uniqueKeysWithValues: stacks.flatMap { stack in stack.members.map { ($0.id, stack.id) } }
        )
    }

    public func stack(containing pullRequest: PullRequest) -> PullRequestStack? {
        guard let stackID = stackIDByMember[pullRequest.id] else { return nil }
        return stacks.first { $0.id == stackID }
    }

    private struct BranchKey: Hashable {
        let repository: RepositoryName
        let branch: String
    }

    private static func buildStacks(_ pullRequests: [PullRequest]) -> [PullRequestStack] {
        let stackablePullRequests = pullRequests.filter { !$0.branches.headIsInFork }
        let pullRequestByHeadBranch = Dictionary(
            stackablePullRequests.map { (BranchKey(repository: $0.repository, branch: $0.branches.head), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        func parent(of pullRequest: PullRequest) -> PullRequest? {
            let baseKey = BranchKey(repository: pullRequest.repository, branch: pullRequest.branches.base)
            guard let candidate = pullRequestByHeadBranch[baseKey], candidate.id != pullRequest.id else { return nil }
            return candidate
        }
        let childrenByParentID = Dictionary(grouping: pullRequests.compactMap { child in
            parent(of: child).map { (parentID: $0.id, child: child) }
        }, by: \.parentID).mapValues { links in links.map(\.child).sorted(by: Self.stackOrder) }

        let roots = pullRequests.filter { parent(of: $0) == nil }.sorted(by: Self.stackOrder)
        let rootedStacks = roots.map { root in
            PullRequestStack(members: depthFirst(from: root, childrenByParentID: childrenByParentID))
        }
        let placedIDs = Set(rootedStacks.flatMap { $0.members.map(\.id) })
        // Branch cycles have no root; keep each member visible as its own stack rather than dropping it.
        let cyclicLeftovers = pullRequests.filter { !placedIDs.contains($0.id) }.map { PullRequestStack(members: [$0]) }
        return rootedStacks + cyclicLeftovers
    }

    private static func depthFirst(
        from root: PullRequest,
        childrenByParentID: [PullRequestID: [PullRequest]]
    ) -> [PullRequest] {
        var ordered: [PullRequest] = []
        var visited = Set<PullRequestID>()
        func visit(_ pullRequest: PullRequest) {
            guard visited.insert(pullRequest.id).inserted else { return }
            ordered.append(pullRequest)
            childrenByParentID[pullRequest.id, default: []].forEach(visit)
        }
        visit(root)
        return ordered
    }

    private static func stackOrder(_ lhs: PullRequest, _ rhs: PullRequest) -> Bool {
        (lhs.repository.nameWithOwner, lhs.number) < (rhs.repository.nameWithOwner, rhs.number)
    }
}
