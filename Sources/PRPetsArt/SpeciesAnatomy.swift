import PRPetsCore

/// Paints each body part for a genome in a given skeleton. All shapes are hand-placed pixel offsets.
struct SpeciesAnatomy {
    let genome: PetGenome
    let skeleton: PetSkeleton

    private static let headWidth = 7
    private static let headHeight = 6

    private var headX: Int { skeleton.head.x }
    private var headY: Int { skeleton.head.y }
    private var headRight: Int { headX + Self.headWidth - 1 }
    private var headBottom: Int { headY + Self.headHeight - 1 }
    private var isLying: Bool { skeleton.posture == .lying }

    // MARK: Legs

    func paintFarLegs(on canvas: inout PaintCanvas) {
        for leg in skeleton.legs where leg.isFarSide { paintLeg(leg, ink: .coatShade, on: &canvas) }
    }

    func paintNearLegs(on canvas: inout PaintCanvas) {
        for leg in skeleton.legs where !leg.isFarSide { paintLeg(leg, ink: .coat, on: &canvas) }
    }

    private func paintLeg(_ leg: PetSkeleton.Leg, ink: Ink, on canvas: inout PaintCanvas) {
        let width = 2
        let columns = leg.x...(leg.x + width - 1)
        if leg.top < leg.bottom {
            canvas.fill(x: columns, y: leg.top...(leg.bottom - 1), .leg, ink)
        }
        canvas.fill(x: columns, y: leg.bottom...leg.bottom, .paw, ink)
    }

    // MARK: Body

    func paintBody(on canvas: inout PaintCanvas) {
        let body = skeleton.body
        switch skeleton.posture {
        case .standing, .lying:
            canvas.fillRounded(x: body.x, y: body.y, .body)
        case .sitting:
            // Upright chest towards the front, rounded haunch at the back.
            canvas.fillRounded(x: (body.x.lowerBound + 2)...body.x.upperBound, y: body.y, .body)
            canvas.fillRounded(x: body.x.lowerBound...(body.x.lowerBound + 5), y: (body.y.upperBound - 4)...body.y.upperBound, .body)
            canvas.paint(body.x.lowerBound + 2, body.y.upperBound, .paw)
            canvas.paint(body.x.lowerBound + 3, body.y.upperBound, .paw)
        }
        let chestColumns = (body.x.upperBound - 2)...body.x.upperBound
        canvas.recolour(x: chestColumns, y: (body.y.lowerBound + 1)...body.y.upperBound, from: .body, to: .chest)
    }

    // MARK: Head

    func paintHead(on canvas: inout PaintCanvas) {
        let rows = headY...headBottom
        switch genome.species {
        case .bunny:
            canvas.fillRounded(x: (headX + 1)...headRight, y: rows, .head)
        case .cat, .dog, .fox:
            canvas.fillRounded(x: headX...headRight, y: rows, .head)
        }
        switch genome.species {
        case .dog:
            canvas.fill(x: (headX + 2)...(headX + 4), y: (headY + 4)...(headY + 5), .muzzle)
            canvas.paint(headX + 3, headY + 6, .muzzle)
        case .fox:
            canvas.fill(x: (headRight - 2)...(headRight + 1), y: (headY + 3)...(headY + 5), .muzzle)
            canvas.paint(headRight + 2, headY + 4, .muzzle)
            canvas.paint(headX + 1, headBottom + 1, .head)
        case .cat:
            canvas.fill(x: (headRight - 3)...(headRight - 1), y: (headY + 4)...(headY + 5), .muzzle)
        case .bunny:
            canvas.fill(x: (headRight - 2)...headRight, y: (headY + 4)...(headY + 5), .muzzle)
        }
    }

    func paintFace(on canvas: inout PaintCanvas) {
        let eyeRow = headY + 2
        let (farEyeX, nearEyeX) = eyeColumns
        for eyeX in [farEyeX, nearEyeX] {
            if skeleton.eyesClosed {
                canvas.paint(eyeX, eyeRow + 1, .head, .eyelid)
            } else {
                canvas.paint(eyeX, eyeRow, .head, .pupil)
                canvas.paint(eyeX, eyeRow + 1, .head, .iris)
            }
        }
        switch genome.species {
        case .cat, .bunny:
            canvas.paint(headRight - 2, headY + 4, .muzzle, .nose)
            canvas.paint(farEyeX - 1, headY + 4, .head, .blush)
            canvas.paint(headRight, headY + 4, .head, .blush)
        case .dog:
            canvas.paint(headX + 3, headY + 4, .muzzle, .nose)
            canvas.paint(headX + 1, headY + 4, .head, .blush)
            canvas.paint(headX + 5, headY + 4, .head, .blush)
        case .fox:
            canvas.paint(headRight + 2, headY + 4, .muzzle, .nose)
        }
    }

    private var eyeColumns: (far: Int, near: Int) {
        switch genome.species {
        case .cat, .fox: (headX + 2, headX + 5)
        case .bunny: (headX + 3, headX + 5)
        case .dog: (headX + 2, headX + 4)
        }
    }

    // MARK: Ears

    func paintFarEar(on canvas: inout PaintCanvas) {
        paintEar(anchorX: headX + 1, isFarSide: true, on: &canvas)
    }

    func paintNearEar(on canvas: inout PaintCanvas) {
        paintEar(anchorX: headRight - 2, isFarSide: false, on: &canvas)
    }

    private func paintEar(anchorX: Int, isFarSide: Bool, on canvas: inout PaintCanvas) {
        let ink: Ink = isFarSide ? .coatShade : .coat
        let top = headY
        let droop = isLying ? 1 : 0
        switch genome.ears {
        case .pointy, .tufted:
            canvas.fill(x: anchorX...(anchorX + 2), y: (top - 1)...(top - 1), .ear, ink)
            canvas.fill(x: anchorX...(anchorX + 1), y: (top - 2)...(top - 2), .ear, ink)
            if droop == 0 { canvas.paint(anchorX, top - 3, .ear, ink) }
            if genome.ears == .tufted, droop == 0 { canvas.paint(anchorX, top - 4, .ear, .coatShade) }
            if !isFarSide { canvas.paint(anchorX + 1, top - 1, .ear, .innerEar) }
        case .folded:
            canvas.fill(x: anchorX...(anchorX + 2), y: (top - 1)...(top - 1), .ear, ink)
            canvas.paint(anchorX + 2, top, .ear, ink)
        case .floppy where isFarSide:
            break
        case .floppy:
            // Both ears hang either side of a front-facing head, so they're painted together over it.
            canvas.fill(x: (headX - 1)...headX, y: (top + 1)...(top + 3), .ear, .coatDeep)
            canvas.fill(x: headRight...(headRight + 1), y: (top + 1)...(top + 3), .ear, .coatDeep)
            canvas.paint(headX - 1, top + 4, .ear, .coatDeep)
            canvas.paint(headRight + 1, top + 4, .ear, .coatDeep)
        case .tall:
            let earTop = top - 5 + droop * 2
            canvas.fill(x: anchorX...(anchorX + 1), y: earTop...(top - 1), .ear, ink)
            if !isFarSide { canvas.fill(x: (anchorX + 1)...(anchorX + 1), y: (earTop + 1)...(top - 1), .ear, .innerEar) }
        case .lop:
            let earX = isFarSide ? headX : headRight - 2
            canvas.fill(x: earX...(earX + 1), y: (top - 1)...(top + 4), .ear, isFarSide ? .coatShade : .coat)
        }
    }

    // MARK: Tail

    func paintTail(on canvas: inout PaintCanvas) {
        let root = skeleton.tailRoot
        let onGround = skeleton.posture != .standing
        let points = onGround ? Self.restingTailPoints(genome.tail) : Self.tailPoints(genome.tail, sway: skeleton.tailSway)
        let tipCount = genome.tail == .bushy ? 3 : 1
        for (offset, point) in points.enumerated() {
            let isTip = offset >= points.count - tipCount
            let ink: Ink = genome.tail == .puff ? .coatHighlight : .coat
            canvas.paint(root.x + point.0, root.y + point.1, isTip ? .tailTip : .tail, ink)
        }
    }

    private static func tailPoints(_ tail: TailShape, sway: Int) -> [(Int, Int)] {
        switch tail {
        case .long where sway == 0: [(-1, 0), (-2, -1), (-2, -2), (-2, -3), (-2, -4), (-1, -5)]
        case .long: [(-1, 0), (-2, -1), (-3, -2), (-3, -3), (-3, -4), (-2, -5)]
        case .curled: [(-1, 0), (-1, -1), (-2, -1), (-2, -2), (-1, -3), (0, -3)]
        case .stub: [(-1, 0), (-1, -1)]
        case .bushy where sway == 0:
            [(-1, 0), (-1, 1), (-2, 0), (-2, 1), (-3, 1), (-3, 2), (-4, 1), (-4, 2), (-4, 3), (-5, 2), (-5, 3), (-5, 4)]
        case .bushy:
            [(-1, 0), (-1, 1), (-2, 0), (-2, 1), (-3, 0), (-3, 1), (-4, 0), (-4, 1), (-4, 2), (-5, 1), (-5, 2), (-6, 1)]
        case .puff: [(0, 1), (-1, 1), (-1, 2), (0, 2), (-1, 0)]
        }
    }

    private static func restingTailPoints(_ tail: TailShape) -> [(Int, Int)] {
        switch tail {
        case .long: [(-1, 0), (-2, 1), (-3, 1), (-4, 1), (-5, 0)]
        case .curled: [(-1, 0), (-2, -1), (-2, -2), (-1, -2)]
        case .stub: [(-1, 0)]
        case .bushy: [(-1, 0), (-2, 0), (-2, 1), (-3, 0), (-3, 1), (-4, 1), (-5, 1), (-4, 0), (-6, 1)]
        case .puff: [(-1, 0), (-1, -1), (0, -1)]
        }
    }

    // MARK: Accessories

    func paintNeckwear(on canvas: inout PaintCanvas, adornment: PetAdornment) {
        guard !isLying else { return }
        let neckRow = headBottom + 1
        let neckColumns = (headX + 2)...(headRight - 1)
        if adornment.wearsStackCollar {
            canvas.fill(x: neckColumns, y: neckRow...neckRow, .chest, .collar)
            canvas.paint(neckColumns.upperBound - 1, neckRow + 1, .chest, .tag)
        } else if genome.accessory == .bandana {
            canvas.fill(x: neckColumns, y: neckRow...neckRow, .chest, .accessory)
            canvas.fill(x: (neckColumns.lowerBound + 1)...(neckColumns.upperBound - 1), y: (neckRow + 1)...(neckRow + 1), .chest, .accessoryShade)
        }
    }

    func paintHeadwear(on canvas: inout PaintCanvas) {
        let bowX = headRight - 3
        switch genome.accessory {
        case .bow:
            canvas.paint(bowX - 1, headY, .head, .accessory)
            canvas.paint(bowX, headY, .head, .accessoryShade)
            canvas.paint(bowX + 1, headY, .head, .accessory)
            canvas.paint(bowX - 1, headY + 1, .head, .accessory)
            canvas.paint(bowX + 1, headY + 1, .head, .accessory)
        case .flower:
            canvas.paint(bowX, headY, .head, .accessoryCentre)
            canvas.paint(bowX - 1, headY, .head, .accessory)
            canvas.paint(bowX + 1, headY, .head, .accessory)
            canvas.paint(bowX, headY - 1, .head, .accessory)
        case .bandana, nil:
            break
        }
    }
}
