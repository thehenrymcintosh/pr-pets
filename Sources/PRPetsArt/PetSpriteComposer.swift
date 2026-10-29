import PRPetsCore

/// Every frame for one pet, facing right. Mirror for facing left.
public struct PetSpriteSheet: Sendable {
    public let frames: [PetPose: PixelImage]

    public func frame(for pose: PetPose) -> PixelImage {
        frames[pose]!
    }

    public static let frameWidth = PetSkeleton.frameWidth
    public static let frameHeight = PetSkeleton.frameHeight
}

/// What to draw a pet wearing, beyond its genome.
public struct PetAdornment: Hashable, Sendable {
    /// A collar and tag marks pets whose PR is part of a stack.
    public let wearsStackCollar: Bool

    public init(wearsStackCollar: Bool) { self.wearsStackCollar = wearsStackCollar }

    public static let none = PetAdornment(wearsStackCollar: false)
}

public enum PetSpriteComposer {
    public static func spriteSheet(for genome: PetGenome, adornment: PetAdornment = .none) -> PetSpriteSheet {
        let palette = CoatPalette(genome: genome)
        let frames = Dictionary(uniqueKeysWithValues: PetPose.allCases.map { pose in
            let canvas = paint(genome, adornment: adornment, pose: pose)
            return (pose, CoatResolver(genome: genome, palette: palette, canvas: canvas).image())
        })
        return PetSpriteSheet(frames: frames)
    }

    static func paint(_ genome: PetGenome, adornment: PetAdornment, pose: PetPose) -> PaintCanvas {
        let skeleton = PetSkeleton(build: genome.build, pose: pose)
        var canvas = PaintCanvas(width: PetSkeleton.frameWidth, height: PetSkeleton.frameHeight)
        let species = SpeciesAnatomy(genome: genome, skeleton: skeleton)
        species.paintFarLegs(on: &canvas)
        species.paintTail(on: &canvas)
        species.paintFarEar(on: &canvas)
        species.paintBody(on: &canvas)
        species.paintNearLegs(on: &canvas)
        species.paintHead(on: &canvas)
        species.paintNearEar(on: &canvas)
        species.paintFace(on: &canvas)
        species.paintNeckwear(on: &canvas, adornment: adornment)
        species.paintHeadwear(on: &canvas)
        return canvas
    }
}
