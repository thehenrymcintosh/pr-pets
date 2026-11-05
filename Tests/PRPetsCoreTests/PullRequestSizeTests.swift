import PRPetsCore
import Testing

@Suite("Pull request size")
struct PullRequestSizeTests {
    private func size(additions: Int, deletions: Int) -> PullRequestSize {
        PullRequestSize(LineDelta(additions: additions, deletions: deletions, changedFiles: 1))
    }

    @Test func linesTouchedPickTheBand() {
        #expect(size(additions: 10, deletions: 5) == .small)
        #expect(size(additions: 30, deletions: 19) == .small)
        #expect(size(additions: 30, deletions: 20) == .medium)
        #expect(size(additions: 399, deletions: 0) == .medium)
        #expect(size(additions: 200, deletions: 200) == .large)
        #expect(size(additions: 799, deletions: 0) == .large)
        #expect(size(additions: 500, deletions: 300) == .extraLarge)
    }

    @Test func biggerPullRequestsMakeChonkierPets() {
        #expect(PullRequestSize.small.build == .slim)
        #expect(PullRequestSize.medium.build == .regular)
        #expect(PullRequestSize.large.build == .chonky)
        #expect(PullRequestSize.extraLarge.build == .extraChonky)
    }

    @Test func overridingTheBuildLeavesEveryOtherTraitAlone() {
        for index in 0..<50 {
            let seed = Seed(hashing: "size-\(index)")
            let seeded = GenomeFactory.genome(for: seed)
            for build in BodyBuild.allCases {
                let sized = GenomeFactory.genome(for: seed, build: build)
                #expect(sized.build == build)
                #expect(sized == PetGenome(
                    species: seeded.species, coat: seeded.coat, secondaryCoat: seeded.secondaryCoat,
                    pattern: seeded.pattern, coatTint: seeded.coatTint, ears: seeded.ears, tail: seeded.tail,
                    build: build, eyes: seeded.eyes, accessory: seeded.accessory, temperament: seeded.temperament
                ))
            }
        }
    }
}
