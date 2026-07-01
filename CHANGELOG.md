# Changelog

All notable changes to FediHome-macOS are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project aims to follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). At release time, `## Unreleased`
is promoted to the new version and `main` is tagged `vX.Y.Z`.

## Unreleased

### Added
- **Inline video playback.** Recognized video links (YouTube, Vimeo, and PeerTube/MakerTube via the
  `/w/` and `/videos/watch/` patterns) now show a ▶ poster that plays inline in an embedded web
  player, instead of bouncing to the browser. Unrecognized hosts still open externally, and an
  "open in browser" affordance is always available. Detection lives in `FediHomeKit.VideoEmbed`
  (portable, unit-tested); playback uses `WKWebView`.
- **Full-screen photo viewer.** Click a feed image to open a full-window lightbox — pinch or
  double-click to zoom and pan, arrow keys / on-screen chevrons to move between a post's images, and
  Esc or a click on the backdrop to dismiss. Works in the feed and the thread sheet.
- **Feed media & embeds.** Post images now load (relative proxied `/uploads/fedi/…` paths are
  resolved against the instance base URL), rendered in a grid; direct video files play inline
  (AVKit) while streaming-page links (YouTube/Vimeo) show a "Watch on …" card; single-link posts
  show a link-preview embed card. (Audio isn't carried by the feed, so none is shown.)
- **Post interactions.** Like, boost, and reply from the feed and from a full **thread view**
  (`GET /api/conversation`); lazy **"Load counts"** (`POST /api/fedi-post-counts`); and a native
  **share** button. Like/boost are optimistic and revert on failure; because the server persists
  `likedByMe`/`boostedByMe`, state survives an app relaunch. Write actions correctly target a
  boosted post's **original** apId (resolving the synthetic `boost:…` id), so liking/replying to a
  boost federates to the right object and its button stays lit after reload.
- **Rich post rendering.** Feed content now renders the sanitized `contentHtml` — clickable,
  accent-colored links / @mentions / #hashtags plus bold, italic, strikethrough, code, headings,
  lists, and blockquotes — natively via a Foundation `AttributedString` (dark-mode correct). Handles
  the upstream Mastodon URL-truncation idiom (`<span class="invisible">`/`ellipsis`) so long links
  read `example.com/very/long/url…`. Parsing lives in `FediHTML` in the portable package (scalar-based
  tokenizer, HTML-entity decoding, safe-scheme link validation) and runs off the main thread. Backed
  by a 54-case adversarial regression suite covering malformed markup, entity/unicode edge cases, and
  the Mastodon span idioms.
- **Connect + Feed + Notifications (read MVP).** A native SwiftUI macOS app (macOS 14+) that connects
  to a FediHome instance via **OAuth 2.0 + PKCE (S256)** — the owner signs in on their own site,
  the app stores a scoped bearer token in the **Keychain** (keyed by instance URL, multi-instance
  ready) — then reads the private **feed** (cursor-paged timeline with media, boosts, counts) and
  **notifications** (bell count + items). Instance-URL entry defaults to `https://fedihome.social`.
  Ships a portable, UI-agnostic **`FediHomeKit`** Swift package (typed models + `FediHomeClient` +
  discovery/PKCE/token-exchange helpers) that iOS will reuse and Android mirrors, plus unit tests
  (RFC 7636 PKCE vector + response decoding against real fixtures). Native macOS theming
  (system light/dark + accent); the project is generated with **XcodeGen** (`project.yml`).
- **Repository scaffold** — README, contributor guide (`CONTRIBUTING.md`), security policy
  (`SECURITY.md`), this changelog, issue & PR templates, Dependabot config, a changelog-enforcement
  workflow, and the `dev`/`main` branching model. No app code yet — the repo is being made
  clean-and-ready ahead of its v1.0 open-source release.
