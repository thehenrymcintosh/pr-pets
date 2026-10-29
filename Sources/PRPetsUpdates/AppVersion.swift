import Foundation

/// A `major.minor.patch` version. Anything after the numbers (`-3-gabc123`, `-beta`) marks a build
/// made from between releases; it's kept for display but ignored when comparing.
public struct AppVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let suffix: String?

    public init(major: Int, minor: Int, patch: Int, suffix: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.suffix = suffix
    }

    /// Parses `1.2.3`, `v1.2`, `1.2.3-4-gdeadbee`. Returns nil for anything without a leading number.
    public init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let unprefixed = trimmed.hasPrefix("v") || trimmed.hasPrefix("V") ? String(trimmed.dropFirst()) : trimmed
        let numericPart = unprefixed.prefix { $0.isNumber || $0 == "." }
        let numbers = numericPart.split(separator: ".").compactMap { Int($0) }
        guard let major = numbers.first else { return nil }
        let remainder = unprefixed.dropFirst(numericPart.count)
        self.init(
            major: major,
            minor: numbers.count > 1 ? numbers[1] : 0,
            patch: numbers.count > 2 ? numbers[2] : 0,
            suffix: remainder.isEmpty ? nil : String(remainder.drop { $0 == "-" || $0 == "+" })
        )
    }

    public var description: String {
        "\(major).\(minor).\(patch)" + (suffix.map { "-\($0)" } ?? "")
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) == (rhs.major, rhs.minor, rhs.patch)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(major)
        hasher.combine(minor)
        hasher.combine(patch)
    }
}
