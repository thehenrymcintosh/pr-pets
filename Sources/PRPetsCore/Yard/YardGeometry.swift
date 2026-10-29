import Foundation

/// A spot on the ground. Units are art pixels (one pixel of the sprite before scaling).
/// `depth` grows towards the viewer: pets with greater depth are drawn lower and in front.
public struct YardPoint: Hashable, Codable, Sendable {
    public var x: Double
    public var depth: Double

    public init(x: Double, depth: Double) {
        self.x = x
        self.depth = depth
    }

    /// Distance with depth exaggerated: pets one depth unit apart look further apart than one unit sideways.
    public func spacing(to other: YardPoint) -> Double {
        let horizontal = x - other.x
        let vertical = (depth - other.depth) * 3
        return (horizontal * horizontal + vertical * vertical).squareRoot()
    }
}

public enum Facing: String, Hashable, Codable, Sendable {
    case left, right
}

/// The invisible patch of ground the pets live on.
public struct YardGeometry: Hashable, Codable, Sendable {
    public var roamingSpan: ClosedRange<Double>
    public var depthSpan: ClosedRange<Double>
    /// Where pets come out of and go back into the doghouse.
    public var door: YardPoint

    public init(roamingSpan: ClosedRange<Double>, depthSpan: ClosedRange<Double> = 0...6, door: YardPoint) {
        self.roamingSpan = roamingSpan
        self.depthSpan = depthSpan
        self.door = door
    }

    public func clamped(_ point: YardPoint) -> YardPoint {
        YardPoint(
            x: min(max(point.x, roamingSpan.lowerBound), roamingSpan.upperBound),
            depth: min(max(point.depth, depthSpan.lowerBound), depthSpan.upperBound)
        )
    }
}
