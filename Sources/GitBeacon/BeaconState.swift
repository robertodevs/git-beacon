import Foundation
import Combine

@MainActor
final class BeaconState: ObservableObject {
    @Published private(set) var pullRequests: [WatchedPullRequest] = []

    /// The single status the indicator renders: worst-case across every
    /// watched PR, so a failing check anywhere is never hidden behind a
    /// passing one elsewhere.
    var overallStatus: PullRequestStatus? {
        pullRequests.map(\.status).max()
    }

    private let client = GitHubGraphQLClient()
    private var pollTask: Task<Void, Never>?

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.refresh()
                let interval = await self.client.currentPollInterval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
    }

    func refresh() async {
        do {
            pullRequests = try await client.fetchStatuses(for: WatchedReposConfig.repos)
        } catch {
            NSLog("GitBeacon: refresh failed — \(error)")
        }
    }
}
