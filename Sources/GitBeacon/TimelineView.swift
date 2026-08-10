import SwiftUI

/// Dropdown contents shown from the status item: every watched PR with
/// its current status, newest activity first.
struct TimelineView: View {
    @ObservedObject var state: BeaconState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("GitBeacon")
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider()

            if state.pullRequests.isEmpty {
                Text("No open pull requests across your watched repos.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .padding(14)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(state.pullRequests.sorted(by: { $0.updatedAt > $1.updatedAt })) { pr in
                            row(for: pr)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .frame(width: 320)
        .frame(maxHeight: 360)
    }

    private func row(for pr: WatchedPullRequest) -> some View {
        Link(destination: pr.url) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(color(for: pr.status))
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pr.title)
                        .font(.callout)
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                    Text("\(pr.repo) #\(pr.number) · \(pr.status.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func color(for status: PullRequestStatus) -> Color {
        switch status {
        case .merged: return .purple
        case .checksPassed: return .green
        case .checksRunning: return .yellow
        case .reviewRequested: return .blue
        case .changesRequested: return .orange
        case .checksFailed: return .red
        }
    }
}
