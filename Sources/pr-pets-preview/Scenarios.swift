import CoreGraphics
import Foundation
import PRPetsArt
import PRPetsCore
import PRPetsDemo
import PRPetsRender

/// Scripted stories rendered to GIFs through exactly the same pipeline the app uses.
struct Scenario {
    enum Step {
        /// Load the demo script's snapshot at this many seconds into its story.
        case demoTime(TimeInterval)
        case mute(number: Int)
        case setPetsInside(Bool)
        case hover(number: Int?)
        case run(seconds: Double)
    }

    let name: String
    let steps: [Step]
    /// Simulated seconds skipped before recording starts, so pets are already out.
    var warmUp: Double = 0
    var roamingArea: RoamingArea = .nearDoghouse

    static let all: [Scenario] = [
        Scenario(name: "arrivals", steps: [.demoTime(70), .run(seconds: 7)]),
        Scenario(name: "life", steps: [.demoTime(70), .run(seconds: 24)], warmUp: 8),
        Scenario(name: "handled", steps: [
            .demoTime(20), .run(seconds: 3), .demoTime(40), .run(seconds: 3), .mute(number: 301), .run(seconds: 4),
        ], warmUp: 8),
        Scenario(name: "kennel", steps: [
            .demoTime(70), .run(seconds: 2), .setPetsInside(true), .run(seconds: 4), .setPetsInside(false), .run(seconds: 6),
        ], warmUp: 8),
        Scenario(name: "hover", steps: [.demoTime(70), .run(seconds: 1), .hover(number: 213), .run(seconds: 3)], warmUp: 10),
        Scenario(name: "screen-width", steps: [.demoTime(70), .run(seconds: 16)], warmUp: 3, roamingArea: .screenWidth),
    ]
}

struct ScenarioRecorder {
    static let viewSize = CGSize(width: 720, height: YardViewport.requiredHeight(scale: 3))
    static let simulationStep = 1.0 / 30
    static let framesPerCapture = 3

    let scenario: Scenario

    func record() -> [CGImage] {
        var preferences = Preferences()
        preferences.roamingArea = scenario.roamingArea
        preferences.roamingWidth = 600
        var ledger = TriageLedger()
        var identities = PetIdentityRegistry()
        var snapshot = DemoScript.snapshot(at: 0)
        var hoveredNumber: Int?
        let viewport = YardViewport(
            scale: 3, viewSize: Self.viewSize, doghouseCentreX: Self.viewSize.width * 0.62,
            roamingArea: preferences.roamingArea, roamingWidth: CGFloat(preferences.roamingWidth)
        )
        var yard = Yard(geometry: viewport.geometry)
        var random = SeededRandom(seed: Seed(hashing: scenario.name))
        let sprites = SpriteCache()
        let renderer = YardRenderer(sprites: sprites)
        var frames: [CGImage] = []

        func board() -> ReviewBoard {
            ReviewBoard(snapshot: snapshot, ledger: ledger, identities: identities, preferences: preferences)
        }
        func pullRequest(number: Int) -> PullRequest? {
            snapshot.pullRequests.first { $0.number == number }
        }
        func simulate(seconds: Double, capturing: Bool) {
            for step in 0..<Int(seconds / Self.simulationStep) {
                yard.advance(by: Self.simulationStep, using: &random)
                guard capturing, step % Self.framesPerCapture == 0 else { continue }
                let card = hoveredNumber.flatMap(pullRequest(number:)).map {
                    HoverCard(petID: $0.id, title: $0.title, reference: $0.shortReference, lineDelta: $0.lineDelta)
                }
                let currentBoard = board()
                let scene = YardScene(
                    viewport: viewport, yard: yard,
                    doghouse: DoghouseStatus(waitingCount: currentBoard.waitingPetCount, petsAreInside: preferences.petsAreInside),
                    hoverCard: card
                )
                let canvas = PreviewCanvas(width: Int(Self.viewSize.width), height: Int(Self.viewSize.height), background: nil)
                DesktopBackdrop.draw(in: canvas)
                renderer.draw(scene, in: canvas.context)
                frames.append(canvas.makeImage())
            }
        }
        func apply(_ step: Scenario.Step, capturing: Bool) {
            switch step {
            case .demoTime(let time):
                snapshot = DemoScript.snapshot(at: time)
                identities = ReviewBoard.identities(identities, updatedFor: snapshot)
            case .mute(let number):
                if let target = pullRequest(number: number) { ledger = ledger.muting(target, at: snapshot.fetchedAt) }
            case .setPetsInside(let inside):
                preferences.petsAreInside = inside
            case .hover(let number):
                hoveredNumber.flatMap(pullRequest(number:)).map { yard.release($0.id) }
                hoveredNumber = number
                number.flatMap(pullRequest(number:)).map { yard.hold($0.id) }
            case .run(let seconds):
                simulate(seconds: seconds, capturing: capturing)
            }
            yard.reconcile(with: board().roster)
        }

        if scenario.warmUp > 0 {
            scenario.steps.prefix { if case .run = $0 { false } else { true } }.forEach { apply($0, capturing: false) }
            simulate(seconds: scenario.warmUp, capturing: false)
        }
        let recordedSteps = scenario.warmUp > 0 ? Array(scenario.steps.drop { if case .run = $0 { false } else { true } }) : scenario.steps
        recordedSteps.forEach { apply($0, capturing: true) }
        return frames
    }
}

/// A soft wallpaper-like gradient so the transparent overlay can be judged against something.
enum DesktopBackdrop {
    static func draw(in canvas: PreviewCanvas) {
        let colours = [CGColor(srgbRed: 0.55, green: 0.66, blue: 0.86, alpha: 1), CGColor(srgbRed: 0.86, green: 0.78, blue: 0.86, alpha: 1)] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colours, locations: [0, 1])!
        canvas.context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: canvas.height), options: [])
    }
}
