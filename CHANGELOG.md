# Changelog

All notable changes to FediHome-macOS are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project aims to follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). At release time, `## Unreleased`
is promoted to the new version and `main` is tagged `vX.Y.Z`.

## Unreleased

### Added
- **Sign in with an access token.** The Connect screen gains an "Advanced — sign in with a token"
  option: paste your instance URL and a personal access token to connect directly, skipping the
  OAuth browser round-trip. Useful for scoped, revocable tokens (e.g. a read-only reviewer token)
  and headless setups. (#60)
- **Category dropdown in compose.** The photo/video/audio gallery **Category** fields now offer a
  dropdown of your instance's existing categories (friendly labels) alongside free typing, and typed
  categories are slugified so a multi-word name like "Photo walk" posts as `photo-walk` instead of
  silently falling back to "general". Needs a FediHome instance that exposes `mediaCategories`
  (dev/#284); older instances keep plain free-text entry. (#61)

### Fixed
- **"My Posts" now previews untitled notes.** A microblog note (no title) used to show as a bare
  "Untitled note"; the row now shows the note's body text so you can tell your posts apart. Needs a
  FediHome instance on v1.15.0+ (which returns a post `preview`). (#59)

## 1.0.1 — 2026-07-13

### Fixed
- **The feed no longer crashes on posts with an inline video.** Video playback now uses AppKit's
  `AVPlayerView` instead of SwiftUI's `VideoPlayer`, which could crash during feed layout on some
  macOS/toolchain combinations (a Swift metadata fault inside `_AVKit_SwiftUI`). The native player
  also brings inline controls, full-screen, and Picture-in-Picture.

## 1.0.0 — 2026-07-13

First public release — a feature-complete native macOS client for FediHome.

### Added
- **Edit your own posts.** My Posts rows gain **Edit…** — the composer opens prefilled (title,
  text, description) in edit mode and saving federates an update. Attached media is kept as-is
  (text-only edits can't touch it). Needs a FediHome instance on the current dev (#31).
- **Edit your profile from the app.** Me → **Edit Profile**: change your avatar and banner (pick an
  image — it uploads and applies), display name, tagline, website bio, fediverse bio, and accent
  color. Your instance saves the changes and **federates an actor update** so Mastodon and friends
  refresh your profile. (#29)
- **Badge & banner hardening** (from a verified multi-agent review): polling now lives in the
  menu-bar item, so badges and banners genuinely keep working with the window closed; clicking a
  banner reopens the window; one DM no longer banners twice; dedupe is ID-based and per-instance
  (late-arriving federated items still announce, switching accounts neither replays nor swallows);
  items you're already viewing or have marked read never banner; disconnect clears the badges; and
  Settings warns when macOS notification permission is denied.
- **Native notification banners.** New likes/boosts/replies/follows and incoming DMs pop a real
  macOS banner while the app runs (window can be closed — the menu-bar poll is the engine);
  clicking one jumps to the right section. First launch never replays history, and a Settings
  toggle turns banners off without building up a backlog blast.
- **Dock icon badge.** The Dock icon now shows the classic red unread bubble (notifications +
  messages combined), kept in sync with the menu-bar counts and clearing on mark-read/disconnect.
  Toggle it in Settings → General. (#38)
- **App icon.** The app finally has one — a blue rounded-square with the FediHome house (generated
  placeholder; `scripts/generate-appicon.swift` regenerates it, and designed art can replace the
  PNGs later).
- **Settings window (⌘,).** Tune how often Notifications, Messages, and the menu-bar badge check
  for new items; set the timeline's default reply/boost filters; toggle remembering your last
  section on launch.
- **Reply to Bluesky DMs.** The message composer now works in Bluesky conversations too (routes via
  the instance's Bluesky bridge); the "isn't supported yet" notice is gone. Starting a *new* Bluesky
  conversation still happens on Bluesky itself for now.
- **Edit your own replies.** In a thread, your replies now show a pencil — the reply bar switches
  to edit mode (prefilled), and saving federates the update.
- **Block list & unblock.** People gains a **Blocked** tab listing everyone you've blocked, with an
  **Unblock** button (confirmed; federates the Undo). After blocking from a profile card, the card
  offers Unblock right there. Older instances without block tracking still work (empty tab).
  (Closes the app side of #12.)
- **Full profiles & finding people.** Profile cards now show the person's **header, bio, and
  follower/following/post counts** (plus a "Follows you" badge), powered by the new profile
  endpoint. The People search field resolves any `@name@server` into a **discovery card** you can
  follow from — including people your instance has never seen. Older instances gracefully fall
  back to the lightweight card / direct follow. (Closes the app side of #5 and #6.)
- **My Posts.** A content manager for your instance (⌘6): every post — published, **scheduled**
  (with its publish time), and **drafts** — with type filters (notes/articles/journal/photo/video/
  audio), like/boost counts, media summaries, open-in-browser, and **delete** (a scheduled post's
  delete doubles as *cancel*). (Closes the app side of #15.)
- **Photo captions & galleries, video and audio posts.** Photos get a per-image **caption** field and
  an **"Add to photo gallery"** toggle (with optional category); **Add Video** takes a
  PeerTube/MakerTube/YouTube/Vimeo URL (the app derives the embed automatically) with an
  **"Add to videos gallery"** toggle; **Add Audio** uploads MP3s (title per track, duration shown)
  with an **"Add to audio gallery"** toggle — matching the instance's Photography/Videos/Audio
  sections. (Closes the app side of #4.)
- **Article descriptions & scheduled posts.** Composing now uses FediHome's rich compose API:
  adding a title reveals a **Description** field (the article's excerpt, ~300 chars), a **Schedule
  for later** toggle publishes the post server-side at the chosen time (it lives on your instance,
  not in the app), and **Bluesky/Threads cross-posting** is now an explicit per-post toggle. Drafts
  still save via Micropub and carry the description as their excerpt. (Closes the app side of #14
  and #18; needs a FediHome instance on the current dev.)
- **Feed & notification filters.** A timeline filter to show/hide **replies** and **boosts**
  (re-queries `/api/feed`), and a **notifications** filter (all / replies & mentions / likes /
  boosts / follows / messages).
- **Your profile ("Me").** Tap the account footer to open your own profile card — banner, avatar, bio,
  and follower/following/post counts — with a button to open your instance in the browser.
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

### Changed
- **CI runs on `macos-15`.** The GitHub Actions runner moved off the now-deprecated `macos-14`
  image to `macos-15` (the current `macos-latest`). The Swift 6 / Xcode 16 toolchain pin is
  unchanged — that image still ships Xcode 16.4, which the `Xcode_16*` selector resolves to.
  CI-only; no app behaviour changes.
- **CI** — a GitHub Actions workflow builds the app and runs the FediHomeKit package tests on every
  PR to (and push to) `dev`/`main` (XcodeGen-generated project, Xcode 16 / Swift 6).

### Fixed
- **Edit-features hardening** (from a verified multi-agent review): starting an edit while a new
  post is in progress asks before discarding it; profile bios are flattened to a single paragraph
  (the server rejects line breaks) and the saved profile is shown authoritatively even when a field
  reverts to the site default; an avatar/banner upload can't land in the wrong slot if you switch
  mid-upload; the article/note badge no longer implies clearing a title converts the post; and a
  failed Edit no longer leaves a stale error on the next New Post.
- **Thread refresh failures are no longer silent** — if the reload after sending/editing a reply
  fails, an alert explains the view may be stale (the change itself was sent).
- **Icon generator is display-independent** — regenerating on a Retina Mac no longer produces
  wrongly-sized PNGs (renders into exact-pixel bitmaps and self-checks dimensions).
- **Empty pages now start from the top** like every other page — loading, error, and empty states
  across Feed, Notifications, People, Messages, My Posts, and threads were vertically centered.
- **Images are cached** (memory + disk), so avatars and feed media stop re-downloading on every
  scroll and relaunch.
- **The app remembers your last section** across launches instead of always opening on Feed.
- **Compose correctness sweep** (from a verified multi-agent review): posting is now blocked with a
  visible reason when the server would reject it (empty text, unfinished video URL, past schedule
  time); a draft in progress **survives switching sidebar sections**; saving a draft says "Draft
  saved" (not "Posted"); unreadable files and unsupported image types are surfaced instead of
  silently skipped; filenames with quotes no longer corrupt uploads.
- **Video-link detection tightened** — Wikipedia-style `/w/…` pages and lookalike domains
  (`notvimeo.com`) are no longer treated as embeddable videos, in compose and in the feed.
- **My Posts** — changing filters mid-scroll can't mix pages from the old filter anymore, and
  delete/paging failures show a dismissible banner instead of failing silently.
- **People/profiles** — follow/unfollow/block from a person's popover now refreshes the lists, and
  an expired session during a profile load triggers reconnect instead of a wrong "Follow" state.
- **Read notifications no longer resurrect themselves** — a stale in-flight poll could overwrite a
  just-completed *mark all read* (and the menu-bar badge); loads now discard superseded responses
  (same guard added to the feed and DM loads).
- **Compose no longer loses text typed while posting** — the editor is disabled during an in-flight post.
- **Notification avatars** now resolve relative paths against the instance URL (were sometimes blank).
- **Menu-bar "Open" reuses the existing window** instead of occasionally opening a duplicate.
- **Clicking a notification no longer errors (-50)** — relative target paths (e.g. `/post/slug`) are
  resolved against the instance URL before opening.
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

### Security
- **Editing is restricted to published posts**, so an edit can't federate an unpublished draft or
  scheduled post's content to your followers — defense-in-depth alongside a coordinated server-side
  fix in FediHome (advisory GHSA-x3j3-ghcw-8r77).
