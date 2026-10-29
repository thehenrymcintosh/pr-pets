import Foundation
import PRPetsCore
import PRPetsDemo
import Testing

private let viewer = Login("you")
private let me = RequestedReviewer.user(viewer)
private let now = PullRequestFixture.referenceDate

private func presence(
    _ reviewRequested: [PullRequest],
    context: [PullRequest] = [],
    ledger: TriageLedger = TriageLedger(),
    policy: PetPresencePolicy = PetPresencePolicy()
) -> PetPresence {
    let snapshot = PullRequestSnapshot(
        viewer: viewer, fetchedAt: now,
        pullRequests: reviewRequested + context,
        reviewRequestedOfViewer: Set(reviewRequested.map(\.id))
    )
    let queue = ReviewQueue(snapshot: snapshot, policy: QueuePolicy())
    let identities = PetIdentityRegistry().registering(queue.stackIndex.stacks)
    return PetPresence(queue: queue, ledger: ledger, identities: identities, policy: policy)
}

@Suite("Triage")
struct TriageTests {
    @Test func mutedPullRequestsStayHidden() {
        let request = PullRequestFixture.make(1, requestedReviewers: [me])
        let ledger = TriageLedger().muting(request, at: now)
        #expect(ledger.isSuppressed(request.with(headCommit: "new-work")))
    }

    @Test func dismissedPullRequestsComeBackWhenTheAuthorPushes() {
        let request = PullRequestFixture.make(1, requestedReviewers: [me])
        let ledger = TriageLedger().dismissing(request, at: now)
        #expect(ledger.isSuppressed(request))
        #expect(!ledger.isSuppressed(request.with(headCommit: "new-work")))
    }

    @Test func restoringUndoesEitherDecision() {
        let request = PullRequestFixture.make(1)
        #expect(!TriageLedger().muting(request, at: now).restoring(request).isSuppressed(request))
    }

    @Test func pruningForgetsClosedPullRequests() {
        let open = PullRequestFixture.make(1)
        let merged = PullRequestFixture.make(2)
        let ledger = TriageLedger().muting(open, at: now).muting(merged, at: now).pruned(keeping: [open])
        #expect(ledger.suppressionByID.keys.map(\.rawValue) == [open.id.rawValue])
    }
}

@Suite("Pet presence")
struct PetPresenceTests {
    @Test func everyReviewRequestGetsAPet() {
        let requests = [PullRequestFixture.make(1, requestedReviewers: [me]), PullRequestFixture.make(2, by: "bob", requestedReviewers: [me])]
        let roster = presence(requests).roster(petsAreInside: false)
        #expect(roster.entries.map(\.label) == ["alice", "bob"])
    }

    @Test func mutedAndApprovedElsewherePullRequestsHaveNoPet() {
        let muted = PullRequestFixture.make(1, requestedReviewers: [me])
        let approved = PullRequestFixture.make(2, requestedReviewers: [me], latestReviews: [SubmittedReview(reviewer: Login("dave"), verdict: .approved)])
        let wanted = PullRequestFixture.make(3, requestedReviewers: [me])
        let petPresence = presence([muted, approved, wanted], ledger: TriageLedger().muting(muted, at: now))

        #expect(petPresence.roster(petsAreInside: false).entries.map(\.id) == [wanted.id])
        #expect(petPresence.absence(of: approved) == .approvedByOthers([Login("dave")]))
    }

    @Test func approvalsElsewhereCanBeIgnored() {
        let approved = PullRequestFixture.make(2, requestedReviewers: [me], latestReviews: [SubmittedReview(reviewer: Login("dave"), verdict: .approved)])
        let roster = presence([approved], policy: PetPresencePolicy(hideWhenApprovedByOthers: false)).roster(petsAreInside: false)
        #expect(roster.entries.count == 1)
    }

    @Test func petsInsideMeansAnEmptyYard() {
        #expect(presence([PullRequestFixture.make(1, requestedReviewers: [me])]).roster(petsAreInside: true) == .empty)
    }

    @Test func rosterIsCappedAtTheMaximum() {
        let requests = (1...9).map { PullRequestFixture.make($0, requestedReviewers: [me]) }
        #expect(presence(requests, policy: PetPresencePolicy(maximumPets: 4)).roster(petsAreInside: false).entries.count == 4)
    }

    @Test func labelsFollowTheChosenStyle() {
        let request = PullRequestFixture.make(1, in: "acme/api", requestedReviewers: [me])
        func label(_ style: PetLabelStyle) -> String? {
            presence([request], policy: PetPresencePolicy(labelStyle: style)).roster(petsAreInside: false).entries.first?.label
        }
        #expect(label(.authorLogin) == "alice")
        #expect(label(.authorName) == "Alice")
        #expect(label(.repository) == "api")
        #expect(label(.hidden) == nil)
    }

    @Test func stackedPetsShareAGenomeAndShowTheirPosition() {
        let stack = PullRequestFixture.stack([10, 11, 12]) { offset, pullRequest in
            offset == 0 ? pullRequest : pullRequest.with(requestedReviewers: [me])
        }
        let roster = presence(Array(stack[1...]), context: [stack[0]]).roster(petsAreInside: false)
        #expect(roster.entries.map(\.stackPosition) == [StackPosition(index: 2, count: 3), StackPosition(index: 3, count: 3)])
        #expect(Set(roster.entries.map(\.genome)).count == 1)
    }
}

@Suite("Pet identity")
struct PetIdentityTests {
    @Test func aPetKeepsItsLookWhenItsStackReRoots() {
        let stack = PullRequestFixture.stack([10, 11, 12])
        let before = PetIdentityRegistry().registering(StackIndex(pullRequests: stack).stacks)
        // #10 merges; #11 becomes the bottom of the stack.
        let rebased = [PullRequestFixture.make(11, head: "alice/stack-11", base: "main"), stack[2]]
        let after = before.registering(StackIndex(pullRequests: rebased).stacks)

        #expect(after.seed(for: stack[1]) == before.seed(for: stack[1]))
        #expect(after.seed(for: stack[2]) == before.seed(for: stack[2]))
        #expect(after.seed(for: stack[0]) == nil, "closed PRs are forgotten")
    }

    @Test func newStackMembersInheritTheStacksLook() {
        let stack = PullRequestFixture.stack([10, 11, 12])
        let registry = PetIdentityRegistry().registering(StackIndex(pullRequests: Array(stack[..<2])).stacks)
            .registering(StackIndex(pullRequests: stack).stacks)
        #expect(registry.seed(for: stack[2]) == registry.seed(for: stack[0]))
    }

    @Test func separateStacksLookDifferent() {
        let registry = PetIdentityRegistry().registering(StackIndex(pullRequests: [PullRequestFixture.make(1), PullRequestFixture.make(2)]).stacks)
        #expect(registry.seed(for: PullRequestFixture.make(1)) != registry.seed(for: PullRequestFixture.make(2)))
    }
}

@Suite("Genomes")
struct GenomeTests {
    @Test func theSameSeedAlwaysMakesTheSamePet() {
        let seed = Seed(hashing: "PR_kwDODKw3uc8AAAABLKVR8g")
        #expect(GenomeFactory.genome(for: seed) == GenomeFactory.genome(for: seed))
        #expect(seed == Seed(12_686_681_191_811_739_394), "seeds must be stable across runs and machines")
    }

    @Test func respectsTheAllowedSpecies() {
        let species = Set((0..<50).map { GenomeFactory.genome(for: Seed(hashing: "\($0)"), allowedSpecies: [.cat, .bunny]).species })
        #expect(species == [.cat, .bunny])
    }

    @Test func producesAGoodSpread() {
        let genomes = (0..<300).map { GenomeFactory.genome(for: Seed(hashing: "spread-\($0)")) }
        #expect(Set(genomes.map(\.species)) == Set(Species.allCases))
        #expect(Set(genomes.map(\.coat)).count >= 8)
        #expect(Set(genomes.map(\.pattern)) == Set(CoatPattern.allCases))
        #expect(Set(genomes).count == genomes.count, "no two of 300 pets should be identical")
    }
}
