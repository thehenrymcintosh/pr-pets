import Foundation

/// Remembers which seed each PR's pet was born with, so a pet keeps its look across polls and restarts,
/// and PRs in the same stack share a look even as the stack's bottom PR merges and the stack re-roots.
public struct PetIdentityRegistry: Hashable, Codable, Sendable {
    public private(set) var seedByID: [PullRequestID: Seed]

    public init(seedByID: [PullRequestID: Seed] = [:]) {
        self.seedByID = seedByID
    }

    public func seed(for pullRequest: PullRequest) -> Seed? {
        seedByID[pullRequest.id]
    }

    /// Gives every open PR a seed. Existing seeds never change; new stack members inherit
    /// the seed of the lowest member that already has one, otherwise the stack gets a fresh seed.
    /// PRs that are no longer open are forgotten.
    public func registering(_ stacks: [PullRequestStack]) -> PetIdentityRegistry {
        let updatedSeedByID = stacks.reduce(into: [PullRequestID: Seed]()) { assigned, stack in
            let stackSeed = stack.members.lazy.compactMap { seedByID[$0.id] }.first
                ?? Seed(hashing: stack.id.rawValue)
            for member in stack.members {
                assigned[member.id] = seedByID[member.id] ?? stackSeed
            }
        }
        return PetIdentityRegistry(seedByID: updatedSeedByID)
    }
}
