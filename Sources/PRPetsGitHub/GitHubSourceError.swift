import Foundation

/// Failures the user can act on. Descriptions are shown verbatim in the dashboard.
public enum GitHubSourceError: Error, Hashable, Sendable, CustomStringConvertible {
    case ghNotFound(searched: [String])
    case notAuthenticated(host: String)
    case commandFailed(exitCode: Int32, message: String)
    case unreadableResponse(details: String)
    case queryErrors([String])

    public var description: String {
        switch self {
        case .ghNotFound(let searched):
            "Couldn't find the GitHub CLI (gh). Install it with `brew install gh`, or set its path in Settings. Looked in: \(searched.joined(separator: ", "))"
        case .notAuthenticated(let host):
            "gh isn't logged in to \(host). Run `gh auth login` in a terminal, then refresh."
        case .commandFailed(let exitCode, let message):
            "gh exited with code \(exitCode): \(message)"
        case .unreadableResponse(let details):
            "GitHub sent a response PR Pets couldn't read: \(details)"
        case .queryErrors(let messages):
            "GitHub reported: \(messages.joined(separator: "; "))"
        }
    }
}
