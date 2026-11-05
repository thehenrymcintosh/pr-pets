import CoreGraphics
import Foundation
import PRPetsArt
import PRPetsCore
import PRPetsRender

/// A grid of generated pets, one per seed, for eyeballing variety.
enum ContactSheet {
    static func render(seedCount: Int, pose: PetPose, scale: Int, species: [Species] = Species.allCases) -> CGImage {
        let columns = 10
        let rows = Int((Double(seedCount) / Double(columns)).rounded(.up))
        let cellWidth = (PetSpriteSheet.frameWidth + 2) * scale
        let cellHeight = (PetSpriteSheet.frameHeight + 2) * scale
        let canvas = PreviewCanvas(width: columns * cellWidth, height: rows * cellHeight, background: 0xf4efe6)
        for index in 0..<seedCount {
            let genome = GenomeFactory.genome(for: Seed(hashing: "contact-sheet-\(index)"), allowedSpecies: species)
            let sheet = PetSpriteComposer.spriteSheet(for: genome, adornment: PetAdornment(wearsStackCollar: index % 7 == 3))
            let origin = CGPoint(x: (index % columns) * cellWidth + scale, y: (index / columns) * cellHeight + scale)
            canvas.drawPixels(sheet.frame(for: pose), at: origin, scale: CGFloat(scale))
        }
        return canvas.makeImage()
    }

    /// Every pose for a handful of pets, one row each.
    static func renderPoses(seedCount: Int, scale: Int) -> CGImage {
        let poses = PetPose.allCases
        let cellWidth = (PetSpriteSheet.frameWidth + 2) * scale
        let cellHeight = (PetSpriteSheet.frameHeight + 2) * scale
        let canvas = PreviewCanvas(width: poses.count * cellWidth, height: seedCount * cellHeight, background: 0xf4efe6)
        for row in 0..<seedCount {
            let genome = GenomeFactory.genome(for: Seed(hashing: "poses-\(row)"))
            let sheet = PetSpriteComposer.spriteSheet(for: genome)
            for (column, pose) in poses.enumerated() {
                let origin = CGPoint(x: column * cellWidth + scale, y: row * cellHeight + scale)
                canvas.drawPixels(sheet.frame(for: pose), at: origin, scale: CGFloat(scale))
            }
        }
        return canvas.makeImage()
    }
}

/// The doghouse in each colour style, side by side.
enum DoghouseSheet {
    static let colours = [
        DoghouseColour.default,
        DoghouseColour(style: .solid, primary: 0x2f6fd0),
        DoghouseColour(style: .ombre, primary: 0xf2c33a, secondary: 0xd8333a),
        DoghouseColour(style: .ombre, primary: 0x2255cc, secondary: 0x8be0ff),
        DoghouseColour(style: .rainbow),
    ]

    static func render(scale: Int) -> CGImage {
        let cellWidth = (DoghouseArt.width + 2) * scale
        let cellHeight = (DoghouseArt.height + 2) * scale
        let canvas = PreviewCanvas(width: colours.count * cellWidth, height: cellHeight, background: 0xf4efe6)
        for (column, colour) in colours.enumerated() {
            let origin = CGPoint(x: column * cellWidth + scale, y: scale)
            canvas.drawPixels(DoghouseArt.image(painted: colour), at: origin, scale: CGFloat(scale))
        }
        return canvas.makeImage()
    }
}
