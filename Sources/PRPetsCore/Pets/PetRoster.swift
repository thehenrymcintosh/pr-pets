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

    public init(
        hideWhenApprovedByOthers: Bool = true,
        maximumPets: Int = 12,
        labelStyle: PetLabelStyle = .authorLogin,
        allowedSpecies: [Species] = Species.allCases
    ) {
        self.hideWhenApprovedByOthers = hideWhenApprovedByOthers
        self.maximumPets = maximumPets
        self.labelStyle = labelStyle
        self.allowedSpecies = allowedSpecies
    }
}

/// Why a PR awaiting the viewer's review has no pet outside. Shown in the dashboard.
public enum PetAbsence: Hashable, Sendable {
    case suppressed(Suppression)
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
        if let suppression = ledger.activeSuppression(for: pullRequest) { return .suppressed(suppression) }
        let otherApprovers = pullRequest.approvers(excluding: queue.viewer)
        let isHandledByOthers = policy.hideWhenApprovedByOthers && !otherApprovers.isEmpty
        return isHandledByOthers ? .approvedByOthers(otherApprovers) : nil
    }

    public func roster(petsAreInside: Bool) -> PetRoster {
        guard !petsAreInside else { return .empty }
        let entries = queue.pullRequests(in: .needsMyReview)
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
        switch policy.labelStyle {
        case .authorLogin: pullRequest.author.login.rawValue
        case .authorName: pullRequest.author.displayName ?? pullRequest.author.login.rawValue
        case .repository: pullRequest.repository.name
        case .hidden: nil
        }
    }
}
