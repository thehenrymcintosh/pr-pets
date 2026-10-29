import AppKit
import PRPetsArt
import PRPetsCore
import PRPetsRender

/// A transparent, borderless panel floating above other windows on every Space.
final class OverlayPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        isMovable = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Where the overlay sits on screen for a placement and scale.
struct OverlayLayout: Equatable {
    let screen: NSScreen
    let panelFrame: CGRect
    let doghouseCentreX: CGFloat

    init(placement: DoghousePlacement, scale: Double) {
        let screen = NSScreen.screens.first { $0.displayID == placement.displayID } ?? NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        let height = YardViewport.requiredHeight(scale: scale)
        let travel = max(0, visible.height - height)
        self.screen = screen
        panelFrame = CGRect(
            x: visible.minX,
            y: visible.minY + travel * Preferences.unitRange.clamp(placement.verticalFraction),
            width: visible.width,
            height: height
        )
        let doghouseHalfWidth = CGFloat(DoghouseArt.width) * scale / 2
        doghouseCentreX = min(max(doghouseHalfWidth, visible.width * Preferences.unitRange.clamp(placement.horizontalFraction)), visible.width - doghouseHalfWidth)
    }

    /// The placement that would put the doghouse centre and the panel bottom at these screen coordinates.
    static func placement(doghouseCentre: CGPoint, panelBottom: CGFloat, scale: Double) -> DoghousePlacement {
        let screen = NSScreen.screens.first { $0.frame.contains(doghouseCentre) } ?? NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        let travel = max(1, visible.height - YardViewport.requiredHeight(scale: scale))
        return DoghousePlacement(
            displayID: screen.displayID,
            horizontalFraction: Preferences.unitRange.clamp((doghouseCentre.x - visible.minX) / visible.width),
            verticalFraction: Preferences.unitRange.clamp((panelBottom - visible.minY) / travel)
        )
    }

    static func == (lhs: OverlayLayout, rhs: OverlayLayout) -> Bool {
        lhs.screen == rhs.screen && lhs.panelFrame == rhs.panelFrame && lhs.doghouseCentreX == rhs.doghouseCentreX
    }
}

extension Preferences {
    static let unitRange: ClosedRange<Double> = 0...1
}

extension NSScreen {
    var displayID: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
