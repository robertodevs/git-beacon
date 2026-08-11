# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

GitBeacon is a native macOS menu bar app (SwiftUI + AppKit, SwiftPM
executable target, no `.xcodeproj`). It polls the GitHub GraphQL API for
the state of pull requests across a configured list of watched repos and
renders a single animated status-item glyph that reflects the
worst-case status across all of them, plus a popover with a per-PR
timeline.

## Commands

- Build: `swift build`
- Run/debug: `open Package.swift` (opens in Xcode via SwiftPM
  integration), or `swift run`, both fine for quick iteration on the
  status item and popover. Neither produces a real `.app` bundle, though
  — Xcode's SwiftPM "Run" for an `executableTarget` is a bare Mach-O
  binary same as `swift build`, not a packaged app (confirmed: no `.app`
  shows up under DerivedData either way). That's enough for everything
  except notifications.
- Run with notifications working: `Scripts/run-app.sh` — builds, wraps
  the binary in a throwaway `.app` bundle under `.build/`, ad-hoc
  codesigns it, and opens it via `open`. `UNUserNotificationCenter`
  refuses authorization ("Notifications are not allowed for this
  application") for anything not launched as a registered, bundled app —
  confirmed by comparing `log show --predicate 'process == "GitBeacon"'`
  output between a direct launch and one through this script.
- No test target exists yet.

Token and watched-repo list are entered through the Settings window
(right-click the status item), backed by `KeychainTokenStore` and
`WatchedReposConfig` respectively — see README "Getting started".

## Architecture

**Wiring** (`AppDelegate.swift`): owns the `NSStatusItem`, the
`BeaconIndicatorView` embedded in its button, and an `NSPopover` hosting
`TimelineView` via `NSHostingController`. It subscribes to
`BeaconState.$pullRequests` and pushes the aggregated status into the
indicator view on every change. `GitBeaconApp.swift` is a near-empty
`Settings` scene — nearly all app behavior lives in the delegate, not in
SwiftUI `Scene`/`WindowGroup` code.

Left-click vs. right-click on the status item is one `action` handler
(`handleStatusItemClick`) branching on `NSApp.currentEvent?.type`, not
two separate targets — `NSStatusItem` only exposes one action. The
right-click menu (`showContextMenu`) is built and assigned to
`statusItem.menu` on demand, `performClick`-triggered, then immediately
detached; leaving a menu permanently attached would swallow left-clicks
and break the popover toggle. `SettingsWindowController` is a plain
`NSWindow`, not the SwiftUI `Settings` scene — accessory apps (no Dock
icon, no app menu) don't reliably get the automatic Cmd+, handling, so
Settings is opened directly from that right-click menu instead.

**Status aggregation** (`BeaconState.swift` + `PullRequestStatus.swift`):
`BeaconState` runs the polling loop (a `Task` sleeping for
`GitHubGraphQLClient.currentPollInterval` between fetches) and exposes
`overallStatus`, computed as `pullRequests.map(\.status).max()`. This
only works because `PullRequestStatus` is `Comparable` via its `Int`
raw value, and the **enum case declaration order is the priority
order** (declared worst-to-best is not the case — check the enum before
assuming semantics; currently `merged < checksPassed < checksRunning <
reviewRequested < changesRequested < checksFailed`, so a single failing
check anywhere always outranks everything else). Reordering the cases
changes what the indicator shows without touching any other file.

**GraphQL polling** (`GitHubGraphQLClient.swift`): an `actor` that
builds one batched query per poll rather than one request per repo —
each watched repo is aliased as `repo0`, `repo1`, ... in a single query
string built by `query(for:)`. The response is decoded through
`GraphQLEnvelope`, which uses a custom `DynamicKey: CodingKey` to walk
the `repo0..repoN` keys by index (standard fixed `CodingKeys` can't
express aliased/dynamic field names). `PullRequestNode.resolvedStatus`
is where GitHub's independent signals (merge state, review decision,
head-commit check-suite rollup) collapse into the single
`PullRequestStatus` axis — this is the mapping to touch when GitHub's
actual states turn out to need more nuance than currently modeled.
`adjustPollInterval()` widens the poll interval as the rate-limit
budget (read from the query's own `rateLimit { remaining }` field)
shrinks, rather than polling on a fixed timer regardless of quota.

**Credentials & config**: `KeychainTokenStore` stores the GitHub PAT in
the login Keychain (service `com.robertodevs.gitbeacon`, account
`github-pat`) via Security.framework — not UserDefaults.
`WatchedReposConfig` stores the watched-repo list (`"owner/name"`
strings) in UserDefaults, since it isn't sensitive. Both are read
synchronously from `GitHubGraphQLClient.fetchStatuses`.

**Notifications** (`NotificationService.swift`): `BeaconState.refresh()` diffs
the previous and newly-fetched `pullRequests` by id and fires a local
`UNUserNotificationCenter` notification for any PR that just transitioned
into `.checksFailed` or `.merged` — every other status change is silent.
The very first refresh after launch is exempt (`hasCompletedFirstRefresh`)
so already-failed/merged PRs don't all notify at once on startup.
`AppDelegate` sets itself as the `UNUserNotificationCenterDelegate` and
requests authorization at launch, and implements `willPresent` so banners
still show while GitBeacon itself is frontmost (accessory apps are
otherwise treated as "already visible" and suppressed).

Two separate constraints stack here, both worked around without a full
`.xcodeproj`:
1. `UNUserNotificationCenter.current()` crashes with an uncaught
   `NSInternalInconsistencyException` if `Bundle.main` has no
   `CFBundleIdentifier` — true of any bare SwiftPM executable.
   `Sources/GitBeacon/Info.plist` supplies one, embedded into the binary
   via a `-sectcreate __TEXT __info_plist` linker flag in `Package.swift`
   (`linkerSettings`). SwiftPM does **not** treat that file path as a
   build input, so editing `Info.plist` alone doesn't trigger a relink —
   touch a `.swift` file too, or `rm .build/debug/GitBeacon`, to force one.
2. Even with a valid bundle identifier, `requestAuthorization` still
   fails ("Notifications are not allowed for this application") unless
   the binary is actually running from inside a registered `.app`
   bundle launched via Launch Services (`open`), not exec'd directly.
   `NotificationService` guards its entry points on
   `Bundle.main.bundleIdentifier != nil` so a plain `swift run` degrades
   to a log line instead of crashing, but only `Scripts/run-app.sh`
   (see Commands) satisfies constraint 2 and gets a real notification
   permission prompt.

**Rendering** (`BeaconIndicatorView.swift`): drives two `CAShapeLayer`s
directly on an `NSView` rather than swapping `NSStatusItem.button.image`
— a `dotLayer` for settled colors and a `spinnerLayer` (rotation
`CABasicAnimation`) shown only during `.checksRunning`. Adding a new
`PullRequestStatus` case requires a corresponding branch in
`BeaconIndicatorView.update(status:)` and in `TimelineView.color(for:)`
— the color mapping is duplicated between the two (AppKit `NSColor` in
one, SwiftUI `Color` in the other) since they're rendered through
different frameworks.
