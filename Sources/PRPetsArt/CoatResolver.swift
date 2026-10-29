import PRPetsCore

/// Turns semantic paint into colours: applies the coat pattern per region, then outlines the silhouette.
struct CoatResolver {
    let genome: PetGenome
    let palette: CoatPalette
    let canvas: PaintCanvas
    private let patternSeed: UInt64

    init(genome: PetGenome, palette: CoatPalette, canvas: PaintCanvas) {
        self.genome = genome
        self.palette = palette
        self.canvas = canvas
        // String(describing:) of a value type is stable across runs, unlike Hasher.
        self.patternSeed = Seed(hashing: String(describing: genome)).rawValue
    }

    func image() -> PixelImage {
        var image = PixelImage(width: canvas.width, height: canvas.height)
        for y in 0..<canvas.height {
            for x in 0..<canvas.width {
                if let paint = canvas[x, y] { image[x, y] = colour(of: paint, x: x, y: y) }
            }
        }
        return outlined(image)
    }

    private func colour(of paint: Paint, x: Int, y: Int) -> RGBA {
        switch paint.ink {
        case .coat: coatColour(region: paint.region, x: x, y: y, shaded: false)
        case .coatShade: coatColour(region: paint.region, x: x, y: y, shaded: true)
        case .coatDeep: coatColour(region: paint.region, x: x, y: y, shaded: true).lightened(by: -0.25)
        case .coatHighlight: palette.coat.lightened(by: 0.55)
        case .pupil: palette.pupil
        case .iris: palette.iris
        case .eyelid: palette.outline
        case .nose: palette.nose
        case .innerEar: palette.innerEar
        case .blush: palette.blush
        case .accessory: palette.accessory
        case .accessoryShade: palette.accessoryShade
        case .accessoryCentre: RGBA(hex: 0xf08a24)
        case .collar: palette.collar
        case .tag: palette.tag
        }
    }

    private func coatColour(region: BodyRegion, x: Int, y: Int, shaded: Bool) -> RGBA {
        switch coatTone(region: region, x: x, y: y) {
        case .primary: shaded ? palette.coatShade : palette.coat
        case .secondary: shaded ? palette.secondaryShade : palette.secondary
        case .stripe: palette.coatShade.lightened(by: -0.12)
        case .point: palette.coat.lightened(by: -0.45)
        }
    }

    private enum CoatTone { case primary, secondary, stripe, point }

    private func coatTone(region: BodyRegion, x: Int, y: Int) -> CoatTone {
        switch genome.pattern {
        case .solid:
            return .primary
        case .tabby:
            let isStripedRegion = [.body, .head, .tail].contains(region)
            let isStripe = region == .tail ? y.isMultiple(of: 2) : x.isMultiple(of: 3) && isNearTopOfRegion(region, y: y)
            return isStripedRegion && isStripe ? .stripe : .primary
        case .patches:
            let isPatchableRegion = [.body, .head, .chest, .leg, .tail].contains(region)
            return isPatchableRegion && noise(x / 3, y / 3) > 0.55 ? .secondary : .primary
        case .socks:
            return region == .paw ? .secondary : .primary
        case .tuxedo:
            return [.chest, .paw, .muzzle, .tailTip].contains(region) ? .secondary : .primary
        case .spots:
            let isSpot = region == .body && noise(x, y) > 0.82
            return isSpot ? .secondary : .primary
        case .points:
            return [.ear, .muzzle, .tailTip, .paw, .leg].contains(region) ? .point : .primary
        }
    }

    private func isNearTopOfRegion(_ region: BodyRegion, y: Int) -> Bool {
        let rows = (0..<canvas.height).filter { row in (0..<canvas.width).contains { canvas[$0, row]?.region == region } }
        guard let top = rows.first else { return false }
        return y <= top + 2
    }

    /// Deterministic per-pet value noise in 0...1.
    private func noise(_ x: Int, _ y: Int) -> Double {
        var random = SeededRandom(seed: Seed(patternSeed ^ (UInt64(bitPattern: Int64(x)) &* 73_856_093) ^ (UInt64(bitPattern: Int64(y)) &* 19_349_663)))
        return Double(random.next() % 10_000) / 10_000
    }

    private func outlined(_ image: PixelImage) -> PixelImage {
        var result = image
        let neighbours = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        for y in 0..<image.height {
            for x in 0..<image.width where !image.isOpaque(x: x, y: y) {
                if neighbours.contains(where: { image.isOpaque(x: x + $0.0, y: y + $0.1) }) {
                    result[x, y] = palette.outline
                }
            }
        }
        return result
    }
}
