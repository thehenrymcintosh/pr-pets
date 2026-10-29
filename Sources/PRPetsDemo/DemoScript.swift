import Foundation
import PRPetsCore

/// A looping story of PRs arriving, getting approved elsewhere and merging, for demo mode and previews.
public enum DemoScript {
    public static let viewer = Login("you")
    public static let loopLength: TimeInterval = 120

    private static let me = RequestedReviewer.user(viewer)

    /// The snapshot at `elapsed` seconds into the story. Loops every `loopLength` seconds.
    public static func snapshot(at elapsed: TimeInterval, fetchedAt: Date = PullRequestFixture.referenceDate) -> PullRequestSnapshot {
        let time = elapsed.truncatingRemainder(dividingBy: loopLength)
        let checkoutStack = checkoutStack(at: time)
        let reviewRequested = reviewRequests(at: time, checkoutStack: checkoutStack)
        let context = checkoutStack.filter { member in !reviewRequested.contains { $0.id == member.id } }
        return PullRequestSnapshot(
            viewer: viewer,
            fetchedAt: fetchedAt,
            pullRequests: reviewRequested + context + authored,
            reviewRequestedOfViewer: Set(reviewRequested.map(\.id))
        )
    }

    private static func checkoutStack(at time: TimeInterval) -> [PullRequest] {
        PullRequestFixture.stack(
            [212, 213, 214, 215],
            by: "alice",
            titles: ["Add checkout service", "Extract checkout form state", "Wire checkout into cart", "Checkout analytics events"]
        ) { offset, pullRequest in
            switch offset {
            case 1: pullRequest.with(requestedReviewers: [me])
            case 2 where time >= 60: pullRequest.with(requestedReviewers: [me])
            case 3: pullRequest.with(isDraft: true)
            default: pullRequest.with(requestedReviewers: [.user(Login("zed"))])
            }
        }
    }

    private static func reviewRequests(at time: TimeInterval, checkoutStack: [PullRequest]) -> [PullRequest] {
        let bob = PullRequestFixture.make(
            88, in: "acme/api", by: "bob", title: "Rate limit webhook retries",
            additions: 132, deletions: 20, requestedReviewers: [me]
        )
        let carol = PullRequestFixture.make(
            19, in: "acme/docs", by: "carol", title: "Document the new deploy flow",
            additions: 310, deletions: 45, requestedReviewers: [.team(slug: "platform")]
        )
        let dan = PullRequestFixture.make(
            301, in: "acme/mobile", by: "dan", title: "Fix crash on empty basket",
            additions: 8, deletions: 3, requestedReviewers: [me]
        )
        let erin = PullRequestFixture.make(
            44, in: "acme/infra", by: "erin", title: "Bump Postgres to 17",
            additions: 26, deletions: 26, requestedReviewers: [me]
        )
        let bobApprovedElsewhere = bob.with(
            reviewDecision: .approved,
            latestReviews: [SubmittedReview(reviewer: Login("frank"), verdict: .approved)]
        )
        let stackRequests = checkoutStack.filter { $0.isRequesting(reviewFrom: viewer) }
        return stackRequests
            + [time < 35 ? bob : bobApprovedElsewhere]
            + (time < 80 ? [carol] : [])
            + (time >= 15 ? [dan] : [])
            + (time >= 35 ? [erin] : [])
    }

    private static let authored: [PullRequest] = [
        PullRequestFixture.make(
            77, in: "acme/web", by: viewer.rawValue, title: "Dark mode toggle", reviewDecision: .approved,
            latestReviews: [SubmittedReview(reviewer: Login("alice"), verdict: .approved)]
        ),
        PullRequestFixture.make(78, in: "acme/web", by: viewer.rawValue, title: "Tidy lint config", reviewDecision: nil),
        PullRequestFixture.make(
            12, in: "acme/api", by: viewer.rawValue, title: "Add /healthz endpoint",
            requestedReviewers: [.user(Login("bob"))]
        ),
        PullRequestFixture.make(
            13, in: "acme/api", by: viewer.rawValue, title: "Structured request logging", reviewDecision: .changesRequested,
            latestReviews: [SubmittedReview(reviewer: Login("bob"), verdict: .changesRequested)]
        ),
    ]
}

/// Plays `DemoScript` in real time from when it was created.
public struct DemoPullRequestSource: PullRequestSource {
    private let startedAt: Date
    private let clock: @Sendable () -> Date

    public init(clock: @escaping @Sendable () -> Date = Date.init) {
        self.clock = clock
        self.startedAt = clock()
    }

    public func fetchSnapshot(_ query: PullRequestQuery) async throws -> PullRequestSnapshot {
        let now = clock()
        return DemoScript.snapshot(at: now.timeIntervalSince(startedAt), fetchedAt: now)
    }
}
