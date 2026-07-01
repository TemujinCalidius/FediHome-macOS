# FediHome-macOS

A native **macOS** client for **[FediHome](https://github.com/TemujinCalidius/FediHome)** — the
open-source (MIT), self-hosted, single-user Fediverse app. It connects to the owner's FediHome
instance over HTTP to compose posts, read the timeline / notifications / DMs, and
like / boost / reply — a first-class desktop companion to the web UI.

> This is the **first** of the native clients. The iOS and Android apps will be based on the
> patterns proven here, so keep the **API client + data models cleanly separated and portable**
> (a self-contained Swift package the iOS app can reuse, and whose API contract Android mirrors).

## Status
Greenfield — no app code yet. The repo is **private during pre-1.0 development** and will become
**full open source (MIT), open to contributors, at v1.0**. Everything is being built clean-and-ready
for that: contributor guide, security policy, changelog, issue/PR templates, and the `dev`/`main`
branching model are already in place.

## Key dependency (read this first)
FediHome can **post** today via its **Micropub** endpoint (bearer `AuthToken`; create/update/delete),
plus `/api/media` for uploads. But **reading** (timeline, notifications, DMs, followers,
interactions) is served by a **session-cookie-based admin API** that a native app can't use — so a
**token-authenticated read API must be added on the FediHome side first.** That's the linchpin for
this app (and the iOS/Android ones later). `/api/health` exists for connection testing.

FediHome source: github.com/TemujinCalidius/FediHome (public), local copy at `~/Developer/FediHome`.

## Onboarding (3 paths)
1. Connect a **self-hosted** instance (URL + app token) + link to FediHome docs.
2. Sign in to an **existing hosted** instance.
3. **Sign up** for a new hosted instance.

Hosting-business internals (billing, provisioning) live in the separate **private** `FediHome-Cloud`
repo — **not here**. Payment is web-first; a macOS app shipped outside the Mac App Store (notarized
direct download) takes no Apple cut.

## Contributing
See [`CONTRIBUTING.md`](CONTRIBUTING.md) for setup, code style, and the PR flow. In short:
**code → `dev`, docs → `main`**, and every PR updates [`CHANGELOG.md`](CHANGELOG.md) (or carries the
`skip-changelog` label). Keep the **API client + data models UI-agnostic and portable** — iOS reuses
that package and Android mirrors its contract.

## Security
Found a vulnerability? Please **don't** open a public issue — report it privately via
**Security → [Report a vulnerability](https://github.com/TemujinCalidius/FediHome-macOS/security/advisories/new)**.
See [`SECURITY.md`](SECURITY.md) for the coordinated-disclosure policy and scope. (Vulnerabilities in
the FediHome *server* go to the [FediHome repo](https://github.com/TemujinCalidius/FediHome) instead.)

## License
Private and all-rights-reserved during pre-1.0 development. FediHome-macOS will be released under the
**MIT License** (matching FediHome) when the repo goes public at v1.0.
