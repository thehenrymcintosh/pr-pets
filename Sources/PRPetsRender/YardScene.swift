import CoreGraphics
import PRPetsArt
import PRPetsCore

/// What the doghouse should show about the queue.
public struct DoghouseStatus: Hashable, Sendable {
    /// PRs that would have a pet out, whether or not the pets are inside right now.
    public var waitingCount: Int
    public var petsAreInside: Bool
    /// The last refresh failed; the dashboard has the details.
    public var hasProblem: Bool

    public init(waitingCount: Int = 0, petsAreInside: Bool = false, hasProblem: Bool = false) {
        self.waitingCount = waitingCount
        self.petsAreInside = petsAreInside
        self.hasProblem = hasProblem
    }
}

/// The quick summary shown while hovering a pet.
public struct HoverCard: Hashable, Sendable {
    public let petID: PullRequestID
    public let title: String
    public let reference: String
    public let lineDelta: LineDelta

    public init(petID: PullRequestID, title: String, reference: String, lineDelta: LineDelta) {
        self.petID = petID
        self.title = title
        self.reference = reference
        self.lineDelta = lineDelta
    }
}

public enum SceneHit: Hashable, Sendable {
    case pet(PullRequestID)
    case doghouse
}

/// A pet positioned in view points, ready to draw.
public struct PetPlacement {
    public let pet: YardPet
    public let frame: SpriteFrame
    /// The whole sprite frame.
    public let spriteRect: CGRect
    /// Just the opaque pixels: used for hit testing and label placement.
    public let bodyRect: CGRect
    public let opacity: CGFloat
}

/// One frame of the overlay: the yard plus everything drawn around it.
public struct YardScene {
    public let viewport: YardViewport
    public let yard: Yard
    public let doghouse: DoghouseStatus
    public let hoverCard: HoverCard?

    public init(viewport: YardViewport, yard: Yard, doghouse: DoghouseStatus, hoverCard: HoverCard? = nil) {
        self.viewport = viewport
        self.yard = yard
        self.doghouse = doghouse
        self.hoverCard = hoverCard
    }

    public func placements(using sprites: SpriteCache) -> [PetPlacement] {
        yard.petsInDrawingOrder.map { pet in placement(of: pet, using: sprites) }
    }

    public func placement(of pet: YardPet, using sprites: SpriteCache) -> PetPlacement {
        placement(of: pet, in: pet.pose(at: yard.clock), using: sprites)
    }

    private func placement(of pet: YardPet, in pose: PetPose, using sprites: SpriteCache) -> PetPlacement {
        let scale = viewport.scale
        let adornment = PetAdornment(wearsStackCollar: pet.entry.stackPosition != nil)
        let frame = sprites.frame(for: pet.genome, adornment: adornment, pose: pose, facing: pet.facing)
        let foot = viewport.footPoint(of: pet.position)
        let spriteRect = CGRect(
            x: foot.x - CGFloat(PetSpriteSheet.frameWidth) / 2 * scale,
            y: foot.y - CGFloat(PetSpriteSheet.frameHeight - 1) * scale,
            width: CGFloat(PetSpriteSheet.frameWidth) * scale,
            height: CGFloat(PetSpriteSheet.frameHeight) * scale
        )
        let bodyRect = CGRect(
            x: spriteRect.minX + frame.opaqueBounds.minX * scale,
            y: spriteRect.minY + frame.opaqueBounds.minY * scale,
            width: frame.opaqueBounds.width * scale,
            height: frame.opaqueBounds.height * scale
        )
        return PetPlacement(
            pet: pet, frame: frame, spriteRect: spriteRect, bodyRect: bodyRect,
            opacity: CGFloat(pet.opacity(at: yard.clock, door: yard.geometry.door))
        )
    }

    /// The pet or doghouse under a point, front-most first. Pets get a little slack so they're easy to catch.
    /// The pet already being hovered keeps the hover while the cursor is anywhere it covers standing or sitting,
    /// since it sits down when hovered and would otherwise slip out from under the cursor and flicker.
    public func hitTest(_ point: CGPoint, using sprites: SpriteCache, keepingHoverOn hoveredPetID: PullRequestID? = nil) -> SceneHit? {
        let slack = max(2, viewport.scale)
        if let hoveredPet = hoveredPetID.flatMap(yard.pet(withID:)),
           hoverArea(of: hoveredPet, using: sprites).insetBy(dx: -slack, dy: -slack).contains(point) {
            return .pet(hoveredPet.id)
        }
        let placements = placements(using: sprites)
        let inFront = placements.filter { $0.pet.position.depth >= YardViewport.doghouseDepth }
        let behind = placements.filter { $0.pet.position.depth < YardViewport.doghouseDepth }
        func petHit(in candidates: [PetPlacement]) -> SceneHit? {
            candidates.reversed()
                .first { $0.opacity > 0.5 && $0.bodyRect.insetBy(dx: -slack, dy: -slack).contains(point) }
                .map { .pet($0.pet.id) }
        }
        if let hit = petHit(in: inFront) { return hit }
        if viewport.doghouseRect.contains(point) { return .doghouse }
        return petHit(in: behind)
    }

    /// Everything a pet covers in its current pose and while standing.
    public func hoverArea(of pet: YardPet, using sprites: SpriteCache) -> CGRect {
        placement(of: pet, using: sprites).bodyRect.union(placement(of: pet, in: .stand, using: sprites).bodyRect)
    }
}
