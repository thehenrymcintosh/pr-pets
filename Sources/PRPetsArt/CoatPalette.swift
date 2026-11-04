import PRPetsCore

/// The resolved colours for one pet.
struct CoatPalette: Sendable {
    let coat: RGBA
    let coatShade: RGBA
    let secondary: RGBA
    let secondaryShade: RGBA
    let outline: RGBA
    let iris: RGBA
    let pupil: RGBA
    let nose: RGBA
    let innerEar: RGBA
    let blush: RGBA
    let accessory: RGBA
    let accessoryShade: RGBA
    let collar: RGBA
    let tag: RGBA

    init(genome: PetGenome) {
        let tint = genome.coatTint * 0.08
        coat = Self.base(of: genome.coat).lightened(by: tint)
        coatShade = Self.shade(of: coat)
        secondary = Self.base(of: genome.secondaryCoat).lightened(by: tint * 0.5)
        secondaryShade = Self.shade(of: secondary)
        let darkerCoat = [coat, secondary].min { $0.luminance < $1.luminance }!
        outline = darkerCoat.luminance < 60
            ? RGBA(hex: 0x1b1626)
            : darkerCoat.lightened(by: -0.68).mixed(with: RGBA(hex: 0x2a1f3d), by: 0.3)
        // Dark eyes vanish on a dark coat, so those pets get glowing amber eyes instead.
        let isDarkCoat = coat.luminance < 80
        let iris = isDarkCoat && genome.eyes == .dark ? Self.iris(of: .amber) : Self.iris(of: genome.eyes)
        self.iris = iris
        pupil = isDarkCoat ? iris.lightened(by: 0.4) : RGBA(hex: 0x1d1a24)
        nose = Self.nose(of: genome.species, coat: coat)
        innerEar = RGBA(hex: 0xf2a0a8)
        blush = RGBA(hex: 0xf7a6b0)
        accessory = Self.accessoryColour(genome.accessory)
        accessoryShade = Self.shade(of: accessory)
        collar = Self.collarColour(genome.collar, standingOutFrom: [coat, secondary])
        tag = RGBA(hex: 0xf5c542)
    }

    private static func base(of coat: CoatColour) -> RGBA {
        switch coat {
        case .ginger: RGBA(hex: 0xf09a3e)
        case .black: RGBA(hex: 0x3b3542)
        case .grey: RGBA(hex: 0x9a9aa8)
        case .cream: RGBA(hex: 0xf3dcb2)
        case .white: RGBA(hex: 0xf8f6f2)
        case .chocolate: RGBA(hex: 0x8a5a3c)
        case .golden: RGBA(hex: 0xe6b860)
        case .silver: RGBA(hex: 0xc6ccd6)
        case .tan: RGBA(hex: 0xc9965f)
        case .russet: RGBA(hex: 0xe0662e)
        }
    }

    private static func shade(of colour: RGBA) -> RGBA {
        colour.luminance > 225
            ? colour.mixed(with: RGBA(hex: 0xb8c0d8), by: 0.45)
            : colour.lightened(by: -0.22)
    }

    private static func iris(of eyes: EyeColour) -> RGBA {
        switch eyes {
        case .dark: RGBA(hex: 0x1d1a24)
        case .green: RGBA(hex: 0x5cbf5a)
        case .amber: RGBA(hex: 0xe8a93a)
        case .blue: RGBA(hex: 0x5aa8e8)
        }
    }

    private static func nose(of species: Species, coat: RGBA) -> RGBA {
        switch species {
        case .cat, .bunny: RGBA(hex: 0xee8a9a)
        case .dog, .fox: RGBA(hex: 0x2a2230)
        }
    }

    /// The genome's collar, or the next colour along if it would blend into the fur it sits on.
    private static func collarColour(_ collar: CollarColour, standingOutFrom fur: [RGBA]) -> RGBA {
        let colours = CollarColour.allCases
        let start = colours.firstIndex(of: collar)!
        let candidates = (0..<colours.count).map { colours[(start + $0) % colours.count] }.map(collarColour)
        return candidates.first { candidate in fur.allSatisfy { candidate.distance(to: $0) >= 90 } } ?? candidates[0]
    }

    private static func collarColour(_ collar: CollarColour) -> RGBA {
        switch collar {
        case .red: RGBA(hex: 0xe23d3d)
        case .orange: RGBA(hex: 0xf28a1c)
        case .lime: RGBA(hex: 0x9acd32)
        case .green: RGBA(hex: 0x2fa84f)
        case .teal: RGBA(hex: 0x1fa5a0)
        case .sky: RGBA(hex: 0x4fc3f7)
        case .blue: RGBA(hex: 0x2f7de1)
        case .indigo: RGBA(hex: 0x4b45c4)
        case .purple: RGBA(hex: 0x8e4fd1)
        case .magenta: RGBA(hex: 0xd6379b)
        case .pink: RGBA(hex: 0xff8fb8)
        case .white: RGBA(hex: 0xfafafa)
        }
    }

    private static func accessoryColour(_ accessory: Accessory?) -> RGBA {
        switch accessory {
        case .bow: RGBA(hex: 0xe84a6f)
        case .bandana: RGBA(hex: 0xd83a3a)
        case .flower: RGBA(hex: 0xffd447)
        case nil: .clear
        }
    }
}

extension RGBA {
    /// Straight-line distance in RGB, 0...441.
    func distance(to other: RGBA) -> Double {
        let channels = [(red, other.red), (green, other.green), (blue, other.blue)]
        return channels.reduce(0.0) { total, pair in
            let difference = Double(pair.0) - Double(pair.1)
            return total + difference * difference
        }.squareRoot()
    }

    var luminance: Double {
        0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue)
    }
}
