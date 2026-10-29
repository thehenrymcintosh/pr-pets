import CoreGraphics
import PRPetsArt
import PRPetsCore

/// Maps between the yard (art pixels) and the overlay view (points, top-left origin).
public struct YardViewport: Hashable, Sendable {
    /// Points per art pixel.
    public let scale: CGFloat
    public let viewSize: CGSize
    /// The doghouse's horizontal centre in view points.
    public let doghouseCentreX: CGFloat
    public let roamingArea: RoamingArea
    /// Width of the roaming strip in view points when roaming near the doghouse.
    public let roamingWidth: CGFloat

    /// Ground rows between the back of the yard and the front.
    public static let depthRows: Double = 6
    /// Pets with less depth than this walk behind the doghouse.
    public static let doghouseDepth: Double = 2
    /// Room above the doghouse for labels and the hover card, in points.
    public static let headroom: CGFloat = 120

    public init(scale: CGFloat, viewSize: CGSize, doghouseCentreX: CGFloat, roamingArea: RoamingArea, roamingWidth: CGFloat) {
        self.scale = scale
        self.viewSize = viewSize
        self.doghouseCentreX = doghouseCentreX
        self.roamingArea = roamingArea
        self.roamingWidth = roamingWidth
    }

    /// Height of overlay needed to fit the doghouse, the yard and the headroom above it.
    public static func requiredHeight(scale: CGFloat) -> CGFloat {
        CGFloat(DoghouseArt.height + Int(depthRows) + 2) * scale + headroom
    }

    /// The y (points) where pets at depth 0 stand.
    public var groundLineY: CGFloat {
        viewSize.height - CGFloat(Self.depthRows + 2) * scale
    }

    public var geometry: YardGeometry {
        let petHalfWidth = Double(PetSpriteSheet.frameWidth) / 2
        let viewWidthInArt = Double(viewSize.width / scale)
        let centre = Double(doghouseCentreX / scale)
        let span: ClosedRange<Double> = switch roamingArea {
        case .screenWidth:
            petHalfWidth...(viewWidthInArt - petHalfWidth)
        case .nearDoghouse:
            max(petHalfWidth, centre - Double(roamingWidth / scale) / 2)...min(viewWidthInArt - petHalfWidth, centre + Double(roamingWidth / scale) / 2)
        }
        return YardGeometry(
            roamingSpan: span.lowerBound <= span.upperBound ? span : centre...centre,
            depthSpan: 0...Self.depthRows,
            door: YardPoint(x: centre, depth: Self.doghouseDepth + 0.5)
        )
    }

    /// Where a pet's feet touch the ground, in view points.
    public func footPoint(of position: YardPoint) -> CGPoint {
        CGPoint(x: CGFloat(position.x) * scale, y: groundLineY + CGFloat(position.depth) * scale)
    }

    public var doghouseRect: CGRect {
        let size = CGSize(width: CGFloat(DoghouseArt.width) * scale, height: CGFloat(DoghouseArt.height) * scale)
        let bottom = groundLineY + CGFloat(Self.doghouseDepth) * scale
        return CGRect(x: doghouseCentreX - size.width / 2, y: bottom - size.height, width: size.width, height: size.height)
    }
}
