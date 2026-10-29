import Foundation

/// A stable 64-bit seed. Derived with FNV-1a, never `Hasher`, which is randomised per process.
public struct Seed: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: UInt64
    public init(_ rawValue: UInt64) { self.rawValue = rawValue }

    public init(hashing text: String) {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        self.init(hash)
    }

    public func derived(_ purpose: String) -> Seed {
        Seed(hashing: "\(rawValue):\(purpose)")
    }

    public var description: String { String(rawValue, radix: 16) }
}

/// SplitMix64: tiny, fast and fully deterministic for a given seed.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: Seed) { state = seed.rawValue }

    public mutating func next() -> UInt64 {
        state &+= 0x9e37_79b9_7f4a_7c15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xbf58_476d_1ce4_e5b9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94d0_49bb_1331_11eb
        return mixed ^ (mixed >> 31)
    }
}

extension RandomNumberGenerator {
    /// Picks from `options` with probability proportional to each weight.
    public mutating func weightedPick<Option>(_ options: [(Option, Double)]) -> Option {
        precondition(!options.isEmpty, "weightedPick needs at least one option")
        let totalWeight = options.reduce(0) { $0 + max(0, $1.1) }
        guard totalWeight > 0 else { return options[0].0 }
        var remaining = Double.random(in: 0..<totalWeight, using: &self)
        for (option, weight) in options {
            remaining -= max(0, weight)
            if remaining < 0 { return option }
        }
        return options[options.count - 1].0
    }

    public mutating func chance(_ probability: Double) -> Bool {
        Double.random(in: 0..<1, using: &self) < probability
    }
}
