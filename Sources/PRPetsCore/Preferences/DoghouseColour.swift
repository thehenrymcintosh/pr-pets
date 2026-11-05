import Foundation

/// What colour the doghouse is painted. Colours are stored as `0xRRGGBB` so Core needs no UI framework.
public struct DoghouseColour: Hashable, Codable, Sendable {
    public enum Style: String, CaseIterable, Hashable, Codable, Sendable {
        /// One colour, `primary`.
        case solid
        /// A gradient from `primary` at the roof down to `secondary` at the ground.
        case ombre
        /// Every colour of the rainbow from the roof down to the ground; the chosen colours are ignored.
        case rainbow
    }

    public var style: Style
    public var primary: UInt32
    /// Kept even while the style is solid, so switching to ombre and back doesn't lose the pick.
    public var secondary: UInt32

    public static let originalRed: UInt32 = 0xd8333a
    public static let defaultSecondary: UInt32 = 0xf2a33a

    public init(style: Style = .solid, primary: UInt32 = originalRed, secondary: UInt32 = defaultSecondary) {
        self.style = style
        self.primary = primary & 0xffffff
        self.secondary = secondary & 0xffffff
    }

    public static let `default` = DoghouseColour()

    /// Gradients are sampled by height so the art can paint them row by row; 0 is the top of the roof, 1 the ground.
    public func hex(atFraction fraction: Double) -> UInt32 {
        let t = min(max(fraction, 0), 1)
        switch style {
        case .solid:
            return primary
        case .ombre:
            return Self.blend(primary, secondary, by: t)
        case .rainbow:
            // Red to violet, stopping short of wrapping back round to red.
            return Self.hex(hue: t * Self.rainbowHueSpan)
        }
    }

    private static let rainbowHueSpan = 0.78

    private static func blend(_ from: UInt32, _ to: UInt32, by t: Double) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            let a = Double((from >> shift) & 0xff)
            let b = Double((to >> shift) & 0xff)
            return UInt32((a + (b - a) * t).rounded()) << shift
        }
        return channel(16) | channel(8) | channel(0)
    }

    private static func hex(hue: Double) -> UInt32 {
        let saturation = 0.78, brightness = 0.88
        let sector = hue * 6
        let index = Int(sector) % 6
        let fraction = sector - Double(Int(sector))
        let p = brightness * (1 - saturation)
        let q = brightness * (1 - saturation * fraction)
        let t = brightness * (1 - saturation * (1 - fraction))
        let (r, g, b): (Double, Double, Double) = switch index {
        case 0: (brightness, t, p)
        case 1: (q, brightness, p)
        case 2: (p, brightness, t)
        case 3: (p, q, brightness)
        case 4: (t, p, brightness)
        default: (brightness, p, q)
        }
        func byte(_ value: Double) -> UInt32 { UInt32((value * 255).rounded()) }
        return byte(r) << 16 | byte(g) << 8 | byte(b)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = DoghouseColour()
        self.init(
            style: (try? container.decodeIfPresent(Style.self, forKey: .style)) ?? defaults.style,
            primary: (try? container.decodeIfPresent(UInt32.self, forKey: .primary)) ?? defaults.primary,
            secondary: (try? container.decodeIfPresent(UInt32.self, forKey: .secondary)) ?? defaults.secondary
        )
    }
}
