import PRPetsCore

/// Where each body part sits for one pose. Coordinates are in the sprite frame, y down, facing right.
struct PetSkeleton: Sendable {
    struct Leg: Sendable {
        let x: Int
        let top: Int
        let bottom: Int
        let isFarSide: Bool
    }

    enum Posture: Sendable { case standing, sitting, lying }

    let posture: Posture
    let body: (x: ClosedRange<Int>, y: ClosedRange<Int>)
    /// Top-left of the head box.
    let head: (x: Int, y: Int)
    let legs: [Leg]
    /// Where the tail joins the body.
    let tailRoot: (x: Int, y: Int)
    /// 0 or 1, alternates the tail's sway.
    let tailSway: Int
    let eyesClosed: Bool

    static let frameWidth = 30
    static let frameHeight = 24
    /// Lowest row a paw can touch. The outline sits one row below.
    static let groundRow = 22

    init(build: BodyBuild, pose: PetPose) {
        let (bodyX, bodyTop) = Self.bodyExtent(for: build)
        let ground = Self.groundRow
        let legLength = 2
        let standingBodyBottom = ground - legLength

        switch pose {
        case .stand, .standBlink, .walk1, .walk2, .walk3, .walk4, .run1, .run2, .startle:
            let gait = Self.gait(for: pose)
            let bodyBottom = standingBodyBottom - gait.lift
            let footRow = ground - gait.airborne
            posture = .standing
            body = (bodyX, (bodyTop - gait.lift)...bodyBottom)
            head = (bodyX.upperBound - 2, bodyTop - 6 - gait.lift)
            let backX = bodyX.lowerBound + 1
            let frontX = bodyX.upperBound - 1
            legs = [
                Leg(x: backX + 1 + gait.farBack, top: bodyBottom + 1, bottom: footRow, isFarSide: true),
                Leg(x: frontX + 1 + gait.farFront, top: bodyBottom + 1, bottom: footRow, isFarSide: true),
                Leg(x: backX + gait.nearBack, top: bodyBottom + 1, bottom: footRow, isFarSide: false),
                Leg(x: frontX + gait.nearFront, top: bodyBottom + 1, bottom: footRow, isFarSide: false),
            ]
            tailRoot = (bodyX.lowerBound, bodyTop - gait.lift + 1)
            tailSway = gait.tailSway
            eyesClosed = pose == .standBlink
        case .sit, .sitBlink:
            posture = .sitting
            let sitTop = bodyTop - 1
            body = ((bodyX.lowerBound + 2)...bodyX.upperBound, sitTop...ground)
            head = (bodyX.upperBound - 3, sitTop - 6)
            legs = [
                Leg(x: bodyX.upperBound, top: ground - 2, bottom: ground, isFarSide: true),
                Leg(x: bodyX.upperBound - 1, top: ground - 2, bottom: ground, isFarSide: false),
            ]
            tailRoot = (bodyX.lowerBound + 2, ground - 1)
            tailSway = 0
            eyesClosed = pose == .sitBlink
        case .sleep1, .sleep2:
            posture = .lying
            let breath = pose == .sleep2 ? 1 : 0
            let lyingTop = ground - 3 - (bodyTop < 16 ? 1 : 0) - breath
            body = ((bodyX.lowerBound - 1)...(bodyX.upperBound), lyingTop...ground)
            head = (bodyX.upperBound - 1, ground - 5)
            legs = [Leg(x: bodyX.upperBound + 4, top: ground, bottom: ground, isFarSide: false)]
            tailRoot = (bodyX.lowerBound - 1, ground - 1)
            tailSway = 0
            eyesClosed = true
        }
    }

    private static func bodyExtent(for build: BodyBuild) -> (x: ClosedRange<Int>, top: Int) {
        switch build {
        case .slim: (10...18, 17)
        case .regular: (10...18, 16)
        case .chonky: (9...19, 15)
        }
    }

    private struct Gait {
        var nearBack = 0, nearFront = 0, farBack = 0, farFront = 0
        var lift = 0
        var airborne = 0
        var tailSway = 0
    }

    private static func gait(for pose: PetPose) -> Gait {
        switch pose {
        case .walk1: Gait(nearBack: 1, nearFront: 1, farBack: -1, farFront: -1, tailSway: 1)
        case .walk2: Gait(lift: 1)
        case .walk3: Gait(nearBack: -1, nearFront: -1, farBack: 1, farFront: 1, tailSway: 1)
        case .walk4: Gait(lift: 1)
        case .run1: Gait(nearBack: -2, nearFront: 2, farBack: -1, farFront: 1, lift: 1, tailSway: 1)
        case .run2: Gait(nearBack: 1, nearFront: -1, farBack: 2, farFront: -2, lift: 2, airborne: 1)
        case .startle: Gait(nearBack: -1, nearFront: 1, lift: 2, airborne: 2, tailSway: 1)
        default: Gait()
        }
    }
}
