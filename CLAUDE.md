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
  integration) — building and running from Xcode is the normal path
  since this is a GUI app; `swift run` will launch it but without a
  proper app bundle (no Info.plist/icon), which is fine for quick
  iteration on the status item and popover but not representative of a
  packaged build.
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
otherwise treated as "already visible" and suppressed). Critical
constraint: `UNUserNotificationCenter.current()` crashes with an uncaught
`NSInternalInconsistencyException` if the running binary has no bundle
identifier — which is exactly what the raw `swift build`/`swift run`
binary is (no Info.plist). `NotificationService` guards every entry point
on `Bundle.main.bundleIdentifier != nil` and no-ops otherwise; a packaged
`.app` (built via Xcode) is required for notifications to actually fire.

**Rendering** (`BeaconIndicatorView.swift`): drives two `CAShapeLayer`s
directly on an `NSView` rather than swapping `NSStatusItem.button.image`
— a `dotLayer` for settled colors and a `spinnerLayer` (rotation
`CABasicAnimation`) shown only during `.checksRunning`. Adding a new
`PullRequestStatus` case requires a corresponding branch in
`BeaconIndicatorView.update(status:)` and in `TimelineView.color(for:)`
— the color mapping is duplicated between the two (AppKit `NSColor` in
one, SwiftUI `Color` in the other) since they're rendered through
different frameworks.
