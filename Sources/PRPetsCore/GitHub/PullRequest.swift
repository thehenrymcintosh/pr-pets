import Foundation

/// GitHub's global node ID for a pull request. Stable for the life of the PR.
public struct PullRequestID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

public struct RepositoryName: Hashable, Codable, Sendable, CustomStringConvertible {
    public let owner: String
    public let name: String

    public init(owner: String, name: String) {
        self.owner = owner
        self.name = name
    }

    /// Parses `owner/name`.
    public init?(nameWithOwner: String) {
        let parts = nameWithOwner.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        self.init(owner: String(parts[0]), name: String(parts[1]))
    }

    public var nameWithOwner: String { "\(owner)/\(name)" }
    public var description: String { nameWithOwner }
}

public struct Login: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    /// GitHub logins are case-insensitive.
    public static func == (lhs: Login, rhs: Login) -> Bool {
        lhs.rawValue.lowercased() == rhs.rawValue.lowercased()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue.lowercased())
    }
}

public struct Person: Hashable, Codable, Sendable {
    public let login: Login
    public let displayName: String?

    public init(login: Login, displayName: String? = nil) {
        self.login = login
        self.displayName = displayName
    }
}

public struct LineDelta: Hashable, Codable, Sendable {
    public let additions: Int
    public let deletions: Int
    public let changedFiles: Int

    public init(additions: Int, deletions: Int, changedFiles: Int) {
        self.additions = additions
        self.deletions = deletions
        self.changedFiles = changedFiles
    }
}

public struct BranchPair: Hashable, Codable, Sendable {
    public let head: String
    public let base: String
    /// True when the head branch lives in a fork; such PRs can never be stacked on a branch in this repository.
    public let headIsInFork: Bool

    public init(head: String, base: String, headIsInFork: Bool = false) {
        self.head = head
        self.base = base
        self.headIsInFork = headIsInFork
    }
}

/// GitHub's aggregate review decision for a pull request.
public enum ReviewDecision: String, Codable, Sendable {
    case reviewRequired
    case approved
    case changesRequested
}

public enum RequestedReviewer: Hashable, Codable, Sendable {
    case user(Login)
    case team(slug: String)
}

public struct SubmittedReview: Hashable, Codable, Sendable {
    public enum Verdict: String, Codable, Sendable {
        case approved, changesRequested, commented, dismissed, pending
    }

    public let reviewer: Login
    public let verdict: Verdict

    public init(reviewer: Login, verdict: Verdict) {
        self.reviewer = reviewer
        self.verdict = verdict
    }
}

/// An open pull request, as last fetched.
public struct PullRequest: Identifiable, Hashable, Codable, Sendable {
    public let id: PullRequestID
    public let repository: RepositoryName
    public let number: Int
    public let title: String
    public let url: URL
    public let author: Person
    public let lineDelta: LineDelta
    public let isDraft: Bool
    public let branches: BranchPair
    /// The head commit. A change here means the author pushed new work.
    public let headCommit: String
    public let reviewDecision: ReviewDecision?
    public let requestedReviewers: [RequestedReviewer]
    public let latestReviews: [SubmittedReview]
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: PullRequestID,
        repository: RepositoryName,
        number: Int,
        title: String,
        url: URL,
        author: Person,
        lineDelta: LineDelta,
        isDraft: Bool,
        branches: BranchPair,
        headCommit: String,
        reviewDecision: ReviewDecision?,
        requestedReviewers: [RequestedReviewer],
        latestReviews: [SubmittedReview],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.repository = repository
        self.number = number
        self.title = title
        self.url = url
        self.author = author
        self.lineDelta = lineDelta
        self.isDraft = isDraft
        self.branches = branches
        self.headCommit = headCommit
        self.reviewDecision = reviewDecision
        self.requestedReviewers = requestedReviewers
        self.latestReviews = latestReviews
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// `owner/repo#123`
    public var shortReference: String { "\(repository.nameWithOwner)#\(number)" }

    public var hasRequestedReviewers: Bool { !requestedReviewers.isEmpty }

    public func isRequesting(reviewFrom login: Login) -> Bool {
        requestedReviewers.contains(.user(login))
    }

    public func isAuthored(by login: Login) -> Bool { author.login == login }

    public func approvers(excluding login: Login) -> [Login] {
        latestReviews
            .filter { $0.verdict == .approved && $0.reviewer != login }
            .map(\.reviewer)
    }
}
