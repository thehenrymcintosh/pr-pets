import CoreGraphics
import PRPetsArt
import PRPetsCore

/// One rendered frame: the bitmap plus where its opaque pixels are, for labels and hit testing.
public struct SpriteFrame {
    public let image: CGImage
    /// Opaque area in art pixels within the frame.
    public let opaqueBounds: CGRect
}

/// Composes each pet's sprites once and keeps them. Not thread-safe: use from one thread.
public final class SpriteCache {
    private struct Key: Hashable {
        let genome: PetGenome
        let adornment: PetAdornment
        let pose: PetPose
        let facing: Facing
    }

    private var frames: [Key: SpriteFrame] = [:]
    private var sheets: [PetGenome: [PetAdornment: PetSpriteSheet]] = [:]
    public private(set) lazy var doghouse: CGImage = DoghouseArt.image.cgImage!

    public init() {}

    public func frame(for genome: PetGenome, adornment: PetAdornment, pose: PetPose, facing: Facing) -> SpriteFrame {
        let key = Key(genome: genome, adornment: adornment, pose: pose, facing: facing)
        if let cached = frames[key] { return cached }
        let pixels = sheet(for: genome, adornment: adornment).frame(for: pose)
        let oriented = facing == .right ? pixels : pixels.mirroredHorizontally()
        let bounds = oriented.opaqueBounds.map {
            CGRect(x: $0.minX, y: $0.minY, width: $0.maxX - $0.minX + 1, height: $0.maxY - $0.minY + 1)
        } ?? .zero
        let frame = SpriteFrame(image: oriented.cgImage!, opaqueBounds: bounds)
        frames[key] = frame
        return frame
    }

    /// Forgets pets that have left so the cache doesn't grow forever.
    public func retainOnly(_ genomes: Set<PetGenome>) {
        frames = frames.filter { genomes.contains($0.key.genome) }
        sheets = sheets.filter { genomes.contains($0.key) }
    }

    private func sheet(for genome: PetGenome, adornment: PetAdornment) -> PetSpriteSheet {
        if let sheet = sheets[genome]?[adornment] { return sheet }
        let sheet = PetSpriteComposer.spriteSheet(for: genome, adornment: adornment)
        sheets[genome, default: [:]][adornment] = sheet
        return sheet
    }
}
