import Foundation

/// The decisions that make pets feel alive: where to go next, what to do when they get there,
/// how fast they move. Kept apart from the mechanics of moving in `Yard`.
public enum PetBehaviour {
    /// Pets closer than this (art pixels) feel crowded and prefer to move on.
    static let personalSpace: Double = 14
    static let candidateSpotCount = 10
    static let shortestWorthwhileWalk: Double = 6

    public static func walkingSpeed(of pet: YardPet) -> Double {
        9 + 9 * pet.genome.temperament.energy
    }

    public static func speed(for pet: YardPet) -> Double {
        switch pet.activity {
        case .returningHome: 42
        case .emerging: 30
        case .zooming: 34 + 10 * pet.genome.temperament.energy
        default: walkingSpeed(of: pet)
        }
    }

    /// What a pet does once it finishes its current activity.
    static func nextActivity(
        for pet: YardPet,
        in yard: Yard,
        using random: inout some RandomNumberGenerator
    ) -> PetActivity {
        let temperament = pet.genome.temperament
        let isCrowded = isCrowded(pet, in: yard)
        let restWeightScale = isCrowded ? 0.15 : 1
        let justArrived: Bool = { if case .emerging = pet.activity { return true } else { return false } }()
        let napWeight = justArrived ? 0 : (0.3 + 1.6 * temperament.sleepiness) * restWeightScale
        let choice = random.weightedPick([
            (Choice.walk, 2.5 + 2 * temperament.energy + (isCrowded ? 4 : 0)),
            (Choice.idle, 3 * restWeightScale),
            (Choice.sit, 2 * restWeightScale),
            (Choice.nap, napWeight),
            (Choice.zoom, 0.25 + 0.9 * temperament.energy),
        ])
        let now = yard.clock
        switch choice {
        case .walk:
            return .walking(destination: destination(for: pet, in: yard, range: roamingRange(for: pet), using: &random))
        case .zoom:
            return .zooming(destination: destination(for: pet, in: yard, range: roamingRange(for: pet) * 1.6, using: &random))
        case .idle:
            return .idling(until: now + Double.random(in: 1.5...5, using: &random))
        case .sit:
            return .sitting(until: now + Double.random(in: 4...12, using: &random))
        case .nap:
            return .napping(until: now + Double.random(in: 15...40, using: &random) * (0.6 + temperament.sleepiness))
        }
    }

    /// After a user lets go of a pet it lingers for a moment before carrying on.
    static func activityAfterAttention(at clock: Double) -> PetActivity {
        .idling(until: clock + 1.2)
    }

    /// Picks a spot that keeps pets apart: sample candidates, prefer the one furthest from everyone else.
    static func destination(
        for pet: YardPet,
        in yard: Yard,
        range: Double,
        using random: inout some RandomNumberGenerator
    ) -> YardPoint {
        let geometry = yard.geometry
        let otherPetSpots = yard.pets.filter { $0.id != pet.id }.flatMap { other in
            [other.position, other.activity.destination].compactMap { $0 }
        }
        let candidates = (0..<candidateSpotCount).map { _ in
            candidateSpot(near: pet.position, range: range, in: geometry, using: &random)
        }
        func clearance(of spot: YardPoint) -> Double {
            otherPetSpots.map { $0.spacing(to: spot) }.min() ?? .infinity
        }
        let scored = candidates.map { spot in
            (spot: spot, score: min(clearance(of: spot), personalSpace * 4) + Double.random(in: 0...6, using: &random))
        }
        return scored.max { $0.score < $1.score }?.spot ?? pet.position
    }

    static func isCrowded(_ pet: YardPet, in yard: Yard) -> Bool {
        yard.pets.contains { other in
            other.id != pet.id && other.activity != .returningHome
                && other.position.spacing(to: pet.position) < personalSpace
        }
    }

    private enum Choice { case walk, idle, sit, nap, zoom }

    private static func roamingRange(for pet: YardPet) -> Double {
        25 + 110 * pet.genome.temperament.curiosity
    }

    private static func candidateSpot(
        near origin: YardPoint,
        range: Double,
        in geometry: YardGeometry,
        using random: inout some RandomNumberGenerator
    ) -> YardPoint {
        let span = geometry.roamingSpan
        let reachable = max(span.lowerBound, origin.x - range)...min(span.upperBound, origin.x + range)
        let offset = Double.random(in: shortestWorthwhileWalk...max(shortestWorthwhileWalk + 1, range), using: &random)
        let direction: Double = random.chance(0.5) ? -1 : 1
        let preferredX = origin.x + direction * offset
        let x = reachable.contains(preferredX) ? preferredX : origin.x - direction * offset
        return geometry.clamped(YardPoint(x: x, depth: Double.random(in: geometry.depthSpan, using: &random)))
    }
}
