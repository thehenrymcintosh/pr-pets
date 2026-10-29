/// Which part of the body a pixel belongs to. Coat patterns are applied per region.
enum BodyRegion: Hashable, Sendable {
    case body, chest, head, muzzle, ear, tail, tailTip, leg, paw
}

/// What a pixel is painted with, before colours are resolved.
enum Ink: Hashable, Sendable {
    /// Main coat colour, or the secondary colour where the pattern says so.
    case coat
    /// The coat in shadow: far-side legs and ears.
    case coatShade
    /// The coat, much darker. Floppy ears.
    case coatDeep
    /// The coat, lightened. Bunny tails.
    case coatHighlight
    case pupil, iris, eyelid, nose, innerEar, blush
    case accessory, accessoryShade, accessoryCentre
    case collar, tag
}

struct Paint: Hashable, Sendable {
    let region: BodyRegion
    let ink: Ink
}

/// A grid of semantic paint, drawn back-to-front; later strokes cover earlier ones.
struct PaintCanvas: Sendable {
    let width: Int
    let height: Int
    private(set) var cells: [Paint?]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        cells = Array(repeating: nil, count: width * height)
    }

    subscript(x: Int, y: Int) -> Paint? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        return cells[y * width + x]
    }

    mutating func paint(_ x: Int, _ y: Int, _ region: BodyRegion, _ ink: Ink = .coat) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        cells[y * width + x] = Paint(region: region, ink: ink)
    }

    mutating func paint(_ points: [(Int, Int)], at origin: (x: Int, y: Int), _ region: BodyRegion, _ ink: Ink = .coat) {
        for (dx, dy) in points { paint(origin.x + dx, origin.y + dy, region, ink) }
    }

    mutating func fill(x: ClosedRange<Int>, y: ClosedRange<Int>, _ region: BodyRegion, _ ink: Ink = .coat) {
        for row in y { for column in x { paint(column, row, region, ink) } }
    }

    /// A rectangle with its four corner pixels left off, which reads as rounded at this size.
    mutating func fillRounded(x: ClosedRange<Int>, y: ClosedRange<Int>, _ region: BodyRegion, _ ink: Ink = .coat) {
        let corners: Set<[Int]> = [
            [x.lowerBound, y.lowerBound], [x.upperBound, y.lowerBound],
            [x.lowerBound, y.upperBound], [x.upperBound, y.upperBound],
        ]
        for row in y {
            for column in x where !corners.contains([column, row]) { paint(column, row, region, ink) }
        }
    }

    /// Repaints already-painted pixels of one region in a range.
    mutating func recolour(x: ClosedRange<Int>, y: ClosedRange<Int>, from source: BodyRegion, to region: BodyRegion) {
        for row in y {
            for column in x where self[column, row]?.region == source {
                paint(column, row, region, self[column, row]!.ink)
            }
        }
    }
}
