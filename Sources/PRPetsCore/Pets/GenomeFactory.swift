import Foundation

public enum GenomeFactory {
    /// The same seed and species list always produce the same pet.
    public static func genome(for seed: Seed, allowedSpecies: [Species] = Species.allCases) -> PetGenome {
        var random = SeededRandom(seed: seed)
        let speciesPool = allowedSpecies.isEmpty ? Species.allCases : allowedSpecies
        let species = speciesPool[Int(random.next() % UInt64(speciesPool.count))]
        let traits = SpeciesCatalogue.traits(for: species)

        let coat = random.weightedPick(traits.coats)
        let secondaryCoat = random.weightedPick(traits.secondaryCoats.filter { $0.0 != coat })
        return PetGenome(
            species: species,
            coat: coat,
            secondaryCoat: secondaryCoat,
            pattern: random.weightedPick(traits.patterns),
            coatTint: Double.random(in: -1...1, using: &random),
            ears: random.weightedPick(traits.ears),
            tail: random.weightedPick(traits.tails),
            build: random.weightedPick([(.slim, 1), (.regular, 2), (.chonky, 1)]),
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
