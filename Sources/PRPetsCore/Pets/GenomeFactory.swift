import Foundation

public enum GenomeFactory {
    /// The same seed and species list always produce the same pet.
    /// Passing a `build` overrides the seeded one without disturbing the pet's other traits.
    public static func genome(for seed: Seed, allowedSpecies: [Species] = Species.allCases, build: BodyBuild? = nil) -> PetGenome {
        var random = SeededRandom(seed: seed)
        let speciesPool = allowedSpecies.isEmpty ? Species.allCases : allowedSpecies
        let species = speciesPool[Int(random.next() % UInt64(speciesPool.count))]
        let traits = SpeciesCatalogue.traits(for: species)

        let coat = random.weightedPick(traits.coats)
        let secondaryCoat = random.weightedPick(traits.secondaryCoats.filter { $0.0 != coat })
        let pattern = random.weightedPick(traits.patterns)
        let coatTint = Double.random(in: -1...1, using: &random)
        let ears = random.weightedPick(traits.ears)
        let tail = random.weightedPick(traits.tails)
        // Always draw the seeded build so the traits after it come out the same whether or not it's overridden.
        let seededBuild = random.weightedPick([(BodyBuild.slim, 1), (.regular, 2), (.chonky, 1)])
        return PetGenome(
            species: species,
            coat: coat,
            secondaryCoat: secondaryCoat,
            pattern: pattern,
            coatTint: coatTint,
            ears: ears,
            tail: tail,
            build: build ?? seededBuild,
            eyes: random.weightedPick(traits.eyes),
            accessory: random.chance(0.2) ? random.weightedPick(Accessory.allCases.map { ($0, 1) }) : nil,
            temperament: Temperament(
                energy: Double.random(in: 0...1, using: &random),
                sleepiness: Double.random(in: 0...1, using: &random),
                curiosity: Double.random(in: 0...1, using: &random)
            )
        )
    }
}
