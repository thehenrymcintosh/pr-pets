import Foundation

/// A pet that should currently be out in the yard.
public struct PetRosterEntry: Identifiable, Hashable, Sendable {
    public let id: PullRequestID
    public let genome: PetGenome
    public let label: String?
    public let stackPosition: StackPosition?

    public init(id: PullRequestID, genome: PetGenome, label: String?, stackPosition: StackPosition?) {
        self.id = id
        self.genome = genome
        self.label = label
        self.stackPosition = stackPosition
    }
}

/// The pets that should be outside. The yard reconciles towards this; it never decides presence itself.
public struct PetRoster: Hashable, Sendable {
    public let entries: [PetRosterEntry]

    public init(entries: [PetRosterEntry]) { self.entries = entries }

    public static let empty = PetRoster(entries: [])
}

public enum PetLabelStyle: String, CaseIterable, Hashable, Codable, Sendable {
    case authorLogin
    case authorName
    case repository
    case hidden
}

public struct PetPresencePolicy: Hashable, Codable, Sendable {
    /// Send a pet home once someone else has approved the PR.
    public var hideWhenApprovedByOthers: Bool
    public var maximumPets: Int
    public var labelStyle: PetLabelStyle
    public var allowedSpecies: [Species]
    /// Which dashboard columns get pets. Reviews only, by default.
    public var petLanes: Set<Lane>

    public static let defaultPetLanes: Set<Lane> = [.needsMyReview]

    public init(
        hideWhenApprovedByOthers: Bool = true,
        maximumPets: Int = 12,
        labelStyle: PetLabelStyle = .authorLogin,
        allowedSpecies: [Species] = Species.allCases,
        petLanes: Set<Lane> = PetPresencePolicy.defaultPetLanes
    ) {
        self.petLanes = petLanes
        self.hideWhenApprovedByOthers = hideWhenApprovedByOthers
        self.maximumPets = maximumPets
        self.labelStyle = labelStyle
        self.allowedSpecies = allowedSpecies
    }
}

/// Why a PR has no pet outside. The dashboard shows the user-relevant ones.
public enum PetAbsence: Hashable, Sendable {
    /// Its column doesn't get pets (or it isn't in a column at all).
    case laneWithoutPets
    case suppressed(Suppression)
    /// Someone else approved a PR the viewer was asked to review.
    case approvedByOthers([Login])
}

/// The single place that decides which PRs get a pet in the yard.
public struct PetPresence: Sendable {
    public let queue: ReviewQueue
    public let ledger: TriageLedger
    public let identities: PetIdentityRegistry
    public let policy: PetPresencePolicy

    public init(queue: ReviewQueue, ledger: TriageLedger, identities: PetIdentityRegistry, policy: PetPresencePolicy) {
        self.queue = queue
        self.ledger = ledger
        self.identities = identities
        self.policy = policy
    }

    /// `nil` means the PR deserves a pet; otherwise why it doesn't.
    public func absence(of pullRequest: PullRequest) -> PetAbsence? {
        guard let lane = queue.placement(of: pullRequest)?.lane, policy.petLanes.contains(lane) else { return .laneWithoutPets }
        if let suppression = ledger.activeSuppression(for: pullRequest) { return .suppressed(suppression) }
        // Only a review request is "handled" by someone else's approval; your own approved PR still needs merging.
        let otherApprovers = pullRequest.approvers(excluding: queue.viewer)
        let isHandledByOthers = lane == .needsMyReview && policy.hideWhenApprovedByOthers && !otherApprovers.isEmpty
        return isHandledByOthers ? .approvedByOthers(otherApprovers) : nil
    }

    public func laneHasPets(_ lane: Lane) -> Bool { policy.petLanes.contains(lane) }

    public func roster(petsAreInside: Bool) -> PetRoster {
        guard !petsAreInside else { return .empty }
        let entries = Lane.allCases.flatMap(queue.pullRequests(in:))
            .filter { absence(of: $0) == nil }
            .prefix(policy.maximumPets)
            .map(entry(for:))
        return PetRoster(entries: Array(entries))
    }

    public func genome(for pullRequest: PullRequest) -> PetGenome {
        let seed = identities.seed(for: pullRequest) ?? Seed(hashing: pullRequest.id.rawValue)
        return GenomeFactory.genome(for: seed, allowedSpecies: policy.allowedSpecies)
    }

    public func stackPosition(of pullRequest: PullRequest) -> StackPosition? {
        guard let stack = queue.stack(containing: pullRequest), stack.isStacked else { return nil }
        return stack.position(of: pullRequest)
    }

    private func entry(for pullRequest: PullRequest) -> PetRosterEntry {
        PetRosterEntry(
            id: pullRequest.id,
            genome: genome(for: pullRequest),
            label: label(for: pullRequest),
            stackPosition: stackPosition(of: pullRequest)
        )
    }

    private func label(for pullRequest: PullRequest) -> String? {
        guard policy.labelStyle != .hidden else { return nil }
        // Your own name over your own PR says nothing; say what it's waiting for instead.
        if let reminder = queue.placement(of: pullRequest)?.ownPullRequestReminder { return reminder }
        return switch policy.labelStyle {
        case .authorLogin: pullRequest.author.login.rawValue
        case .authorName: pullRequest.author.displayName ?? pullRequest.author.login.rawValue
        case .repository: pullRequest.repository.name
        case .hidden: nil
        }
    }
}

extension QueuePlacement {
    /// The name tag for a pet whose PR is the viewer's own.
    var ownPullRequestReminder: String? {
        switch self {
        case .needsMyReview: nil
        case .needsMyAction(.addressChangesRequested): "changes requested"
        case .needsMyAction(.merge): "ready to merge"
        case .needsMyAction(.finishDraft): "finish draft"
        case .needsMyAction(.requestReviewers): "needs reviewers"
        case .waitingOnOthers: "in review"
        }
    }
}
