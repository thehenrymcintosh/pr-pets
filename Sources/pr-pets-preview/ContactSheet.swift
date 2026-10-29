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
