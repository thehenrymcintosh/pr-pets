import Foundation

/// The pet simulation. Deterministic given the same roster changes, time steps and random source,
/// so it can be replayed in tests and rendered headlessly.
public struct Yard: Sendable {
    /// Seconds between pets coming out of the doghouse, so they don't all pile out at once.
    static let arrivalInterval: Double = 0.7

    public private(set) var clock: Double = 0
    public private(set) var pets: [YardPet] = []
    public private(set) var geometry: YardGeometry
    private var pendingArrivals: [PetRosterEntry] = []
    private var nextArrivalAt: Double = 0
    private var heldPetIDs: Set<PullRequestID> = []

    public init(geometry: YardGeometry) {
        self.geometry = geometry
    }

    public var isEmpty: Bool { pets.isEmpty && pendingArrivals.isEmpty }

    public func pet(withID id: PullRequestID) -> YardPet? {
        pets.first { $0.id == id }
    }

    /// Pets back-to-front, the order they should be drawn in.
    public var petsInDrawingOrder: [YardPet] {
        pets.sorted { ($0.position.depth, $0.id.rawValue) < ($1.position.depth, $1.id.rawValue) }
    }

    // MARK: - Commands

    /// Moves the yard towards the roster: newcomers queue up at the door, missing pets startle and run home,
    /// pets that were heading home but are wanted again turn around.
    public mutating func reconcile(with roster: PetRoster) {
        let wantedByID = Dictionary(uniqueKeysWithValues: roster.entries.map { ($0.id, $0) })
        pets = pets.map { pet in
            guard let wantedEntry = wantedByID[pet.id] else { return sendingHome(pet) }
            return updating(pet, to: wantedEntry)
        }
        let presentIDs = Set(pets.map(\.id))
        let stillPending = pendingArrivals.filter { wantedByID[$0.id] != nil }
        let pendingIDs = Set(stillPending.map(\.id))
        let newcomers = roster.entries.filter { !presentIDs.contains($0.id) && !pendingIDs.contains($0.id) }
        pendingArrivals = stillPending + newcomers
    }

    /// Holding a pet makes it sit and look at the user until released.
    public mutating func hold(_ id: PullRequestID) {
        heldPetIDs.insert(id)
        pets = pets.map { pet in
            guard pet.id == id, !pet.activity.isHeadingHome else { return pet }
            return starting(.attending, for: pet)
        }
    }

    public mutating func release(_ id: PullRequestID) {
        heldPetIDs.remove(id)
        pets = pets.map { pet in
            guard pet.id == id, pet.activity == .attending else { return pet }
            return starting(PetBehaviour.activityAfterAttention(at: clock), for: pet)
        }
    }

    /// Moves the doghouse or resizes the yard; pets are kept inside the new bounds.
    public mutating func relocate(to newGeometry: YardGeometry) {
        let shift = newGeometry.door.x - geometry.door.x
        geometry = newGeometry
        pets = pets.map { pet in
            var moved = pet
            moved.position = newGeometry.clamped(YardPoint(x: pet.position.x + shift, depth: pet.position.depth))
            if let destination = pet.activity.destination, pet.activity != .returningHome {
                let shiftedDestination = newGeometry.clamped(YardPoint(x: destination.x + shift, depth: destination.depth))
                moved.activity = Self.retargeted(pet.activity, to: shiftedDestination)
            }
            return moved
        }
    }

    // MARK: - Simulation

    public mutating func advance(by seconds: Double, using random: inout some RandomNumberGenerator) {
        clock += seconds
        releaseNextArrival(using: &random)
        var updated: [YardPet] = []
        for pet in pets {
            let stepped = step(pet, by: seconds, using: &random)
            if let stepped { updated.append(stepped) }
        }
        pets = updated
    }

    private mutating func releaseNextArrival(using random: inout some RandomNumberGenerator) {
        guard clock >= nextArrivalAt, !pendingArrivals.isEmpty else { return }
        let entry = pendingArrivals.removeFirst()
        let newborn = YardPet(
            id: entry.id,
            entry: entry,
            position: geometry.door,
            facing: random.chance(0.5) ? .left : .right,
            activity: .idling(until: clock),
            activityStartedAt: clock,
            odometer: 0
        )
        let destination = PetBehaviour.destination(for: newborn, in: self, range: 70, using: &random)
        pets.append(starting(.emerging(destination: destination), for: newborn))
        nextArrivalAt = clock + Self.arrivalInterval
    }

    /// Returns nil when the pet has made it back inside.
    private func step(_ pet: YardPet, by seconds: Double, using random: inout some RandomNumberGenerator) -> YardPet? {
        if case .startled(let until) = pet.activity {
            return clock >= until ? starting(.returningHome, for: pet) : pet
        }
        if pet.activity == .returningHome {
            let walked = moving(pet, towards: geometry.door, by: seconds)
            return walked.position == geometry.door ? nil : walked
        }
        if let destination = pet.activity.destination {
            let walked = moving(pet, towards: destination, by: seconds)
            return walked.position == destination ? planningNext(walked, using: &random) : walked
        }
        if let endsAt = pet.activity.endsAt {
            let isRestless = pet.activity.isResting && pet.activity != .attending
                && PetBehaviour.isCrowded(pet, in: self) && random.chance(seconds * 0.4)
            return clock >= endsAt || isRestless ? planningNext(pet, using: &random) : pet
        }
        return pet
    }

    private func planningNext(_ pet: YardPet, using random: inout some RandomNumberGenerator) -> YardPet {
        if heldPetIDs.contains(pet.id) { return starting(.attending, for: pet) }
        return starting(PetBehaviour.nextActivity(for: pet, in: self, using: &random), for: pet)
    }

    private func moving(_ pet: YardPet, towards target: YardPoint, by seconds: Double) -> YardPet {
        let deltaX = target.x - pet.position.x
        let deltaDepth = target.depth - pet.position.depth
        let distance = (deltaX * deltaX + deltaDepth * deltaDepth).squareRoot()
        let stride = PetBehaviour.speed(for: pet) * seconds
        var moved = pet
        if distance <= stride {
            moved.position = target
        } else {
            let fraction = stride / distance
            moved.position = YardPoint(x: pet.position.x + deltaX * fraction, depth: pet.position.depth + deltaDepth * fraction)
        }
        moved.odometer += min(stride, distance)
        if abs(deltaX) > 0.01 { moved.facing = deltaX < 0 ? .left : .right }
        return moved
    }

    private func sendingHome(_ pet: YardPet) -> YardPet {
        pet.activity.isHeadingHome ? pet : starting(.startled(until: clock + PetBehaviour.startleDuration(for: pet)), for: pet)
    }

    private func updating(_ pet: YardPet, to entry: PetRosterEntry) -> YardPet {
        var updated = pet
        updated.entry = entry
        guard pet.activity.isHeadingHome else { return updated }
        return starting(.idling(until: clock + 0.5), for: updated)
    }

    private func starting(_ activity: PetActivity, for pet: YardPet) -> YardPet {
        var updated = pet
        updated.activity = activity
        updated.activityStartedAt = clock
        return updated
    }

    private static func retargeted(_ activity: PetActivity, to destination: YardPoint) -> PetActivity {
        switch activity {
        case .emerging: .emerging(destination: destination)
        case .walking: .walking(destination: destination)
        case .zooming: .zooming(destination: destination)
        default: activity
        }
    }
}
