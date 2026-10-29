import Foundation

/// What a pet is doing. Timed activities end at an absolute yard-clock time (seconds).
public enum PetActivity: Hashable, Sendable {
    /// Running out of the doghouse to its first spot.
    case emerging(destination: YardPoint)
    case walking(destination: YardPoint)
    /// A short burst of running for the fun of it.
    case zooming(destination: YardPoint)
    case idling(until: Double)
    case sitting(until: Double)
    case napping(until: Double)
    /// Sitting still and looking at the user, who is hovering or has its card open.
    case attending
    /// Jumps and freezes for a beat on being called home, so the user notices it leaving.
    case startled(until: Double)
    /// Running back into the doghouse; the pet leaves the yard when it gets there.
    case returningHome

    public var destination: YardPoint? {
        switch self {
        case .emerging(let destination), .walking(let destination), .zooming(let destination): destination
        default: nil
        }
    }

    public var endsAt: Double? {
        switch self {
        case .idling(let until), .sitting(let until), .napping(let until): until
        default: nil
        }
    }

    public var isRunning: Bool {
        switch self {
        case .emerging, .zooming, .returningHome: true
        default: false
        }
    }

    /// Startled or already running home: the pet is leaving.
    public var isHeadingHome: Bool {
        switch self {
        case .startled, .returningHome: true
        default: false
        }
    }

    public var isResting: Bool {
        switch self {
        case .idling, .sitting, .napping, .attending: true
        default: false
        }
    }
}

/// Every drawable pose. Art produces one frame per pose.
public enum PetPose: String, CaseIterable, Hashable, Sendable {
    case stand, standBlink
    case walk1, walk2, walk3, walk4
    case run1, run2
    case sit, sitBlink
    case sleep1, sleep2
    /// Mid-jump with surprise.
    case startle
}

public struct YardPet: Identifiable, Hashable, Sendable {
    public let id: PullRequestID
    public internal(set) var entry: PetRosterEntry
    public internal(set) var position: YardPoint
    public internal(set) var facing: Facing
    public internal(set) var activity: PetActivity
    public internal(set) var activityStartedAt: Double
    /// Total distance walked, in art pixels. Drives the walk cycle so feet don't slide.
    public internal(set) var odometer: Double

    public var genome: PetGenome { entry.genome }

    /// 0..<1, fixed per pet. Offsets blinks, breathing and startles so pets don't move in lockstep.
    var individuality: Double {
        Double(Seed(hashing: id.rawValue).rawValue % 1000) / 1000
    }

    private var animationPhase: Double { individuality * 10 }

    public func pose(at clock: Double) -> PetPose {
        let localTime = clock + animationPhase
        let isBlinking = localTime.truncatingRemainder(dividingBy: 3.7) < 0.15
        switch activity {
        case .startled:
            // A quick hop, then frozen wide-eyed until it bolts.
            return clock - activityStartedAt < PetBehaviour.startleHopDuration ? .startle : .stand
        case .emerging, .zooming, .returningHome:
            return Int(odometer / 3).isMultiple(of: 2) ? .run1 : .run2
        case .walking:
            return [.walk1, .walk2, .walk3, .walk4][Int(odometer / 2.5) % 4]
        case .idling:
            return isBlinking ? .standBlink : .stand
        case .sitting, .attending:
            return isBlinking ? .sitBlink : .sit
        case .napping:
            return Int(localTime / 1.4).isMultiple(of: 2) ? .sleep1 : .sleep2
        }
    }

    /// Fades in as it leaves the door and out as it gets back to it.
    public func opacity(at clock: Double, door: YardPoint) -> Double {
        switch activity {
        case .emerging:
            return min(1, (clock - activityStartedAt) / 0.35)
        case .returningHome:
            return min(1, position.spacing(to: door) / 5)
        default:
            return 1
        }
    }

    public var isStartled: Bool {
        if case .startled = activity { return true }
        return false
    }

    public var isAsleep: Bool {
        if case .napping = activity { return true }
        return false
    }
}
