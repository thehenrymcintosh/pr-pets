import Foundation

/// The traits each species can be born with, and how common each one is.
/// Add a species here (and its body in PRPetsArt) to bring a new kind of pet to the yard.
public struct SpeciesTraits: Sendable {
    public let coats: [(CoatColour, Double)]
    public let secondaryCoats: [(CoatColour, Double)]
    public let patterns: [(CoatPattern, Double)]
    public let ears: [(EarShape, Double)]
    public let tails: [(TailShape, Double)]
    public let eyes: [(EyeColour, Double)]
}

public enum SpeciesCatalogue {
    public static func traits(for species: Species) -> SpeciesTraits {
        switch species {
        case .cat: cat
        case .dog: dog
        case .bunny: bunny
        case .fox: fox
        }
    }

    private static let cat = SpeciesTraits(
        coats: [(.ginger, 3), (.black, 2), (.grey, 2), (.cream, 1), (.white, 1), (.chocolate, 1), (.silver, 1)],
        secondaryCoats: [(.white, 4), (.cream, 1), (.black, 1), (.ginger, 1)],
        patterns: [(.solid, 2), (.tabby, 3), (.patches, 1.5), (.socks, 1.5), (.tuxedo, 1.5), (.points, 1)],
        ears: [(.pointy, 5), (.tufted, 1.5), (.folded, 1)],
        tails: [(.long, 5), (.bushy, 1), (.stub, 0.5)],
        eyes: [(.green, 3), (.amber, 3), (.blue, 1.5), (.dark, 1)]
    )

    private static let dog = SpeciesTraits(
        coats: [(.golden, 3), (.chocolate, 2), (.black, 2), (.cream, 2), (.white, 1), (.tan, 2), (.grey, 1)],
        secondaryCoats: [(.white, 4), (.cream, 1), (.black, 1), (.tan, 1)],
        patterns: [(.solid, 3), (.patches, 2), (.socks, 1.5), (.tuxedo, 1), (.spots, 1), (.points, 1)],
        ears: [(.floppy, 5), (.pointy, 2), (.folded, 2)],
        tails: [(.curled, 3), (.long, 2), (.stub, 1), (.bushy, 1)],
        eyes: [(.dark, 6), (.amber, 1), (.blue, 0.5)]
    )

    private static let bunny = SpeciesTraits(
        coats: [(.white, 3), (.grey, 2), (.chocolate, 2), (.cream, 2), (.tan, 1), (.black, 1)],
        secondaryCoats: [(.white, 4), (.cream, 1), (.chocolate, 1)],
        patterns: [(.solid, 4), (.patches, 2), (.points, 1), (.socks, 1)],
        ears: [(.tall, 5), (.lop, 2)],
        tails: [(.puff, 1)],
        eyes: [(.dark, 5), (.blue, 1)]
    )

    private static let fox = SpeciesTraits(
        coats: [(.russet, 6), (.silver, 1), (.white, 1), (.cream, 1)],
        secondaryCoats: [(.white, 5), (.black, 1)],
        patterns: [(.tuxedo, 4), (.points, 2), (.socks, 1)],
        ears: [(.pointy, 1)],
        tails: [(.bushy, 1)],
        eyes: [(.amber, 3), (.dark, 2)]
    )
}
