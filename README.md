# GitBeacon

A menu bar dot that quietly tells you where your open pull requests stand —
review, CI, merge — across every repo you watch. No dashboard tab, no
fifteen browser tabs open just to check if the build went green.

The status item morphs instead of just swapping icons: a spinning arc while
checks run, then a settled color once they land — green (passed), red
(failed), blue (review requested), orange (changes requested), purple
(merged). Click it for a dropdown timeline of every watched PR.

## Status

Early scaffold. Status-item rendering, the polling loop, and the dropdown
timeline are wired up, and `GitHubGraphQLClient` now sends a real batched
query — one request per poll, aliasing every watched repo (`repo0`,
`repo1`, ...) and pulling each open/merged PR's review decision and
head-commit check-suite rollup. Untested against a live token so far.

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

Build and run from Xcode. On first launch there's no settings UI yet —
seed a token and repo list from a debug breakpoint or a temporary call to:

```swift
KeychainTokenStore.save("ghp_...")
WatchedReposConfig.repos = ["robertodevs/NotchCritter", "robertodevs/git-beacon"]
```

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
```

## Roadmap

- [x] Fill in the real GraphQL query — batched per-repo `pullRequests`
      aliases plus each head commit's check-suite status
- [ ] A real settings window for token + watched-repo list instead of
      seeding UserDefaults/Keychain by hand
- [ ] Verify the status mapping against a live token — GitHub's actual
      review/check states may need more nuance than the current six
- [ ] Local notification when a watched PR's checks fail or it merges
- [ ] Multiple status items or a compact summary when watching a lot of PRs

## License

MIT — see [LICENSE](LICENSE).
