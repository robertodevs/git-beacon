import Foundation

/// Which repos to poll, stored as "owner/name" strings. Backed by
/// UserDefaults for now — swap for a proper settings window later.
enum WatchedReposConfig {
    private static let key = "com.robertodevs.gitbeacon.watchedRepos"

    static var repos: [String] {
        get { UserDefaults.standard.stringArray(forKey: key) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
