import Foundation
import PRPetsCore

/// Wire shapes for GitHub's GraphQL responses, mapped to domain types in `toPullRequest()`.
struct GraphQLEnvelope<Payload: Decodable>: Decodable {
    struct Problem: Decodable { let message: String }
    let data: Payload?
    let errors: [Problem]?
}

struct ViewerQueuePayload: Decodable {
    struct Viewer: Decodable { let login: String }
    let viewer: Viewer
    let reviewRequested: SearchResult
    let authored: SearchResult
}

struct SearchResult: Decodable {
    /// Nodes that aren't pull requests decode as nil and are dropped.
    let nodes: [PullRequestNode?]

    var pullRequestNodes: [PullRequestNode] { nodes.compactMap { $0 } }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nodes = try container.decode([OptionalNode].self, forKey: .nodes).map(\.node)
    }

    private enum CodingKeys: String, CodingKey { case nodes }

    private struct OptionalNode: Decodable {
        let node: PullRequestNode?
        init(from decoder: any Decoder) throws { node = try? PullRequestNode(from: decoder) }
    }
}

struct PullRequestNode: Decodable {
    struct Repository: Decodable { let nameWithOwner: String }
    struct Author: Decodable {
        let login: String
        let name: String?
    }
    struct ReviewRequests: Decodable {
        struct Node: Decodable {
            struct Reviewer: Decodable {
                let __typename: String
                let login: String?
                let slug: String?
            }
            let requestedReviewer: Reviewer?
        }
        let nodes: [Node]
    }
    struct LatestReviews: Decodable {
        struct Node: Decodable {
            struct Author: Decodable { let login: String }
            let state: String
            let author: Author?
        }
        let nodes: [Node]
    }

    let id: String
    let number: Int
    let title: String
    let url: String
    let isDraft: Bool
    let additions: Int
    let deletions: Int
    let changedFiles: Int
    let createdAt: Date
    let updatedAt: Date
    let headRefName: String
    let baseRefName: String
    let headRefOid: String
    let isCrossRepository: Bool
    let reviewDecision: String?
    let repository: Repository
    /// Null when the author's account was deleted.
    let author: Author?
    let reviewRequests: ReviewRequests
    let latestReviews: LatestReviews

    func toPullRequest() throws -> PullRequest {
        guard let repositoryName = RepositoryName(nameWithOwner: repository.nameWithOwner) else {
            throw GitHubSourceError.unreadableResponse(details: "repository name '\(repository.nameWithOwner)'")
        }
        guard let pullRequestURL = URL(string: url) else {
            throw GitHubSourceError.unreadableResponse(details: "PR url '\(url)'")
        }
        return PullRequest(
            id: PullRequestID(id),
            repository: repositoryName,
            number: number,
            title: title,
            url: pullRequestURL,
            author: Person(login: Login(author?.login ?? "ghost"), displayName: author?.name.flatMap { $0.isEmpty ? nil : $0 }),
            lineDelta: LineDelta(additions: additions, deletions: deletions, changedFiles: changedFiles),
            isDraft: isDraft,
            branches: BranchPair(head: headRefName, base: baseRefName, headIsInFork: isCrossRepository),
            headCommit: headRefOid,
            reviewDecision: reviewDecision.flatMap(Self.reviewDecision),
            requestedReviewers: reviewRequests.nodes.compactMap { $0.requestedReviewer.flatMap(Self.requestedReviewer) },
            latestReviews: latestReviews.nodes.compactMap(Self.submittedReview),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func reviewDecision(_ raw: String) -> ReviewDecision? {
        switch raw {
        case "APPROVED": .approved
        case "CHANGES_REQUESTED": .changesRequested
        case "REVIEW_REQUIRED": .reviewRequired
        default: nil
        }
    }

    private static func requestedReviewer(_ reviewer: ReviewRequests.Node.Reviewer) -> RequestedReviewer? {
        switch reviewer.__typename {
        case "User", "Bot", "Mannequin": reviewer.login.map { .user(Login($0)) }
        case "Team": reviewer.slug.map { .team(slug: $0) }
        default: nil
        }
    }

    private static func submittedReview(_ node: LatestReviews.Node) -> SubmittedReview? {
        guard let author = node.author else { return nil }
        let verdict: SubmittedReview.Verdict? = switch node.state {
        case "APPROVED": .approved
        case "CHANGES_REQUESTED": .changesRequested
        case "COMMENTED": .commented
        case "DISMISSED": .dismissed
        case "PENDING": .pending
        default: nil
        }
        return verdict.map { SubmittedReview(reviewer: Login(author.login), verdict: $0) }
    }
}

extension JSONDecoder {
    static let gitHub: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
