import PRPetsCore
import PRPetsDemo
import Testing

private let viewer = Login("you")
private let me = RequestedReviewer.user(viewer)

private func queue(
    reviewRequested: [PullRequest] = [],
    other: [PullRequest] = [],
    policy: QueuePolicy = QueuePolicy()
) -> ReviewQueue {
    ReviewQueue(
        snapshot: PullRequestSnapshot(
            viewer: viewer,
            fetchedAt: PullRequestFixture.referenceDate,
            pullRequests: reviewRequested + other,
            reviewRequestedOfViewer: Set(reviewRequested.map(\.id))
        ),
        policy: policy
    )
}

@Suite("Review queue")
struct ReviewQueueTests {
    @Test func directReviewRequestsNeedMyReview() {
        let request = PullRequestFixture.make(1, requestedReviewers: [me])
        #expect(queue(reviewRequested: [request]).placement(of: request) == .needsMyReview(.direct))
    }

    @Test func teamRequestsCanBeIgnored() {
        let request = PullRequestFixture.make(1, requestedReviewers: [.team(slug: "platform")])
        #expect(queue(reviewRequested: [request]).placement(of: request) == .needsMyReview(.team))
        #expect(queue(reviewRequested: [request], policy: QueuePolicy(includeTeamReviewRequests: false)).placement(of: request) == nil)
    }

    @Test(arguments: [
        (PullRequestFixture.make(1, by: "you", reviewDecision: .changesRequested), QueuePlacement.needsMyAction(.addressChangesRequested)),
        (PullRequestFixture.make(2, by: "you", reviewDecision: .approved), .needsMyAction(.merge)),
        (PullRequestFixture.make(3, by: "you", reviewDecision: nil, latestReviews: [SubmittedReview(reviewer: Login("bob"), verdict: .approved)]), .needsMyAction(.merge)),
        (PullRequestFixture.make(4, by: "you", isDraft: true), .needsMyAction(.finishDraft)),
        (PullRequestFixture.make(5, by: "you"), .needsMyAction(.requestReviewers)),
        (PullRequestFixture.make(6, by: "you", requestedReviewers: [.user(Login("bob"))]), .waitingOnOthers),
    ])
    func myOwnPullRequestsArePlacedByWhatTheyWaitOn(pullRequest: PullRequest, expected: QueuePlacement) {
        #expect(queue(other: [pullRequest]).placement(of: pullRequest) == expected)
    }

    @Test func pullRequestsThatDontInvolveMeHaveNoLane() {
        let stranger = PullRequestFixture.make(1, by: "bob")
        #expect(queue(other: [stranger]).placement(of: stranger) == nil)
    }

    @Test func demoScriptFillsEveryLane() {
        let demo = ReviewQueue(snapshot: DemoScript.snapshot(at: 0), policy: QueuePolicy())
        #expect(demo.pullRequests(in: .needsMyReview).map(\.number) == [213, 88, 19])
        #expect(demo.pullRequests(in: .needsMyAction).map(\.number).sorted() == [13, 77, 78])
        #expect(demo.pullRequests(in: .waitingOnOthers).map(\.number) == [12])
    }
}

@Suite("Stacks")
struct StackTests {
    @Test func followsBaseBranchesIntoOrderedStacks() {
        let stack = PullRequestFixture.stack([10, 11, 12])
        let index = StackIndex(pullRequests: [stack[2], stack[0], stack[1]])

        let found = index.stack(containing: stack[2])
        #expect(found?.members.map(\.number) == [10, 11, 12])
        #expect(found?.position(of: stack[1]) == StackPosition(index: 2, count: 3))
        #expect(index.stacks.count == 1)
    }

    @Test func unrelatedPullRequestsAreStacksOfOne() {
        let index = StackIndex(pullRequests: [PullRequestFixture.make(1), PullRequestFixture.make(2)])
        #expect(index.stacks.map(\.isStacked) == [false, false])
    }

    @Test func sameBranchNamesInDifferentRepositoriesDontLink() {
        let web = PullRequestFixture.make(1, in: "acme/web", head: "feature")
        let api = PullRequestFixture.make(2, in: "acme/api", head: "next", base: "feature")
        #expect(StackIndex(pullRequests: [web, api]).stacks.count == 2)
    }

    @Test func forksNeverStack() {
        let parent = PullRequestFixture.make(1, head: "patch-1")
        let fork = PullRequest(
            id: PullRequestID("fork"), repository: parent.repository, number: 2, title: "fork", url: parent.url,
            author: parent.author, lineDelta: parent.lineDelta, isDraft: false,
            branches: BranchPair(head: "patch-1", base: "main", headIsInFork: true),
            headCommit: "x", reviewDecision: nil, requestedReviewers: [], latestReviews: [],
            createdAt: parent.createdAt, updatedAt: parent.updatedAt
        )
        let child = PullRequestFixture.make(3, head: "child", base: "patch-1")
        let index = StackIndex(pullRequests: [parent, fork, child])
        #expect(index.stack(containing: child)?.members.map(\.number) == [1, 3])
    }

    @Test func branchCyclesStillShowEveryPullRequest() {
        let first = PullRequestFixture.make(1, head: "a", base: "b")
        let second = PullRequestFixture.make(2, head: "b", base: "a")
        #expect(StackIndex(pullRequests: [first, second]).stacks.flatMap(\.members).count == 2)
    }

    @Test func laneGroupsHighlightOnlyTheirOwnMembers() {
        let demo = ReviewQueue(snapshot: DemoScript.snapshot(at: 0), policy: QueuePolicy())
        let checkout = demo.groups(in: .needsMyReview).first { $0.stack.isStacked }
        #expect(checkout?.stack.members.map(\.number) == [212, 213, 214, 215])
        #expect(checkout?.highlightedMembers.map(\.number) == [213])
    }
}
