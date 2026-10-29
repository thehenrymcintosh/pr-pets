import Foundation

public enum Species: String, CaseIterable, Hashable, Codable, Sendable {
    case cat, dog, bunny, fox
}

public enum CoatColour: String, CaseIterable, Hashable, Codable, Sendable {
    case ginger, black, grey, cream, white, chocolate, golden, silver, tan, russet
}

public enum CoatPattern: String, CaseIterable, Hashable, Codable, Sendable {
    case solid
    /// Darker stripes across the back.
    case tabby
    /// Patches of the secondary coat.
    case patches
    /// Secondary-coloured paws.
    case socks
    /// Secondary-coloured chest and paws.
    case tuxedo
    /// Small secondary-coloured spots.
    case spots
    /// Secondary-coloured ears, face and tail tip.
    case points
}

public enum EarShape: String, CaseIterable, Hashable, Codable, Sendable {
    case pointy, tufted, floppy, folded, tall, lop
}

public enum TailShape: String, CaseIterable, Hashable, Codable, Sendable {
    case long, curled, stub, bushy, puff
}

public enum BodyBuild: String, CaseIterable, Hashable, Codable, Sendable {
    case slim, regular, chonky
}

public enum EyeColour: String, CaseIterable, Hashable, Codable, Sendable {
    case dark, green, amber, blue
}

public enum Accessory: String, CaseIterable, Hashable, Codable, Sendable {
    case bow, bandana, flower
}

/// How a pet likes to spend its time. Each trait is 0...1.
public struct Temperament: Hashable, Codable, Sendable {
    /// Walk speed and how often it wanders or gets the zoomies.
    public let energy: Double
    /// How often and how long it naps.
    public let sleepiness: Double
    /// How far it roams from where it is.
    public let curiosity: Double

    public init(energy: Double, sleepiness: Double, curiosity: Double) {
        self.energy = energy
        self.sleepiness = sleepiness
        self.curiosity = curiosity
    }
}

/// Everything that makes a pet look and behave like itself. Derived deterministically from a `Seed`.
public struct PetGenome: Hashable, Codable, Sendable {
    public let species: Species
    public let coat: CoatColour
    public let secondaryCoat: CoatColour
    public let pattern: CoatPattern
    /// Small per-pet shift in coat lightness, -1...1, so two ginger cats aren't identical.
    public let coatTint: Double
    public let ears: EarShape
    public let tail: TailShape
    public let build: BodyBuild
    public let eyes: EyeColour
    public let accessory: Accessory?
    public let temperament: Temperament

    public init(
        species: Species,
        coat: CoatColour,
        secondaryCoat: CoatColour,
        pattern: CoatPattern,
        coatTint: Double,
        ears: EarShape,
        tail: TailShape,
        build: BodyBuild,
        eyes: EyeColour,
        accessory: Accessory?,
        temperament: Temperament
    ) {
        self.species = species
        self.coat = coat
        self.secondaryCoat = secondaryCoat
        self.pattern = pattern
        self.coatTint = coatTint
        self.ears = ears
        self.tail = tail
        self.build = build
        self.eyes = eyes
        self.accessory = accessory
        self.temperament = temperament
    }
}
