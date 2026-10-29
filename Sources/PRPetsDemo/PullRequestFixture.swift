import Foundation
import PRPetsCore

/// Builds plausible pull requests with only the interesting fields spelled out.
public enum PullRequestFixture {
    public static let referenceDate = Date(timeIntervalSince1970: 1_790_000_000)

    public static func make(
        _ number: Int,
        in repository: String = "acme/web",
        by author: String = "alice",
        title: String? = nil,
        head: String? = nil,
        base: String = "main",
        additions: Int = 40,
        deletions: Int = 12,
        isDraft: Bool = false,
        headCommit: String? = nil,
        reviewDecision: ReviewDecision? = .reviewRequired,
        requestedReviewers: [RequestedReviewer] = [],
        latestReviews: [SubmittedReview] = []
    ) -> PullRequest {
        let repositoryName = RepositoryName(nameWithOwner: repository)!
        return PullRequest(
            id: PullRequestID("PR_\(repository)#\(number)"),
            repository: repositoryName,
            number: number,
            title: title ?? "Change number \(number)",
            url: URL(string: "https://github.com/\(repository)/pull/\(number)")!,
            author: Person(login: Login(author), displayName: author.capitalized),
            lineDelta: LineDelta(additions: additions, deletions: deletions, changedFiles: max(1, (additions + deletions) / 40)),
            isDraft: isDraft,
            branches: BranchPair(head: head ?? "\(author)/change-\(number)", base: base),
            headCommit: headCommit ?? "sha-\(number)",
            reviewDecision: reviewDecision,
            requestedReviewers: requestedReviewers,
            latestReviews: latestReviews,
            createdAt: referenceDate.addingTimeInterval(-86_400 * Double(number % 9 + 1)),
            updatedAt: referenceDate
        )
    }

    /// A chain of PRs, each based on the previous one's branch.
    public static func stack(
        _ numbers: [Int],
        in repository: String = "acme/web",
        by author: String = "alice",
        titles: [String] = [],
        configure: (Int, PullRequest) -> PullRequest = { _, pullRequest in pullRequest }
    ) -> [PullRequest] {
        numbers.enumerated().map { offset, number in
            let base = offset == 0 ? "main" : "\(author)/stack-\(numbers[offset - 1])"
            let pullRequest = make(
                number, in: repository, by: author,
                title: offset < titles.count ? titles[offset] : nil,
                head: "\(author)/stack-\(number)", base: base
            )
            return configure(offset, pullRequest)
        }
    }
}

extension PullRequest {
    /// A copy with some fields replaced; handy for scripting how a PR changes over time.
    public func with(
        title: String? = nil,
        isDraft: Bool? = nil,
        headCommit: String? = nil,
        reviewDecision: ReviewDecision?? = nil,
        requestedReviewers: [RequestedReviewer]? = nil,
        latestReviews: [SubmittedReview]? = nil
    ) -> PullRequest {
        PullRequest(
            id: id, repository: repository, number: number,
            title: title ?? self.title, url: url, author: author, lineDelta: lineDelta,
            isDraft: isDraft ?? self.isDraft, branches: branches,
            headCommit: headCommit ?? self.headCommit,
            reviewDecision: reviewDecision ?? self.reviewDecision,
            requestedReviewers: requestedReviewers ?? self.requestedReviewers,
            latestReviews: latestReviews ?? self.latestReviews,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }
}
