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
    private var hasCompletedFirstRefresh = false

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
            let updated = try await client.fetchStatuses(for: WatchedReposConfig.repos)
            // Skip the very first refresh after launch (or after the watched-repo
            // list changes) — otherwise every already-failed or already-merged PR
            // notifies immediately instead of only on a genuine transition.
            if hasCompletedFirstRefresh {
                notifyTransitions(from: pullRequests, to: updated)
            }
            pullRequests = updated
            hasCompletedFirstRefresh = true
        } catch {
            NSLog("GitBeacon: refresh failed — \(error)")
        }
    }

    private func notifyTransitions(from previous: [WatchedPullRequest], to current: [WatchedPullRequest]) {
        let previousStatusByID = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0.status) })
        for pr in current {
            guard pr.status == .checksFailed || pr.status == .merged else { continue }
            guard previousStatusByID[pr.id] != pr.status else { continue }
            NotificationService.notify(for: pr)
        }
    }
}
