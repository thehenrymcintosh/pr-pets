import CoreGraphics
import PRPetsCore

/// Places name tags so they never overlap. Each tag sits above its pet; one that would collide with a
/// tag already placed steps up a row, and if every row is taken it's left out until there's room.
/// Tags are placed in a stable priority order, so they don't swap rows as pets walk past each other.
public enum NameTagLayout {
    public struct Request: Hashable, Sendable {
        public let id: PullRequestID
        public let size: CGSize
        /// Top-centre of the pet's body; the tag's bottom-centre goes just above it.
        public let anchor: CGPoint

        public init(id: PullRequestID, size: CGSize, anchor: CGPoint) {
            self.id = id
            self.size = size
            self.anchor = anchor
        }
    }

    public static let maximumRows = 3
    /// Points between a pet and its tag, and between stacked tags.
    static let spacing: CGFloat = 2

    /// `requests` in priority order, highest first; `obstacles` are areas tags must keep off, like the
    /// doghouse badge. Returns a frame for every tag that fits.
    public static func arrange(_ requests: [Request], withinWidth width: CGFloat, avoiding obstacles: [CGRect] = []) -> [PullRequestID: CGRect] {
        var placed: [PullRequestID: CGRect] = [:]
        for request in requests {
            let candidates = (0..<maximumRows).map { row in frame(for: request, row: row, withinWidth: width) }
            let taken = obstacles + placed.values
            placed[request.id] = candidates.first { candidate in !taken.contains { $0.intersects(candidate) } }
        }
        return placed
    }

    private static func frame(for request: Request, row: Int, withinWidth width: CGFloat) -> CGRect {
        let rowHeight = request.size.height + spacing
        let unclampedX = request.anchor.x - request.size.width / 2
        return CGRect(
            x: min(max(spacing, unclampedX), width - request.size.width - spacing),
            y: request.anchor.y - spacing - request.size.height - CGFloat(row) * rowHeight,
            width: request.size.width,
            height: request.size.height
        )
    }
}
