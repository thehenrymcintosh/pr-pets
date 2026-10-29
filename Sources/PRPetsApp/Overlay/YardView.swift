import AppKit
import PRPetsRender

/// Mouse gestures on the overlay, already disambiguated.
@MainActor
protocol YardViewDelegate: AnyObject {
    func yardView(_ view: YardView, clicked hit: SceneHit)
    func yardViewDoubleClickedDoghouse(_ view: YardView)
    func yardView(_ view: YardView, rightClicked hit: SceneHit, with event: NSEvent)
    func yardView(_ view: YardView, draggedDoghouseBy delta: CGSize)
    func yardViewFinishedDraggingDoghouse(_ view: YardView)
    func yardView(_ view: YardView, hitAt point: CGPoint) -> SceneHit?
}

/// Draws the current scene and turns raw mouse events into gestures.
final class YardView: NSView {
    weak var delegate: YardViewDelegate?
    var scene: YardScene? { didSet { needsDisplay = true } }
    let sprites = SpriteCache()
    private lazy var renderer = YardRenderer(sprites: sprites)

    private var pressedHit: SceneHit?
    private var pressLocationInScreen: CGPoint?
    private var isDraggingDoghouse = false
    private var pendingSingleClick: DispatchWorkItem?
    /// Movement (points) before a press on the doghouse becomes a drag.
    private static let dragThreshold: CGFloat = 4

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let scene, let context = NSGraphicsContext.current?.cgContext else { return }
        renderer.draw(scene, in: context)
    }

    override func mouseDown(with event: NSEvent) {
        pressedHit = delegate?.yardView(self, hitAt: convert(event.locationInWindow, from: nil))
        pressLocationInScreen = NSEvent.mouseLocation
        isDraggingDoghouse = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard pressedHit == .doghouse, let start = pressLocationInScreen else { return }
        let now = NSEvent.mouseLocation
        let delta = CGSize(width: now.x - start.x, height: now.y - start.y)
        if !isDraggingDoghouse, hypot(delta.width, delta.height) < Self.dragThreshold { return }
        isDraggingDoghouse = true
        pressLocationInScreen = now
        NSCursor.closedHand.set()
        delegate?.yardView(self, draggedDoghouseBy: delta)
    }

    override func mouseUp(with event: NSEvent) {
        defer { pressedHit = nil; pressLocationInScreen = nil }
        if isDraggingDoghouse {
            isDraggingDoghouse = false
            NSCursor.arrow.set()
            delegate?.yardViewFinishedDraggingDoghouse(self)
            return
        }
        guard let hit = pressedHit else { return }
        switch hit {
        case .doghouse where event.clickCount >= 2:
            pendingSingleClick?.cancel()
            delegate?.yardViewDoubleClickedDoghouse(self)
        case .doghouse:
            // Wait to see whether this becomes a double click before opening the dashboard.
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.delegate?.yardView(self, clicked: .doghouse)
            }
            pendingSingleClick = work
            DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: work)
        case .pet:
            delegate?.yardView(self, clicked: hit)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let hit = delegate?.yardView(self, hitAt: convert(event.locationInWindow, from: nil)) else { return }
        delegate?.yardView(self, rightClicked: hit, with: event)
    }
}
