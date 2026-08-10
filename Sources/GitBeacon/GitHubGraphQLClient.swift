import Foundation

/// Polls the GitHub GraphQL API for the state of watched pull requests.
/// Uses a single batched query per poll (one request covers every watched
/// repo, each aliased as `repo0`, `repo1`, ...) rather than one REST call
/// per repo, and backs off when the GraphQL rate-limit budget runs low
/// instead of polling on a fixed timer regardless of remaining quota.
actor GitHubGraphQLClient {
    private let endpoint = URL(string: "https://api.github.com/graphql")!
    private var remainingPoints = 5000
    private var pollInterval: TimeInterval = 30

    var currentPollInterval: TimeInterval { pollInterval }

    func fetchStatuses(for repos: [String]) async throws -> [WatchedPullRequest] {
        guard let token = KeychainTokenStore.load() else {
            throw GitBeaconError.missingToken
        }
        let targets = repos.compactMap(RepoRef.init)
        guard !targets.isEmpty else { return [] }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(GraphQLPayload(query: Self.query(for: targets)))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw GitBeaconError.requestFailed
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(GraphQLEnvelope.self, from: data)

        remainingPoints = envelope.data.rateLimit.remaining
        adjustPollInterval()

        return zip(targets, envelope.data.orderedRepos).flatMap { target, repoPayload in
            (repoPayload?.pullRequests.nodes ?? []).map { $0.asWatchedPullRequest(repo: target.fullName) }
        }
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

    private static func query(for targets: [RepoRef]) -> String {
        let fields = targets.enumerated().map { index, target in
            """
            repo\(index): repository(owner: "\(target.owner)", name: "\(target.name)") {
              pullRequests(states: [OPEN, MERGED], first: 20, orderBy: {field: UPDATED_AT, direction: DESC}) {
                nodes {
                  id
                  number
                  title
                  url
                  updatedAt
                  mergedAt
                  reviewDecision
                  commits(last: 1) {
                    nodes {
                      commit {
                        statusCheckRollup { state }
                      }
                    }
                  }
                }
              }
            }
            """
        }.joined(separator: "\n")

        return """
        query {
          rateLimit { remaining }
          \(fields)
        }
        """
    }
}

/// A parsed "owner/name" watched-repo entry.
private struct RepoRef {
    let owner: String
    let name: String

    var fullName: String { "\(owner)/\(name)" }

    init?(_ raw: String) {
        let parts = raw.split(separator: "/", maxSplits: 1)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        owner = String(parts[0])
        name = String(parts[1])
    }
}

private struct GraphQLPayload: Encodable {
    let query: String
}

/// GitHub's response has one dynamically-named key per aliased repo
/// (`repo0`, `repo1`, ...), which a fixed `CodingKeys` enum can't express
/// — this decodes them by index instead, stopping at the first gap.
private struct GraphQLEnvelope: Decodable {
    let data: Payload

    struct Payload: Decodable {
        let rateLimit: RateLimit
        let orderedRepos: [RepoPayload?]

        private struct DynamicKey: CodingKey {
            var stringValue: String
            var intValue: Int?
            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { self.stringValue = "repo\(intValue)"; self.intValue = intValue }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicKey.self)
            rateLimit = try container.decode(RateLimit.self, forKey: DynamicKey(stringValue: "rateLimit")!)

            var repos: [RepoPayload?] = []
            var index = 0
            while let key = DynamicKey(intValue: index), container.contains(key) {
                repos.append(try container.decodeIfPresent(RepoPayload.self, forKey: key))
                index += 1
            }
            orderedRepos = repos
        }
    }

    struct RateLimit: Decodable {
        let remaining: Int
    }

    struct RepoPayload: Decodable {
        let pullRequests: PullRequests
    }

    struct PullRequests: Decodable {
        let nodes: [PullRequestNode]
    }
}

private struct PullRequestNode: Decodable {
    let id: String
    let number: Int
    let title: String
    let url: URL
    let updatedAt: Date
    let mergedAt: Date?
    let reviewDecision: String?
    let commits: Commits

    struct Commits: Decodable {
        let nodes: [CommitWrapper]
    }
    struct CommitWrapper: Decodable {
        let commit: Commit
    }
    struct Commit: Decodable {
        let statusCheckRollup: StatusCheckRollup?
    }
    struct StatusCheckRollup: Decodable {
        let state: String // SUCCESS, FAILURE, ERROR, PENDING, EXPECTED
    }

    func asWatchedPullRequest(repo: String) -> WatchedPullRequest {
        WatchedPullRequest(
            id: id,
            repo: repo,
            number: number,
            title: title,
            url: url,
            status: resolvedStatus,
            updatedAt: updatedAt
        )
    }

    /// Maps GitHub's independent merge/review/check-suite signals onto
    /// GitBeacon's single-axis status, worst-first: a failing check
    /// outranks a pending review, which outranks a clean pass.
    private var resolvedStatus: PullRequestStatus {
        if mergedAt != nil { return .merged }

        let rollupState = commits.nodes.first?.commit.statusCheckRollup?.state
        if rollupState == "FAILURE" || rollupState == "ERROR" { return .checksFailed }
        if reviewDecision == "CHANGES_REQUESTED" { return .changesRequested }
        if rollupState == "PENDING" || rollupState == "EXPECTED" { return .checksRunning }
        if reviewDecision == "REVIEW_REQUIRED" { return .reviewRequested }
        return .checksPassed
    }
}

enum GitBeaconError: Error {
    case missingToken
    case requestFailed
}
