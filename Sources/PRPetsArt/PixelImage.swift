import Foundation

public struct RGBA: Hashable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8
    public let alpha: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// `0xRRGGBB`
    public init(hex: UInt32) {
        self.init(red: UInt8((hex >> 16) & 0xff), green: UInt8((hex >> 8) & 0xff), blue: UInt8(hex & 0xff))
    }

    public static let clear = RGBA(red: 0, green: 0, blue: 0, alpha: 0)

    /// Moves towards black (negative amount) or white (positive amount), -1...1.
    public func lightened(by amount: Double) -> RGBA {
        let target: Double = amount >= 0 ? 255 : 0
        let weight = min(abs(amount), 1)
        func mix(_ channel: UInt8) -> UInt8 {
            UInt8((Double(channel) + (target - Double(channel)) * weight).rounded())
        }
        return RGBA(red: mix(red), green: mix(green), blue: mix(blue), alpha: alpha)
    }

    public func mixed(with other: RGBA, by weight: Double) -> RGBA {
        func mix(_ lhs: UInt8, _ rhs: UInt8) -> UInt8 {
            UInt8((Double(lhs) + (Double(rhs) - Double(lhs)) * weight).rounded())
        }
        return RGBA(red: mix(red, other.red), green: mix(green, other.green), blue: mix(blue, other.blue), alpha: alpha)
    }
}

/// A small straight-alpha RGBA bitmap, row-major from the top-left.
public struct PixelImage: Hashable, Sendable {
    public let width: Int
    public let height: Int
    public private(set) var pixels: [RGBA]

    public init(width: Int, height: Int, fill: RGBA = .clear) {
        self.width = width
        self.height = height
        self.pixels = Array(repeating: fill, count: width * height)
    }

    public subscript(x: Int, y: Int) -> RGBA {
        get { contains(x: x, y: y) ? pixels[y * width + x] : .clear }
        set { if contains(x: x, y: y) { pixels[y * width + x] = newValue } }
    }

    public func contains(x: Int, y: Int) -> Bool {
        x >= 0 && y >= 0 && x < width && y < height
    }

    public func isOpaque(x: Int, y: Int) -> Bool { self[x, y].alpha > 0 }

    public func mirroredHorizontally() -> PixelImage {
        var mirrored = PixelImage(width: width, height: height)
        for y in 0..<height {
            for x in 0..<width {
                mirrored[width - 1 - x, y] = self[x, y]
            }
        }
        return mirrored
    }

    /// Bounding box of opaque pixels, or nil if the image is empty.
    public var opaqueBounds: (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        let opaque = (0..<height).flatMap { y in (0..<width).filter { isOpaque(x: $0, y: y) }.map { (x: $0, y: y) } }
        guard !opaque.isEmpty else { return nil }
        return (opaque.map(\.x).min()!, opaque.map(\.y).min()!, opaque.map(\.x).max()!, opaque.map(\.y).max()!)
    }

    /// Premultiplied RGBA bytes, the layout CoreGraphics wants.
    public var premultipliedBytes: [UInt8] {
        pixels.flatMap { pixel -> [UInt8] in
            let alpha = Double(pixel.alpha) / 255
            return [
                UInt8((Double(pixel.red) * alpha).rounded()),
                UInt8((Double(pixel.green) * alpha).rounded()),
                UInt8((Double(pixel.blue) * alpha).rounded()),
                pixel.alpha,
            ]
        }
    }
}
