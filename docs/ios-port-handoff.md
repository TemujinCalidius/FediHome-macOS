# iOS/iPadOS port — handoff brief

This is the starting brief for a **new session** that ports FediHome from macOS to **iOS + iPadOS**
(a new repo, `FediHome-iOS`), following the same "macOS-first, share the portable core" pattern.
Android mirrors the same API contract later.

Paste the **Handoff prompt** below into the new session. The rest of this doc is the supporting map.

---

## Handoff prompt (paste this)

```
Port the FediHome macOS client to iOS + iPadOS as a new app, FediHome-iOS, reusing the shared
Swift package unchanged. The macOS app is at ~/Developer/FediHome-macOS (private, pre-1.0→1.0);
study it as the reference implementation. Follow its conventions: XcodeGen project (project.yml,
.xcodeproj git-ignored), FediHomeKit as the portable UI-agnostic layer, OAuth 2.0 + PKCE with the
token in Keychain, dev/main branching with one PR per phase and CI (swift test + xcodebuild) green
before self-merge to dev, a CHANGELOG entry per PR, and "public-clean" from day one (no secrets in
git). Build a plan first, phase it, and verify each phase.

Key facts (audited):
- FediHomeKit (Packages/FediHomeKit) is 100% platform-agnostic — zero AppKit, already declares
  .iOS(.v17). REUSE IT AS-IS: add the package as a dependency; do not fork it. Any change needed
  there is a real portability bug — fix it in place and it benefits macOS too.
- Only 6 files in the macOS App/ target touch AppKit (~10 call sites). Everything else is SwiftUI
  and ports directly. The hard part is re-authoring the SCENE GRAPH and re-homing the background
  POLLING ENGINE, plus an iPhone TabView.

Deliver, phased:
1. Repo + project scaffold: FediHome-iOS, XcodeGen project (iOS 17+), FediHomeKit dependency, CI
   workflow (swift test on the package + xcodebuild for the app on an iOS Simulator destination),
   CONTRIBUTING/SECURITY/CHANGELOG mirrored from macOS.
2. App shell: WindowGroup + RootView (Connect ↔ Main), driven by the SAME Navigator/AppSection
   (6 sections). iPhone = TabView (compact); iPad = NavigationSplitView (reuse the macOS layout).
   Relax the fixed .frame(width:) sizes used on macOS.
3. Auth: reuse SessionStore, KeychainStore, AuthController, OAuthClient. Only change:
   AuthController's ASPresentationAnchor (return the key UIWindow from the active UIWindowScene
   instead of NSApp.keyWindow), and import UIKit.
4. Re-home the polling engine: on macOS it lives on the MenuBarExtra label (survives window
   close). On iOS use a foreground .task while active + BGTaskScheduler / BGAppRefreshTask for
   background refresh; drive badge + banners from there. Dock badge → UNUserNotificationCenter
   badge / UIApplication.shared.applicationIconBadgeNumber (or setBadgeCount).
5. Platform shims (small): NSImage→UIImage, NSColor→UIColor (hex round-trip in EditProfileView),
   WebVideoPlayer NSViewRepresentable→UIViewRepresentable (drop allowsMagnification), and prefer
   PhotosPicker over .fileImporter for images. A tiny PlatformImage/Color(hex) helper covers most.
6. Port the content views (they're SwiftUI already): Feed, Notifications, People, Messages,
   MyPosts, Thread, Compose, Profile/Me, EditProfile, ImageViewer, PostRow/Content, InteractionBar,
   InlineReplyBar. Convert .popover(arrowEdge:) to .sheet on iPhone. Drop .help() tooltips (no-op).
7. Settings: the macOS Settings scene (⌘,) becomes a Settings tab/screen; reuse the Prefs keys.
8. Verify on iPhone + iPad simulators; adversarial review each phase like the macOS build did.

Cross-platform already (reuse, no change): FediHomeKit, KeychainStore, SessionStore, the 7
ViewModels, InstanceURL/Prefs/PostInteracting, VideoPlayerView (AVKit), ImageViewer, RootView,
ConnectView, AsyncAvatar, URLSession/URLCache, UNUserNotifications (minus 2 NSApp.activate calls),
ASWebAuthenticationSession + PKCE.

Do NOT touch the macOS repo except to fix a genuine FediHomeKit portability bug (as its own PR).
```

---

## Supporting map (from the macOS portability audit)

### Reuse as-is (no changes)
- All of `Packages/FediHomeKit/**` (models, `FediHomeClient`, `OAuthClient`, PKCE, `FediHTML`,
  `VideoEmbed`, `MediaURL`).
- `App/Auth/KeychainStore.swift`, `App/Auth/StoredToken.swift`, `App/State/SessionStore.swift`.
- `App/Support/InstanceURL.swift`, `Prefs.swift`, `PostInteracting.swift`.
- All 7 `App/ViewModels/*`.
- `App/Views/VideoPlayerView.swift` (AVKit), `ImageViewer.swift`, `RootView.swift`,
  `ConnectView.swift`, `AsyncAvatar.swift`.
- Most content views — SwiftUI only (caveats below).

### Needs a small platform tweak (`#if os` / one-line swap)
| File | Site | Change |
|---|---|---|
| `App/Auth/AuthController.swift` | `:98` `NSApplication.shared.keyWindow` | key `UIWindow` via `UIWindowScene`; `import UIKit` |
| `App/Support/NotificationManager.swift` | `:96` `NSApp.activate` | drop; `import UIKit` |
| `App/State/Navigator.swift` | `:154` `NSApp.dockTile.badgeLabel` | `UNUserNotificationCenter`/`setBadgeCount`; `import UIKit` |
| `App/Views/EditProfileView.swift` | `:142,154,276` `NSImage`/`NSColor` | `UIImage`/`UIColor` |
| `App/Views/ComposeView.swift` | `:291` `NSImage` thumbnail + `.fileImporter` | `UIImage`; prefer `PhotosPicker` |
| `App/Views/WebVideoPlayer.swift` | whole file `NSViewRepresentable` | `UIViewRepresentable`; drop `allowsMagnification` |

### macOS-only — needs an iOS counterpart (rewrite)
- `App/FediHomeApp.swift` — `Window` + `Settings` + `MenuBarExtra` scene graph → `WindowGroup` +
  TabView (iPhone) / SplitView (iPad) + a Settings screen; **relocate the polling engine** off the
  menu-bar label to `.task` + `BGTaskScheduler`.
- `App/Views/MenuBarContent.swift` — delete; fold its actions (go-to-section, refresh, disconnect)
  into the tab bar / a toolbar menu.
- `App/Views/MainView.swift` — keep `NavigationSplitView` for iPad; add a compact `TabView` branch
  for iPhone (both driven by the existing `Navigator.section` / `AppSection`).
- Project config: new `project.yml` (`platform: iOS`, deployment 17.0), `Info.plist`
  (no `NSPrincipalClass`; `UILaunchScreen`), and iOS entitlements (drop the macOS sandbox keys;
  add push/background modes if used). `NSPhotoLibraryUsageDescription` if `PhotosPicker` needs it.

### Navigation
- `AppSection` (`App/State/Navigator.swift`): 6 cases — `feed, notifications, compose, people,
  messages, myPosts` (`CaseIterable`), already built to be driven from multiple entry points →
  clean fit for a `TabView`. Nested `NavigationStack` already used in DMs/Thread → transfers.
