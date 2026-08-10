import Foundation

struct WatchedPullRequest: Identifiable, Equatable, Decodable {
    let id: String // GraphQL node id
    let repo: String // "owner/name"
    let number: Int
    let title: String
    let url: URL
    let status: PullRequestStatus
    let updatedAt: Date
}
