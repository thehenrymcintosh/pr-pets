import Foundation

/// Everything derived from one snapshot plus the user's decisions: the queue, who gets a pet, and why not.
public struct ReviewBoard: Sendable {
    public let queue: ReviewQueue
    public let presence: PetPresence
    public let preferences: Preferences

    public init(snapshot: PullRequestSnapshot, ledger: TriageLedger, identities: PetIdentityRegistry, preferences: Preferences) {
        let queue = ReviewQueue(snapshot: snapshot, policy: preferences.queuePolicy)
        self.queue = queue
        self.presence = PetPresence(queue: queue, ledger: ledger, identities: identities, policy: preferences.presencePolicy)
        self.preferences = preferences
    }

    /// The pets that should be outside right now.
    public var roster: PetRoster { presence.roster(petsAreInside: preferences.petsAreInside) }

    /// How many pets would be outside if they weren't inside. Shown on the doghouse.
    public var waitingPetCount: Int { presence.roster(petsAreInside: false).entries.count }

    /// Registers seeds for any new PRs. Call once per new snapshot.
    public static func identities(_ registry: PetIdentityRegistry, updatedFor snapshot: PullRequestSnapshot) -> PetIdentityRegistry {
        registry.registering(StackIndex(pullRequests: snapshot.pullRequests).stacks)
    }
}
