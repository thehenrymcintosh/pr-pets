import Foundation
import PRPetsCore

/// Fetches pull requests through the user's own `gh` login. No tokens are stored by PR Pets.
public struct GhCliPullRequestSource: PullRequestSource {
    public struct Configuration: Hashable, Sendable {
        /// Explicit path to `gh`; nil means search the usual install locations.
        public var executablePath: String?
        /// GitHub Enterprise host; nil means github.com.
        public var host: String?

        public init(executablePath: String? = nil, host: String? = nil) {
            self.executablePath = executablePath
            self.host = host
        }
    }

    private let configuration: Configuration
    private let runner: any CommandRunner
    private let clock: @Sendable () -> Date

    public init(
        configuration: Configuration,
        runner: any CommandRunner = ProcessCommandRunner(),
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.configuration = configuration
        self.runner = runner
        self.clock = clock
    }

    public func fetchSnapshot(_ query: PullRequestQuery) async throws -> PullRequestSnapshot {
        let executable = try GhExecutableLocator.locate(explicitPath: configuration.executablePath)
        let queue: ViewerQueuePayload = try await graphQL(
            executable,
            document: GraphQLDocuments.viewerQueue,
            variables: [
                "reviewSearch": GraphQLDocuments.reviewRequestedSearch(query),
                "authoredSearch": GraphQLDocuments.authoredSearch(query),
            ]
        )
        let reviewRequested = try queue.reviewRequested.pullRequestNodes.map { try $0.toPullRequest() }
        let authored = try queue.authored.pullRequestNodes.map { try $0.toPullRequest() }
        let context = query.includeStackContext
            ? try await stackContext(executable, around: reviewRequested, viewer: Login(queue.viewer.login))
            : []
        return PullRequestSnapshot(
            viewer: Login(queue.viewer.login),
            fetchedAt: clock(),
            pullRequests: reviewRequested + authored + context,
            reviewRequestedOfViewer: Set(reviewRequested.map(\.id))
        )
    }

    /// Other open PRs by the same authors in the same repositories, so stacks can be shown whole.
    /// The viewer's own PRs are already fetched in full, and bots don't stack.
    private func stackContext(_ executable: URL, around pullRequests: [PullRequest], viewer: Login) async throws -> [PullRequest] {
        struct RepositoryAuthor: Hashable {
            let repository: RepositoryName
            let author: Login
        }
        let pairs = Set(pullRequests.map { RepositoryAuthor(repository: $0.repository, author: $0.author.login) })
            .filter { $0.author != viewer && !$0.author.rawValue.hasSuffix("[bot]") }
            .sorted { ($0.repository.nameWithOwner, $0.author.rawValue) < ($1.repository.nameWithOwner, $1.author.rawValue) }
        guard !pairs.isEmpty else { return [] }
        let variables = Dictionary(uniqueKeysWithValues: pairs.enumerated().map { index, pair in
            ("search\(index)", GraphQLDocuments.stackContextSearch(repository: pair.repository, author: pair.author))
        })
        let results: [String: SearchResult] = try await graphQL(
            executable,
            document: GraphQLDocuments.stackContext(searchCount: pairs.count),
            variables: variables
        )
        return try results.values.flatMap(\.pullRequestNodes).map { try $0.toPullRequest() }
    }

    private func graphQL<Payload: Decodable>(
        _ executable: URL,
        document: String,
        variables: [String: String]
    ) async throws -> Payload {
        let hostArguments = configuration.host.map { ["--hostname", $0] } ?? []
        let variableArguments = variables.sorted { $0.key < $1.key }.flatMap { ["-f", "\($0.key)=\($0.value)"] }
        let arguments = ["api", "graphql"] + hostArguments + ["-f", "query=\(document)"] + variableArguments
        let output = try await runner.run(executable, arguments: arguments)
        try checkSucceeded(output)
        return try decode(output.standardOutput)
    }

    private func checkSucceeded(_ output: CommandOutput) throws {
        guard output.exitCode != 0 else { return }
        // gh exits with 4 when authentication is required.
        let needsLogin = output.exitCode == 4 || output.standardError.contains("gh auth login")
        if needsLogin { throw GitHubSourceError.notAuthenticated(host: configuration.host ?? "github.com") }
        let message = output.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        throw GitHubSourceError.commandFailed(exitCode: output.exitCode, message: message.isEmpty ? "no error output" : message)
    }

    private func decode<Payload: Decodable>(_ data: Data) throws -> Payload {
        let envelope: GraphQLEnvelope<Payload>
        do {
            envelope = try JSONDecoder.gitHub.decode(GraphQLEnvelope<Payload>.self, from: data)
        } catch {
            throw GitHubSourceError.unreadableResponse(details: String(describing: error))
        }
        if let errors = envelope.errors, !errors.isEmpty, envelope.data == nil {
            throw GitHubSourceError.queryErrors(errors.map(\.message))
        }
        guard let payload = envelope.data else {
            throw GitHubSourceError.unreadableResponse(details: "response had no data")
        }
        return payload
    }
}

/// Apps launched from Finder don't inherit the shell's PATH, so `gh` has to be found explicitly.
public enum GhExecutableLocator {
    public static func candidatePaths(environment: [String: String] = ProcessInfo.processInfo.environment) -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let wellKnown = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "\(home)/.local/bin", "/run/current-system/sw/bin", "\(home)/.nix-profile/bin"]
        let fromPath = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        var seen = Set<String>()
        return (wellKnown + fromPath).filter { seen.insert($0).inserted }.map { "\($0)/gh" }
    }

    public static func locate(explicitPath: String?) throws -> URL {
        let candidates = explicitPath.map { [$0] } ?? candidatePaths()
        guard let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw GitHubSourceError.ghNotFound(searched: candidates)
        }
        return URL(fileURLWithPath: found)
    }
}
