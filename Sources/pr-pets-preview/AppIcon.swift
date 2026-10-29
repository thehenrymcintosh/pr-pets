import CoreGraphics
import Foundation
import PRPetsArt
import PRPetsCore
import PRPetsRender

/// The app icon: the doghouse with a cat out front, on a rounded sky tile.
enum AppIcon {
    static let iconsetSizes: [(name: String, pixels: Int)] = [
        ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
        ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
        ("icon_512x512", 512), ("icon_512x512@2x", 1024),
    ]

    static func writeIconset(to directory: URL) throws {
        for size in iconsetSizes {
            try ImageWriter.writePNG(render(pixels: size.pixels), to: directory.appending(path: "\(size.name).png"))
        }
    }

    static func render(pixels: Int) -> CGImage {
        let canvas = PreviewCanvas(width: pixels, height: pixels, background: nil)
        let size = CGFloat(pixels)
        let tile = CGRect(x: size * 0.1, y: size * 0.1, width: size * 0.8, height: size * 0.8)
        let context = canvas.context
        context.saveGState()
        context.addPath(CGPath(roundedRect: tile, cornerWidth: size * 0.18, cornerHeight: size * 0.18, transform: nil))
        context.clip()
        let colours = [CGColor(srgbRed: 0.62, green: 0.8, blue: 0.98, alpha: 1), CGColor(srgbRed: 0.98, green: 0.88, blue: 0.78, alpha: 1)] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colours, locations: [0, 1])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: tile.minY), end: CGPoint(x: 0, y: tile.maxY), options: [])
        context.setFillColor(CGColor(srgbRed: 0.55, green: 0.78, blue: 0.45, alpha: 1))
        context.fill(CGRect(x: tile.minX, y: tile.maxY - tile.height * 0.2, width: tile.width, height: tile.height * 0.2))
        context.restoreGState()

        // Art is 34 (doghouse) + 24 (cat) pixels wide; snap to whole pixels where the icon is big enough.
        let rawScale = tile.width * 0.92 / CGFloat(DoghouseArt.width + 18)
        let scale = rawScale >= 2 ? rawScale.rounded(.down) : rawScale
        let groundY = tile.maxY - tile.height * 0.12
        let doghouseOrigin = CGPoint(x: tile.minX + tile.width * 0.06, y: groundY - CGFloat(DoghouseArt.height) * scale)
        canvas.drawPixels(DoghouseArt.image, at: doghouseOrigin, scale: scale)
        let cat = PetSpriteComposer.spriteSheet(for: PetGenome(
            species: .cat, coat: .ginger, secondaryCoat: .white, pattern: .tabby, coatTint: 0,
            ears: .pointy, tail: .long, build: .regular, eyes: .green, accessory: nil,
            temperament: Temperament(energy: 0.5, sleepiness: 0.5, curiosity: 0.5)
        )).frame(for: .sit)
        let catOrigin = CGPoint(x: doghouseOrigin.x + CGFloat(DoghouseArt.width - 6) * scale, y: groundY - CGFloat(PetSpriteSheet.frameHeight) * scale)
        canvas.drawPixels(cat, at: catOrigin, scale: scale)
        return canvas.makeImage()
    }
}
