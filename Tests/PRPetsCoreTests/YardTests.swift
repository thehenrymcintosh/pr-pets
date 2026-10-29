import PRPetsCore
import PRPetsDemo
import Testing

private let geometry = YardGeometry(roamingSpan: 0...200, depthSpan: 0...6, door: YardPoint(x: 100, depth: 3))
private let frameDuration = 1.0 / 30

private func entry(_ number: Int) -> PetRosterEntry {
    let pullRequest = PullRequestFixture.make(number)
    return PetRosterEntry(id: pullRequest.id, genome: GenomeFactory.genome(for: Seed(hashing: pullRequest.id.rawValue)), label: "pet \(number)", stackPosition: nil)
}

private func roster(_ numbers: [Int]) -> PetRoster { PetRoster(entries: numbers.map(entry)) }

private extension Yard {
    mutating func run(seconds: Double, random: inout SeededRandom, every: (Yard) -> Void = { _ in }) {
        for _ in 0..<Int(seconds / frameDuration) {
            advance(by: frameDuration, using: &random)
            every(self)
        }
    }
}

@Suite("Yard simulation")
struct YardTests {
    @Test func petsComeOutOneAtATime() {
        var yard = Yard(geometry: geometry)
        var random = SeededRandom(seed: Seed(1))
        yard.reconcile(with: roster([1, 2, 3]))

        yard.advance(by: frameDuration, using: &random)
        #expect(yard.pets.count == 1)
        yard.run(seconds: 2, random: &random)
        #expect(yard.pets.count == 3)
    }

    @Test func petsStayInsideTheYard() {
        var yard = Yard(geometry: geometry)
        var random = SeededRandom(seed: Seed(2))
        yard.reconcile(with: roster(Array(1...6)))
        yard.run(seconds: 300, random: &random) { yard in
            for pet in yard.pets {
                #expect(geometry.roamingSpan.contains(pet.position.x))
                #expect(geometry.depthSpan.contains(pet.position.depth))
            }
        }
    }

    @Test func petsThatLeaveTheRosterGoHome() {
        var yard = Yard(geometry: geometry)
        var random = SeededRandom(seed: Seed(3))
        yard.reconcile(with: roster([1, 2, 3]))
        yard.run(seconds: 20, random: &random)

        yard.reconcile(with: roster([2]))
        #expect(yard.pets.filter { $0.activity == .returningHome }.count == 2)
        yard.run(seconds: 10, random: &random)
        #expect(yard.pets.map(\.entry.label) == ["pet 2"])
    }

    @Test func aPetHeadingHomeTurnsAroundIfWantedAgain() {
        var yard = Yard(geometry: geometry)
        var random = SeededRandom(seed: Seed(4))
        yard.reconcile(with: roster([1]))
        yard.run(seconds: 15, random: &random)

        yard.reconcile(with: .empty)
        yard.reconcile(with: roster([1]))
        #expect(yard.pets.first?.activity != .returningHome)
        yard.run(seconds: 10, random: &random)
        #expect(yard.pets.count == 1)
    }

    @Test func emptyingTheRosterSendsEveryoneInside() {
        var yard = Yard(geometry: geometry)
        var random = SeededRandom(seed: Seed(5))
        yard.reconcile(with: roster(Array(1...5)))
        yard.run(seconds: 30, random: &random)
        yard.reconcile(with: .empty)
        yard.run(seconds: 10, random: &random)
        #expect(yard.isEmpty)
    }

    @Test func heldPetsWaitForTheUser() {
        var yard = Yard(geometry: geometry)
        var random = SeededRandom(seed: Seed(6))
        yard.reconcile(with: roster([1]))
        yard.run(seconds: 5, random: &random)
        let id = yard.pets[0].id

        yard.hold(id)
        let heldAt = yard.pets[0].position
        yard.run(seconds: 30, random: &random)
        #expect(yard.pets[0].activity == .attending)
        #expect(yard.pets[0].position == heldAt)

        yard.release(id)
        #expect(yard.pets[0].activity != .attending)
    }

    @Test func petsPreferToSpreadOut() {
        var yard = Yard(geometry: geometry)
        var random = SeededRandom(seed: Seed(7))
        yard.reconcile(with: roster(Array(1...4)))
        yard.run(seconds: 10, random: &random)
        var closestSpacings: [Double] = []
        yard.run(seconds: 600, random: &random) { yard in
            let positions = yard.pets.map(\.position)
            let pairs = positions.indices.flatMap { i in positions.indices.filter { $0 > i }.map { (positions[i], positions[$0]) } }
            if let closest = pairs.map({ $0.spacing(to: $1) }).min() { closestSpacings.append(closest) }
        }
        let averageClosest = closestSpacings.reduce(0, +) / Double(closestSpacings.count)
        // Four pets placed at random in a 200px yard average ~27px from their nearest neighbour.
        #expect(averageClosest > 30, "average nearest-neighbour spacing was \(averageClosest)")
    }

    @Test func petsDoAVarietyOfThings() {
        var yard = Yard(geometry: geometry)
        var random = SeededRandom(seed: Seed(8))
        yard.reconcile(with: roster(Array(1...5)))
        var posesSeen = Set<PetPose>()
        yard.run(seconds: 600, random: &random) { yard in
            yard.pets.forEach { posesSeen.insert($0.pose(at: yard.clock)) }
        }
        #expect(posesSeen == Set(PetPose.allCases))
    }

    @Test func relocatingKeepsPetsInTheNewBounds() {
        var yard = Yard(geometry: geometry)
        var random = SeededRandom(seed: Seed(9))
        yard.reconcile(with: roster([1, 2, 3]))
        yard.run(seconds: 20, random: &random)

        let smaller = YardGeometry(roamingSpan: 50...120, depthSpan: 0...6, door: YardPoint(x: 80, depth: 3))
        yard.relocate(to: smaller)
        yard.run(seconds: 60, random: &random) { yard in
            #expect(yard.pets.allSatisfy { smaller.roamingSpan.contains($0.position.x) })
        }
    }

    @Test func simulationIsDeterministic() {
        func finalPositions() -> [YardPoint] {
            var yard = Yard(geometry: geometry)
            var random = SeededRandom(seed: Seed(10))
            yard.reconcile(with: roster([1, 2, 3]))
            yard.run(seconds: 60, random: &random)
            return yard.pets.map(\.position)
        }
        #expect(finalPositions() == finalPositions())
    }
}
