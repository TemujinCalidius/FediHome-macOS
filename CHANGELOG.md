# Changelog

All notable changes to FediHome-macOS are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project aims to follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). At release time, `## Unreleased`
is promoted to the new version and `main` is tagged `vX.Y.Z`.

## Unreleased

### Fixed
- **Notifications are now actionable** — a **Mark all read** button (clears the count + menu-bar
  badge), an unread dot on new items, and clicking a notification opens its post/actor. The DM badge
  also clears as conversations are read.
- **DM conversation list showed raw HTML** in the message preview — now stripped to plain text (the
  thread bubbles were already fixed).
- **Direct messages rendered raw HTML tags** — incoming DM content is now rendered cleanly (via the
  same HTML renderer as posts) instead of showing literal `<p>` tags.
- **Notifications and DMs now refresh on their own** while their section is open (polling), so new
  likes/boosts/replies and incoming messages appear without a manual refresh.
- **Unreadable "Unfollow" button** on the profile card (dark-on-dark) — now a legible bordered button.

### Added
- **Menu-bar presence.** A status-bar item showing unread notification + message counts with quick
  actions (open, jump to a section, New Post, refresh, disconnect), plus native app-menu commands —
  **New Post (⌘N)**, a **Go** menu for the sections (⌘1–⌘5), and **Refresh (⌘R)**.
- **Direct messages.** A Messages section: conversation list grouped by conversation with unread
  indicators, a thread view with message bubbles, an inline reply composer, mark-read on open, and
  starting a new DM by `@handle`. Fediverse DMs; replying to Bluesky DMs isn't supported yet.
- **People.** A People section with **Following / Followers** lists (from `/api/graph`, with counts);
  tap a fediverse person to open their profile card, and **follow someone** by entering
  `@name@server`. Discovery search is blocked on a FediHome endpoint (tracked in #6).
- **Clickable profiles.** Tap a post author's avatar or name (feed or thread) to open a profile card
  with **Follow / Unfollow**, **Block** (confirmed), and **Open in browser**. Full bio/counts/posts is
  blocked on a FediHome profile endpoint (tracked in #5).
- **Compose a new post.** A "New Post" section to publish via Micropub: a note with no title lands in
  the instance's Journal, while adding a title makes it an Article; a live character counter nudges
  long no-title posts toward an Article. Attach photos (uploaded via `/api/media`, shown as thumbnails)
  and optionally save as a draft. Photo captions/galleries, video, and audio compose need a FediHome
  server change (tracked in #4).
- **Reply to a specific person.** The reply composer (feed and thread) is prefilled with the
  target's @handle so a reply is addressed to that person, and the thread's inline reply bar has an
  **@-mention menu** of the other participants to pull a specific person into the reply. Typed
  `@user@domain` mentions federate to those actors.
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
