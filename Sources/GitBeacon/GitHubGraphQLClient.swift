import Foundation

/// Polls the GitHub GraphQL API for the state of watched pull requests.
/// Uses a single batched query per poll (one request covers every watched
/// repo) rather than one REST call per repo, and backs off when the
/// GraphQL rate-limit budget runs low instead of polling on a fixed timer
/// regardless of remaining quota.
actor GitHubGraphQLClient {
    private let endpoint = URL(string: "https://api.github.com/graphql")!
    private var remainingPoints = 5000
    private var pollInterval: TimeInterval = 30

    func fetchStatuses(for repos: [String]) async throws -> [WatchedPullRequest] {
        guard let token = KeychainTokenStore.load() else {
            throw GitBeaconError.missingToken
        }
        guard !repos.isEmpty else { return [] }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            GraphQLPayload(query: Self.query, variables: ["repos": repos])
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw GitBeaconError.requestFailed
        }

        let decoded = try JSONDecoder().decode(GraphQLResponse.self, from: data)
        remainingPoints = decoded.data.rateLimit.remaining
        adjustPollInterval()

        return decoded.data.pullRequests
    }

    /// Widens the poll interval as the rate-limit budget shrinks, instead
    /// of hammering the API at a fixed cadence across many watched repos.
    private func adjustPollInterval() {
        switch remainingPoints {
        case ..<200: pollInterval = 300
        case ..<1000: pollInterval = 90
        default: pollInterval = 30
        }
    }

    var currentPollInterval: TimeInterval { pollInterval }

    // NOTE: placeholder shape — the real query needs to walk each watched
    // repo's open PRs plus their latest commit's check-suite status. Left
    // deliberately simple until the schema is wired up against a live token.
    private static let query = """
    query($repos: [String!]!) {
      rateLimit { remaining }
      # ...batched per-repo pullRequests(states: OPEN) { ... } aliases go here
    }
    """
}

private struct GraphQLPayload: Encodable {
    let query: String
    let variables: [String: [String]]
}

private struct GraphQLResponse: Decodable {
    struct Data: Decodable {
        let rateLimit: RateLimit
        let pullRequests: [WatchedPullRequest]
    }
    struct RateLimit: Decodable {
        let remaining: Int
    }
    let data: Data
}

enum GitBeaconError: Error {
    case missingToken
    case requestFailed
}
