import Foundation
import PRPetsCore
import Testing
@testable import PRPetsGitHub

/// Stands in for `gh`, answering each GraphQL operation with a recorded fixture.
private struct RecordedGh: CommandRunner {
    var responses: [String: CommandOutput]
    let recordedArguments = ArgumentLog()

    func run(_ executable: URL, arguments: [String]) async throws -> CommandOutput {
        recordedArguments.append(arguments)
        let query = arguments.first { $0.hasPrefix("query=") } ?? ""
        let operation = responses.keys.first { query.contains("query \($0)") } ?? ""
        return responses[operation] ?? CommandOutput(exitCode: 1, standardOutput: Data(), standardError: "no fixture for \(operation)")
    }

    static func succeeding(_ fixtureByOperation: [String: String]) throws -> RecordedGh {
        RecordedGh(responses: try fixtureByOperation.mapValues { fixture in
            CommandOutput(exitCode: 0, standardOutput: try fixtureData(fixture), standardError: "")
        })
    }
}

private final class ArgumentLog: @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [[String]] = []
    func append(_ arguments: [String]) { lock.withLock { calls.append(arguments) } }
    var all: [[String]] { lock.withLock { calls } }
}

private func fixtureData(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

/// `/bin/sh` always exists and is executable; the recorded runner never actually launches it.
private let anyExecutable = GhCliPullRequestSource.Configuration(executablePath: "/bin/sh")

@Suite("gh CLI pull request source")
struct GhCliPullRequestSourceTests {
    @Test func decodesTheViewersQueueAndStackContext() async throws {
        let gh = try RecordedGh.succeeding(["ViewerQueue": "viewer-queue", "StackContext": "stack-context"])
        let source = GhCliPullRequestSource(configuration: anyExecutable, runner: gh)

        let snapshot = try await source.fetchSnapshot(PullRequestQuery())

        #expect(snapshot.viewer == Login("octo-me"))
        #expect(snapshot.reviewRequestedOfViewer == [PullRequestID("PR_web101"), PullRequestID("PR_api55"), PullRequestID("PR_api60")])
        let numbers = snapshot.pullRequests.map(\.number).sorted()
        #expect(numbers == [55, 60, 61, 90, 91, 100, 101, 102], "context PRs are merged in without duplicates")

        let checkout = try #require(snapshot.pullRequest(withID: PullRequestID("PR_web101")))
        #expect(checkout.author == Person(login: Login("alice"), displayName: "Alice Liddell"))
        #expect(checkout.lineDelta == LineDelta(additions: 240, deletions: 88, changedFiles: 6))
        #expect(checkout.branches == BranchPair(head: "alice/step-2", base: "alice/step-1"))
        #expect(checkout.requestedReviewers == [.user(Login("octo-me"))])
    }

    @Test func dropsNullReviewersAndKeepsTeams() async throws {
        let gh = try RecordedGh.succeeding(["ViewerQueue": "viewer-queue", "StackContext": "stack-context"])
        let snapshot = try await GhCliPullRequestSource(configuration: anyExecutable, runner: gh).fetchSnapshot(PullRequestQuery())

        let retries = try #require(snapshot.pullRequest(withID: PullRequestID("PR_api55")))
        #expect(retries.requestedReviewers == [.team(slug: "platform")])
    }

    @Test func skipsTheContextRequestWhenStacksAreTurnedOff() async throws {
        let gh = try RecordedGh.succeeding(["ViewerQueue": "viewer-queue"])
        let source = GhCliPullRequestSource(configuration: anyExecutable, runner: gh)

        let snapshot = try await source.fetchSnapshot(PullRequestQuery(includeStackContext: false))

        #expect(gh.recordedArguments.all.count == 1)
        #expect(snapshot.pullRequests.count == 6)
    }

    @Test func buildsSearchesFromTheQueryFilters() async throws {
        let gh = try RecordedGh.succeeding(["ViewerQueue": "viewer-queue"])
        let source = GhCliPullRequestSource(configuration: .init(executablePath: "/bin/sh", host: "github.example.com"), runner: gh)

        _ = try await source.fetchSnapshot(PullRequestQuery(owners: ["acme"], excludedRepositories: ["acme/legacy"], includeStackContext: false))

        let arguments = try #require(gh.recordedArguments.all.first)
        #expect(arguments.starts(with: ["api", "graphql", "--hostname", "github.example.com"]))
        #expect(arguments.contains("reviewSearch=is:pr is:open archived:false review-requested:@me user:acme -repo:acme/legacy"))
        #expect(arguments.contains("authoredSearch=is:pr is:open archived:false author:@me user:acme -repo:acme/legacy"))
    }

    @Test func reportsMissingLoginClearly() async throws {
        let gh = RecordedGh(responses: ["ViewerQueue": CommandOutput(
            exitCode: 4, standardOutput: Data(), standardError: "To get started with GitHub CLI, please run:  gh auth login"
        )])
        let source = GhCliPullRequestSource(configuration: anyExecutable, runner: gh)

        await #expect(throws: GitHubSourceError.notAuthenticated(host: "github.com")) {
            try await source.fetchSnapshot(PullRequestQuery())
        }
    }

    @Test func surfacesGraphQLErrors() async throws {
        let gh = try RecordedGh.succeeding(["ViewerQueue": "query-error"])
        let source = GhCliPullRequestSource(configuration: anyExecutable, runner: gh)

        await #expect(throws: GitHubSourceError.queryErrors(["Something went wrong while executing your query."])) {
            try await source.fetchSnapshot(PullRequestQuery())
        }
    }

    @Test func reportsWhereItLookedWhenGhIsMissing() {
        #expect(throws: GitHubSourceError.ghNotFound(searched: ["/nowhere/gh"])) {
            try GhExecutableLocator.locate(explicitPath: "/nowhere/gh")
        }
    }

    @Test func searchesHomebrewEvenWithoutAShellPath() {
        let candidates = GhExecutableLocator.candidatePaths(environment: [:])
        #expect(candidates.contains("/opt/homebrew/bin/gh"))
        #expect(candidates.contains("/usr/local/bin/gh"))
    }
}
