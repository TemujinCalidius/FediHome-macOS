# FediHome for macOS

A native **macOS** client for **[FediHome](https://github.com/TemujinCalidius/FediHome)** — the
open-source, self-hosted, single-user Fediverse app. Read your timeline, notifications, and DMs;
compose posts with photos, video, audio, scheduling and drafts; manage your profile and content;
and get native notifications — a first-class desktop companion to your instance, living in your
menu bar.

[![Mac App Store](https://img.shields.io/badge/Mac_App_Store-Download-0D96F6?logo=apple&logoColor=white)](https://apps.apple.com/app/id6790605091)
[![Direct Download](https://img.shields.io/badge/Direct_Download-macOS_14%2B-blue)](https://github.com/TemujinCalidius/FediHome-macOS/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Sponsor](https://img.shields.io/badge/Sponsor-❤-ea4aaa)](https://github.com/sponsors/TemujinCalidius)

## Download

- 🍎 **[Mac App Store](https://apps.apple.com/app/id6790605091)** — one-click install with automatic updates. **Free.**
- 💾 **[Direct download (`.dmg`)](https://github.com/TemujinCalidius/FediHome-macOS/releases/latest)** — a **notarized** disk image, no Apple account needed. Open it, drag **FediHome** to Applications, and launch.

Requires **macOS 14 (Sonoma) or later**. Both are Apple-notarized, so they open with no security warnings.

## Features

- **Read** — your private timeline (with media, boosts, and interaction counts), notifications, and
  direct messages, all refreshing on their own.
- **Post** — notes and articles via Micropub and FediHome's rich compose API: **photos** (with
  captions + galleries), **video** (by URL — the embed is derived automatically), **audio** (MP3
  uploads), an article **description/excerpt**, **schedule-for-later**, drafts, and explicit
  Bluesky/Threads cross-posting.
- **Interact** — like, boost, and reply from the feed or a full thread view; edit your own posts and
  replies; a native share button.
- **People & DMs** — following/followers, full profile cards (bio, header, counts, "follows you"),
  find people by `@handle`, block/unblock, and fediverse **and Bluesky** direct messages.
- **Manage** — a **My Posts** manager (published / scheduled / drafts, with delete & cancel), and
  **Edit Profile** (avatar, banner, name, bio, accent color — federated as an actor update).
- **Native macOS** — a **menu-bar** presence with unread counts, a **Dock badge**, **notification
  banners**, a full-screen photo viewer, inline video playback, rich (dark-mode-correct) rendering,
  a **Settings** window, and keyboard shortcuts.

Your data stays yours: the app talks only to **your** instance over HTTPS, stores its access token
in the **Keychain**, and sends nothing to anyone else — no analytics, no tracking.

## Build from source

The app is built with [XcodeGen](https://github.com/yonaskolb/XcodeGen) (the `.xcodeproj` is
generated, not committed):

```bash
git clone https://github.com/TemujinCalidius/FediHome-macOS.git
cd FediHome-macOS
brew install xcodegen
xcodegen generate
open FediHome.xcodeproj   # then ⌘R
```

Requires **Xcode 16+** (Swift 6). On first launch, enter your instance URL and sign in via OAuth —
you authenticate on your own site and the app stores a scoped token in the Keychain.

## Architecture

FediHome-macOS is the **first** of the native clients. The networking + data-model layer is a
standalone, UI-agnostic Swift package — **`FediHomeKit`** — that the coming **iOS/iPadOS** app reuses
directly and **Android** mirrors. Keep that package free of UI framework imports; the macOS UI
depends on it, not the other way around.

## Contributing

Contributions are welcome! See [`CONTRIBUTING.md`](CONTRIBUTING.md) for setup, code style, and the PR
flow. In short: **code → `dev`, docs → `main`**, every PR updates [`CHANGELOG.md`](CHANGELOG.md) (or
carries the `skip-changelog` label), and CI must be green. Keep the `FediHomeKit` layer portable.

## Sponsor

If FediHome for macOS is useful to you, please consider
**[❤ sponsoring the project](https://github.com/sponsors/TemujinCalidius)** — it directly supports
continued development and the upcoming iOS and Android clients.

## Security

Found a vulnerability? Please **don't** open a public issue — report it privately via
**Security → [Report a vulnerability](https://github.com/TemujinCalidius/FediHome-macOS/security/advisories/new)**.
See [`SECURITY.md`](SECURITY.md) for the coordinated-disclosure policy. (Vulnerabilities in the
FediHome *server* go to the [FediHome repo](https://github.com/TemujinCalidius/FediHome) instead.)

## License

Released under the **[MIT License](LICENSE)** — matching FediHome.
