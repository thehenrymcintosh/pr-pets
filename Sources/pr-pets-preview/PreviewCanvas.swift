import CoreGraphics
import Foundation
import ImageIO
import PRPetsArt
import PRPetsRender
import UniformTypeIdentifiers

/// A top-left-origin bitmap context for headless previews.
final class PreviewCanvas {
    let context: CGContext
    let width: Int
    let height: Int

    init(width: Int, height: Int, background: UInt32?) {
        self.width = width
        self.height = height
        context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.interpolationQuality = .none
        if let background {
            let colour = RGBA(hex: background)
            context.setFillColor(red: CGFloat(colour.red) / 255, green: CGFloat(colour.green) / 255, blue: CGFloat(colour.blue) / 255, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    func drawPixels(_ image: PixelImage, at origin: CGPoint, scale: CGFloat) {
        guard let cgImage = image.cgImage else { return }
        let rect = CGRect(x: origin.x, y: origin.y, width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        // CGContext.draw assumes a bottom-left origin; flip locally so the sprite is upright.
        context.saveGState()
        context.translateBy(x: 0, y: rect.maxY + rect.minY)
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: rect)
        context.restoreGState()
    }

    func makeImage() -> CGImage { context.makeImage()! }
}

enum ImageWriter {
    static func writePNG(_ image: CGImage, to url: URL) throws {
        try write([image], to: url, type: .png, frameDelay: 0)
    }

    static func writeGIF(_ frames: [CGImage], to url: URL, frameDelay: Double) throws {
        try write(frames, to: url, type: .gif, frameDelay: frameDelay)
    }

    private static func write(_ frames: [CGImage], to url: URL, type: UTType, frameDelay: Double) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, frames.count, nil) else {
            throw PreviewError.cannotWrite(url)
        }
        if type == .gif {
            let loop = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
            CGImageDestinationSetProperties(destination, loop as CFDictionary)
        }
        let frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFUnclampedDelayTime: frameDelay]]
        for frame in frames {
            CGImageDestinationAddImage(destination, frame, type == .gif ? frameProperties as CFDictionary : nil)
        }
        guard CGImageDestinationFinalize(destination) else { throw PreviewError.cannotWrite(url) }
    }
}

enum PreviewError: Error, CustomStringConvertible {
    case cannotWrite(URL)
    case unknownCommand(String)

    var description: String {
        switch self {
        case .cannotWrite(let url): "Could not write \(url.path)"
        case .unknownCommand(let command): "Unknown command '\(command)'. Try: all, sheet, scenarios, scenario <name> <dir>, icon <dir>"
        }
    }
}

/// Evenly spaced frames from an animation stacked top to bottom, for reviewing motion as a still.
enum Filmstrip {
    static func make(from frames: [CGImage], count: Int) -> CGImage {
        let picked = (0..<count).map { frames[min(frames.count - 1, $0 * frames.count / count)] }
        let width = picked[0].width
        let height = picked[0].height
        let canvas = PreviewCanvas(width: width, height: height * count + (count - 1) * 4, background: 0x222222)
        for (index, frame) in picked.enumerated() {
            let rect = CGRect(x: 0, y: index * (height + 4), width: width, height: height)
            canvas.context.saveGState()
            canvas.context.translateBy(x: 0, y: rect.minY + rect.maxY)
            canvas.context.scaleBy(x: 1, y: -1)
            canvas.context.draw(frame, in: rect)
            canvas.context.restoreGState()
        }
        return canvas.makeImage()
    }
}
