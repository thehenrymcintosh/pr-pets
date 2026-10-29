import PRPetsCore

/// The GraphQL sent to GitHub, and the search strings built from a `PullRequestQuery`.
enum GraphQLDocuments {
    static let pullRequestFields = """
    fragment PullRequestFields on PullRequest {
      id number title url isDraft additions deletions changedFiles createdAt updatedAt
      headRefName baseRefName headRefOid isCrossRepository reviewDecision
      repository { nameWithOwner }
      author { login ... on User { name } }
      reviewRequests(first: 20) {
        nodes { requestedReviewer { __typename ... on User { login } ... on Team { slug } } }
      }
      latestReviews(first: 20) { nodes { state author { login } } }
    }
    """

    static let viewerQueue = """
    query ViewerQueue($reviewSearch: String!, $authoredSearch: String!) {
      viewer { login }
      reviewRequested: search(query: $reviewSearch, type: ISSUE, first: 50) { nodes { ...PullRequestFields } }
      authored: search(query: $authoredSearch, type: ISSUE, first: 50) { nodes { ...PullRequestFields } }
    }
    \(pullRequestFields)
    """

    /// One aliased search per (repository, author) so every stack member comes back in a single request.
    static func stackContext(searchCount: Int) -> String {
        let variables = (0..<searchCount).map { "$search\($0): String!" }.joined(separator: ", ")
        let searches = (0..<searchCount)
            .map { "  context\($0): search(query: $search\($0), type: ISSUE, first: 30) { nodes { ...PullRequestFields } }" }
            .joined(separator: "\n")
        return """
        query StackContext(\(variables)) {
        \(searches)
        }
        \(pullRequestFields)
        """
    }

    static func reviewRequestedSearch(_ query: PullRequestQuery) -> String {
        search("review-requested:@me", query)
    }

    static func authoredSearch(_ query: PullRequestQuery) -> String {
        search("author:@me", query)
    }

    static func stackContextSearch(repository: RepositoryName, author: Login) -> String {
        "is:pr is:open repo:\(repository.nameWithOwner) author:\(author.rawValue)"
    }

    private static func search(_ qualifier: String, _ query: PullRequestQuery) -> String {
        let owners = query.owners.map { "user:\($0)" }
        let exclusions = query.excludedRepositories.map { "-repo:\($0)" }
        return (["is:pr", "is:open", "archived:false", qualifier] + owners + exclusions).joined(separator: " ")
    }
}
