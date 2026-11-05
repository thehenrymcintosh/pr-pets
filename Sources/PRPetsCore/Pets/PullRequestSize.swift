import Foundation

/// How much reading a pull request asks of its reviewer, in coarse bands so a pet doesn't change shape on every push.
public enum PullRequestSize: String, CaseIterable, Hashable, Codable, Sendable {
    case small, medium, large, extraLarge

    /// Lines touched (additions plus deletions) at which each band begins.
    static let mediumThreshold = 50
    static let largeThreshold = 400
    static let extraLargeThreshold = 800

    public init(_ lineDelta: LineDelta) {
        let linesTouched = lineDelta.additions + lineDelta.deletions
        self = switch linesTouched {
        case ..<Self.mediumThreshold: .small
        case ..<Self.largeThreshold: .medium
        case ..<Self.extraLargeThreshold: .large
        default: .extraLarge
        }
    }

    /// Bigger pull requests make chonkier pets.
    public var build: BodyBuild {
        switch self {
        case .small: .slim
        case .medium: .regular
        case .large: .chonky
        case .extraLarge: .extraChonky
        }
    }
}
