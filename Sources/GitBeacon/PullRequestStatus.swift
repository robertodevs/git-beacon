import Foundation

/// The lifecycle stages GitBeacon distinguishes visually. Order matters —
/// `BeaconState` picks the single "worst" (most attention-needing) status
/// across all watched PRs to drive the status bar indicator.
enum PullRequestStatus: Int, Comparable, Decodable {
    case merged
    case checksPassed
    case checksRunning
    case reviewRequested
    case changesRequested
    case checksFailed

    static func < (lhs: PullRequestStatus, rhs: PullRequestStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .merged: return "Merged"
        case .checksPassed: return "Checks passed"
        case .checksRunning: return "Checks running"
        case .reviewRequested: return "Review requested"
        case .changesRequested: return "Changes requested"
        case .checksFailed: return "Checks failed"
        }
    }
}
