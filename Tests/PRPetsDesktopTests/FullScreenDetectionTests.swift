import CoreGraphics
import PRPetsDesktop
import Testing

private let laptop = CGRect(x: 0, y: 0, width: 1440, height: 900)
private let externalOnTheRight = CGRect(x: 1440, y: -200, width: 2560, height: 1440)
private let ownProcess: Int32 = 42

private func window(_ bounds: CGRect, layer: Int = 0, owner: Int32 = 7) -> WindowSnapshot {
    WindowSnapshot(ownerProcessID: owner, layer: layer, bounds: bounds)
}

@Suite("Full screen detection")
struct FullScreenDetectionTests {
    @Test func aFullScreenAppCountsButAMaximisedOneDoesnt() {
        let fullScreen = window(laptop)
        let maximised = window(CGRect(x: 0, y: 30, width: 1440, height: 870))
        #expect(FullScreenDetection.isFullScreen(display: laptop, windows: [fullScreen], ignoringProcess: ownProcess))
        #expect(!FullScreenDetection.isFullScreen(display: laptop, windows: [maximised], ignoringProcess: ownProcess))
    }

    @Test func systemChromeAndPRPetsItselfNeverCount() {
        let menuBarLayer = window(laptop, layer: 24)
        let ownOverlay = window(laptop, layer: 3, owner: ownProcess)
        #expect(!FullScreenDetection.isFullScreen(display: laptop, windows: [menuBarLayer, ownOverlay], ignoringProcess: ownProcess))
    }

    @Test func slideshowsAboveNormalWindowsCount() {
        #expect(FullScreenDetection.isFullScreen(display: laptop, windows: [window(laptop, layer: 8)], ignoringProcess: ownProcess))
    }

    @Test func onlyTheDisplayInQuestionMatters() {
        let fullScreenOnExternal = window(externalOnTheRight)
        #expect(FullScreenDetection.isFullScreen(display: externalOnTheRight, windows: [fullScreenOnExternal], ignoringProcess: ownProcess))
        #expect(!FullScreenDetection.isFullScreen(display: laptop, windows: [fullScreenOnExternal], ignoringProcess: ownProcess))
    }

    @Test func toleratesRetinaRounding() {
        let almost = window(CGRect(x: 0.5, y: 0, width: 1439.6, height: 900))
        #expect(FullScreenDetection.isFullScreen(display: laptop, windows: [almost], ignoringProcess: ownProcess))
    }
}
