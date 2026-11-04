@testable import PRPetsArt
import PRPetsCore
import Testing

private let sampleGenomes = (0..<200).map { GenomeFactory.genome(for: Seed(hashing: "art-\($0)")) }

private func everyFrame(_ body: (PetGenome, PetPose, PixelImage) -> Void) {
    for genome in sampleGenomes {
        for adornment in [PetAdornment.none, PetAdornment(wearsStackCollar: true)] {
            let sheet = PetSpriteComposer.spriteSheet(for: genome, adornment: adornment)
            for pose in PetPose.allCases { body(genome, pose, sheet.frame(for: pose)) }
        }
    }
}

@Suite("Pet sprites")
struct PetSpriteTests {
    @Test func everyPoseFitsInsideTheFrameWithoutClipping() {
        everyFrame { genome, pose, image in
            guard let bounds = image.opaqueBounds else {
                Issue.record("\(genome.species) \(pose) is empty")
                return
            }
            // The bottom row is reserved for the outline under the feet, so only the other edges count.
            let touchesEdge = bounds.minX == 0 || bounds.minY == 0 || bounds.maxX == image.width - 1
            #expect(!touchesEdge, "\(genome.species) with \(genome.ears) ears and \(genome.tail) tail is clipped in \(pose): \(bounds)")
        }
    }

    @Test func petsStandOnTheGround() {
        // Every grounded pose's lowest pixel is the outline under the feet, so pets don't float or sink.
        let airbornePoses: Set<PetPose> = [.run2, .startle]
        everyFrame { genome, pose, image in
            guard !airbornePoses.contains(pose), let bounds = image.opaqueBounds else { return }
            #expect(bounds.maxY == PetSpriteSheet.frameHeight - 1, "\(genome.species) \(pose) bottom row is \(bounds.maxY)")
        }
    }

    @Test func spritesAreDeterministic() {
        let genome = sampleGenomes[7]
        #expect(PetSpriteComposer.spriteSheet(for: genome).frames == PetSpriteComposer.spriteSheet(for: genome).frames)
    }

    @Test func theStackCollarChangesHowAPetLooks() {
        let genome = sampleGenomes[3]
        let plain = PetSpriteComposer.spriteSheet(for: genome).frame(for: .stand)
        let collared = PetSpriteComposer.spriteSheet(for: genome, adornment: PetAdornment(wearsStackCollar: true)).frame(for: .stand)
        #expect(plain != collared)
    }

    @Test func theCollarColourShowsInTheSprite() {
        let genome = sampleGenomes[3]
        let adornment = PetAdornment(wearsStackCollar: true)
        let frames = CollarColour.allCases.map { collar in
            PetSpriteComposer.spriteSheet(for: genome.wearing(collar), adornment: adornment).frame(for: .stand)
        }
        // Colours too close to this pet's fur fall back to another, so count the colours it actually wears.
        let wornColours = Set(CollarColour.allCases.map { CoatPalette(genome: genome.wearing($0)).collar })
        #expect(wornColours.count > CollarColour.allCases.count / 2)
        #expect(Set(frames).count == wornColours.count, "each collar colour should paint differently")
        let uncollared = CollarColour.allCases.map { PetSpriteComposer.spriteSheet(for: genome.wearing($0)).frame(for: .stand) }
        #expect(Set(uncollared).count == 1, "the collar colour only matters when the pet wears one")
    }

    @Test func collarsStandOutFromTheFurTheySitOn() {
        let whiteCat = PetGenome(
            species: .cat, coat: .white, secondaryCoat: .cream, pattern: .solid, coatTint: 0, ears: .pointy, tail: .long,
            build: .regular, eyes: .blue, accessory: nil, collar: .white, temperament: Temperament(energy: 0, sleepiness: 0, curiosity: 0)
        )
        let gingerCat = PetGenome(
            species: .cat, coat: .ginger, secondaryCoat: .white, pattern: .tuxedo, coatTint: 0, ears: .pointy, tail: .long,
            build: .regular, eyes: .green, accessory: nil, collar: .orange, temperament: Temperament(energy: 0, sleepiness: 0, curiosity: 0)
        )
        for genome in [whiteCat, gingerCat] {
            let palette = CoatPalette(genome: genome)
            #expect(palette.collar.distance(to: palette.coat) >= 90)
            #expect(palette.collar.distance(to: palette.secondary) >= 90)
        }
    }

    @Test func differentGenomesLookDifferent() {
        let distinctStandingFrames = Set(sampleGenomes.map { PetSpriteComposer.spriteSheet(for: $0).frame(for: .stand) })
        #expect(distinctStandingFrames.count == Set(sampleGenomes).count)
    }

    @Test func walkingActuallyMovesTheLegs() {
        for genome in sampleGenomes.prefix(20) {
            let sheet = PetSpriteComposer.spriteSheet(for: genome)
            let walkFrames = Set([PetPose.walk1, .walk2, .walk3, .walk4].map(sheet.frame(for:)))
            #expect(walkFrames.count >= 3)
        }
    }

    @Test func mirroringFlipsColumns() {
        let frame = PetSpriteComposer.spriteSheet(for: sampleGenomes[0]).frame(for: .stand)
        let mirrored = frame.mirroredHorizontally()
        #expect(mirrored[0, 10] == frame[frame.width - 1, 10])
        #expect(mirrored.mirroredHorizontally() == frame)
    }
}

@Suite("Doghouse")
struct DoghouseTests {
    @Test func doorIsCentredAndOpaque() {
        let image = DoghouseArt.image
        #expect(image.width == DoghouseArt.width && image.height == DoghouseArt.height)
        let doorPixel = image[DoghouseArt.doorCentreX, DoghouseArt.height - 4]
        #expect(doorPixel.alpha == 255)
        #expect(doorPixel != image[6, DoghouseArt.height - 4], "the doorway is darker than the wall")
    }
}
