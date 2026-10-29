import CoreGraphics
import PRPetsCore
import PRPetsDemo
import PRPetsRender
import Testing

private let viewSize = CGSize(width: 1200, height: YardViewport.requiredHeight(scale: 3))

private func viewport(_ roamingArea: RoamingArea = .nearDoghouse) -> YardViewport {
    YardViewport(scale: 3, viewSize: viewSize, doghouseCentreX: 900, roamingArea: roamingArea, roamingWidth: 400)
}

@Suite("Yard scene")
struct YardSceneTests {
    @Test func nearDoghouseRoamingStaysAroundTheDoghouse() {
        let span = viewport().geometry.roamingSpan
        #expect(span.lowerBound * 3 >= 900 - 200 - 0.001)
        #expect(span.upperBound * 3 <= 900 + 200 + 0.001)
    }

    @Test func screenWidthRoamingKeepsPetsOnScreen() {
        let span = viewport(.screenWidth).geometry.roamingSpan
        #expect(span.lowerBound > 0)
        #expect(span.upperBound * 3 < viewSize.width)
    }

    @Test func theDoghouseFitsInTheOverlay() {
        let rect = viewport().doghouseRect
        #expect(CGRect(origin: .zero, size: viewSize).contains(rect))
    }

    @Test func clicksFindPetsAndTheDoghouse() {
        let viewport = viewport()
        var yard = Yard(geometry: viewport.geometry)
        let pullRequest = PullRequestFixture.make(1)
        yard.reconcile(with: PetRoster(entries: [PetRosterEntry(
            id: pullRequest.id, genome: GenomeFactory.genome(for: Seed(1)), label: "alice", stackPosition: nil
        )]))
        var random = SeededRandom(seed: Seed(1))
        for _ in 0..<90 { yard.advance(by: 1.0 / 30, using: &random) }
        let scene = YardScene(viewport: viewport, yard: yard, doghouse: DoghouseStatus())
        let sprites = SpriteCache()
        let pet = scene.placement(of: yard.pets[0], using: sprites)

        #expect(scene.hitTest(CGPoint(x: pet.bodyRect.midX, y: pet.bodyRect.midY), using: sprites) == .pet(pullRequest.id))
        #expect(scene.hitTest(CGPoint(x: viewport.doghouseRect.midX, y: viewport.doghouseRect.minY + 4), using: sprites) == .doghouse)
        #expect(scene.hitTest(CGPoint(x: 5, y: 5), using: sprites) == nil, "empty overlay lets clicks through")
    }

    @Test func aHoveredPetStaysHoveredAfterItSitsDown() throws {
        let viewport = viewport()
        var yard = Yard(geometry: viewport.geometry)
        let pullRequest = PullRequestFixture.make(1)
        yard.reconcile(with: PetRoster(entries: [PetRosterEntry(
            id: pullRequest.id, genome: GenomeFactory.genome(for: Seed(1)), label: "alice", stackPosition: nil
        )]))
        var random = SeededRandom(seed: Seed(1))
        for _ in 0..<90 { yard.advance(by: 1.0 / 30, using: &random) }
        yard.hold(pullRequest.id)
        let scene = YardScene(viewport: viewport, yard: yard, doghouse: DoghouseStatus())
        let sprites = SpriteCache()
        let area = scene.hoverArea(of: yard.pets[0], using: sprites)

        // Somewhere the standing pet covered but the sitting pet doesn't: where the cursor used to fall off.
        let points = stride(from: area.minX, through: area.maxX, by: 1).flatMap { x in
            stride(from: area.minY, through: area.maxY, by: 1).map { CGPoint(x: x, y: $0) }
        }
        let uncoveredBySitting = try #require(points.first { scene.hitTest($0, using: sprites) != .pet(pullRequest.id) })
        #expect(scene.hitTest(uncoveredBySitting, using: sprites, keepingHoverOn: pullRequest.id) == .pet(pullRequest.id))
    }

    @Test func renderingDrawsSomething() {
        let viewport = viewport()
        let scene = YardScene(viewport: viewport, yard: Yard(geometry: viewport.geometry), doghouse: DoghouseStatus(waitingCount: 2))
        let context = CGContext(
            data: nil, width: Int(viewSize.width), height: Int(viewSize.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        YardRenderer(sprites: SpriteCache()).draw(scene, in: context)
        let data = context.data!.assumingMemoryBound(to: UInt8.self)
        let opaquePixels = (0..<(context.bytesPerRow * context.height / 4)).filter { data[$0 * 4 + 3] > 0 }.count
        #expect(opaquePixels > 1000)
    }
}
