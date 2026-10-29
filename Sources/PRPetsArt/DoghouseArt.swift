/// The red doghouse the pets live in, drawn from the front with an arched door.
public enum DoghouseArt {
    public static let width = 34
    public static let height = 30
    /// Column at the centre of the door.
    public static let doorCentreX = 17
    /// Height of the door opening in art pixels.
    public static let doorHeight = 11

    private static let wall = RGBA(hex: 0xd8333a)
    private static let wallShade = RGBA(hex: 0xb5242f)
    private static let roof = RGBA(hex: 0xa81e2a)
    private static let roofHighlight = RGBA(hex: 0xc72a35)
    private static let doorway = RGBA(hex: 0x1c1420)
    private static let outline = RGBA(hex: 0x2a0f16)

    public static let image: PixelImage = draw()

    private static func draw() -> PixelImage {
        var image = PixelImage(width: width, height: height)
        let centre = Double(width - 1) / 2
        let roofRows = 0...12
        let wallRows = 12...(height - 2)
        let wallColumns = 5...(width - 6)

        for row in wallRows {
            for column in wallColumns {
                let isPlankLine = (row - wallRows.lowerBound).isMultiple(of: 4) && row != wallRows.lowerBound
                image[column, row] = isPlankLine ? wallShade : wall
            }
        }
        for row in roofRows {
            let outerHalfWidth = 1.5 + Double(row) * 1.25
            let innerHalfWidth = outerHalfWidth - 3.2
            for column in 0..<width {
                let distance = abs(Double(column) - centre)
                guard distance <= outerHalfWidth else { continue }
                let isRoofBoard = distance > innerHalfWidth || row == roofRows.upperBound
                if isRoofBoard {
                    image[column, row] = row.isMultiple(of: 3) ? roofHighlight : roof
                } else {
                    image[column, row] = wall
                }
            }
        }
        paintDoor(on: &image)
        return outlined(image)
    }

    private static func paintDoor(on image: inout PixelImage) {
        let halfWidth = 4.5
        let bottom = height - 2
        let top = bottom - doorHeight + 1
        let centre = Double(doorCentreX)
        for row in top...bottom {
            let archRise = Double(row - top)
            for column in 0..<width {
                let dx = Double(column) - centre + 0.5
                let isInsideArch = archRise >= halfWidth || (dx * dx + (halfWidth - archRise) * (halfWidth - archRise)) <= halfWidth * halfWidth
                if abs(dx) <= halfWidth, isInsideArch { image[column, row] = doorway }
            }
        }
    }

    private static func outlined(_ image: PixelImage) -> PixelImage {
        var result = image
        for y in 0..<image.height {
            for x in 0..<image.width where !image.isOpaque(x: x, y: y) {
                let touchesShape = [(-1, 0), (1, 0), (0, -1), (0, 1)].contains { image.isOpaque(x: x + $0.0, y: y + $0.1) }
                if touchesShape { result[x, y] = outline }
            }
        }
        return result
    }
}
