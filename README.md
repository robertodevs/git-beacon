# GitBeacon

A menu bar dot that quietly tells you where your open pull requests stand —
review, CI, merge — across every repo you watch. No dashboard tab, no
fifteen browser tabs open just to check if the build went green.

The status item morphs instead of just swapping icons: a spinning arc while
checks run, then a settled color once they land — green (passed), red
(failed), blue (review requested), orange (changes requested), purple
(merged). Left-click for a dropdown timeline of every watched PR;
right-click for Settings, a manual refresh, or Quit.

## Status

Early scaffold, but functional end to end: `GitHubGraphQLClient` sends a
real batched query — one request per poll, aliasing every watched repo
(`repo0`, `repo1`, ...) and pulling each open/merged PR's review decision
and head-commit check-suite rollup — and it's confirmed working against a
live token. Settings (token + watched repos) now has a real window
instead of requiring a code edit.

## Requirements

- macOS 13+
- Xcode 15+ / Swift 5.9+
- A GitHub personal access token with `repo` read scope

## Getting started

```bash
git clone <your-fork-url>
cd git-beacon
open Package.swift
```

Build and run from Xcode. Right-click the status item → **Settings…** to
add your GitHub token (needs `repo` read scope) and the repos you want
watched, as `owner/name`.

## Project layout

```
Sources/GitBeacon/
  GitBeaconApp.swift          entry point (accessory app, no dock icon)
  AppDelegate.swift           wires up the status item + popover + polling
  BeaconIndicatorView.swift   the animated status-item glyph (CAShapeLayer)
  BeaconState.swift           polling loop + worst-status aggregation
  GitHubGraphQLClient.swift   batched GraphQL polling, rate-limit backoff
  PullRequestStatus.swift     the status enum driving color/shape
  WatchedPullRequest.swift    per-PR model
  WatchedReposConfig.swift    which repos to poll (UserDefaults-backed)
  KeychainTokenStore.swift    GitHub PAT storage via Keychain Services
  TimelineView.swift          SwiftUI dropdown list shown from the popover
  SettingsView.swift          token + watched-repo editor
  SettingsWindowController.swift  hosts SettingsView in a plain NSWindow
  NotificationService.swift   local notifications for checksFailed/merged transitions
```

## Roadmap

- [x] Fill in the real GraphQL query — batched per-repo `pullRequests`
      aliases plus each head commit's check-suite status
- [x] A real settings window for token + watched-repo list instead of
      seeding UserDefaults/Keychain by hand
- [x] Local notification when a watched PR's checks fail or it merges
- [ ] Verify the status mapping against a live token across more PR
      states — GitHub's actual review/check states may need more nuance
      than the current six
- [ ] Multiple status items or a compact summary when watching a lot of PRs

## License

MIT — see [LICENSE](LICENSE).
