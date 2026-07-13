# Contributing to FediHome-macOS

Thanks for your interest in contributing to FediHome-macOS! This guide will help you get set up
and understand how the project is organized.

FediHome-macOS is a native **macOS** client for [FediHome](https://github.com/TemujinCalidius/FediHome),
the self-hosted, single-user Fediverse app. It's the **first** of the native clients — the iOS and
Android apps will follow the patterns proven here, so the **API client + data models are kept in a
clean, portable, UI-agnostic layer** that iOS can reuse and Android can mirror.

## Prerequisites

- **macOS 14 (Sonoma) or later** — the app's minimum deployment target.
- **Xcode 16+** (Swift 6 toolchain) — to build, run, and test.
- **Git** — for cloning and version control.
- **A FediHome instance + app token** — to run the app against real data. See the FediHome
  [self-hosting docs](https://github.com/TemujinCalidius/FediHome). `/api/health` is handy for
  checking reachability.

## Local Development Setup

1. **Fork & clone the repo:**
   ```bash
   git clone https://github.com/<you>/FediHome-macOS.git
   cd FediHome-macOS
   ```

2. **Generate the Xcode project.** `FediHome.xcodeproj` is git-ignored — `project.yml` is the source
   of truth. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) and run:
   ```bash
   xcodegen generate
   ```
   Re-run this whenever you add/rename files or change `project.yml`.

3. **Open & run.** `open FediHome.xcodeproj`, then build (⌘B) / run (⌘R). The `FediHomeKit` Swift
   package resolves automatically on first open.

4. **Point the app at a FediHome instance.** On the Connect screen, enter your instance URL
   (defaults to `https://fedihome.social`) and sign in via OAuth — the owner authenticates **on their
   own site**, and the app stores a scoped bearer token in the **Keychain** (never a file, log, or
   the repo).

> The **networking + data-model layer is a standalone Swift package** meant to be reused by the iOS
> app. Keep it **UI-agnostic** — no `SwiftUI` / `AppKit` imports in that layer — so it stays
> portable. The macOS UI depends on the package, not the other way around.

## Code Style

- **Swift 6, typed and modern.** Prefer value types, `async/await`, and strict concurrency where
  it's clean. Public API surfaces should have clear, documented types.
- **Keep the portable layer portable.** The API client and models must not import `SwiftUI` or
  `AppKit`, reference macOS-only APIs, or bake in UI concerns — iOS reuses this package and Android
  mirrors its contract.
- **SwiftUI-first for the app**, dropping to AppKit where a native macOS affordance needs it
  (menu-bar item, window management, etc.).
- **Secrets live in the Keychain.** Never log, print, or commit tokens, instance URLs tied to a real
  owner, or any personal data. This repo is destined to be public.
- **Formatting & linting are enforced by CI** once tooling lands (`swift-format` / SwiftLint). Don't
  hand-format around the formatter.

## Branching model

FediHome-macOS uses two long-lived branches:

- **`dev`** — the active development / integration branch. **All code changes land here.**
- **`main`** — the stable, released branch. It only moves when maintainers cut a release (by
  merging `dev` → `main`) or for **documentation-only** changes.

**In short: code → `dev`, docs → `main`.**

- **Code work** (anything under `Sources/`, the app target, the Swift package, workflows, build
  config, dependencies): fork, branch from **`dev`**, and open your PR against **`dev`**.
- **Documentation only** (`README`, `docs/`, `CONTRIBUTING.md`, code comments, typos): you may
  branch from **`main`** and PR against **`main`** — apply the `skip-changelog` label.

Use branch prefixes: `feat/*`, `fix/*`, `docs/*` (e.g. `feat/timeline-view`).

`main` is the default branch, so a fresh PR targets `main` — **retarget code PRs to `dev`.** A code
PR left on `main` will be asked to retarget. Releases are cut by maintainers: `dev` is merged into
`main` (a **merge commit**, not a squash, so the branches stay in sync), `## Unreleased` is promoted
to the new version, and `main` is tagged + a GitHub Release is published.

## Making a Pull Request

1. **Fork** the repository on GitHub.
2. **Create a branch from the right base** — `dev` for code, `main` for docs-only:
   ```bash
   git checkout -b feat/my-feature dev      # code work
   # git checkout -b docs/my-fix main        # documentation only
   ```
3. **Implement your change.** Write clear, typed Swift. Add comments where the "why" isn't obvious.
   Keep the portable API/model layer free of UI imports.
4. **Test locally.** Build and run the app, and run the same checks CI does:
   ```bash
   swift test            # package unit tests
   xcodebuild -scheme FediHome-macOS build   # app build
   ```
5. **Commit** with a clear message describing what the change does and why:
   ```bash
   git commit -m "Add timeline pagination to the read client"
   ```
6. **Push** and open a pull request against **`dev`** (or `main` for documentation-only changes):
   ```bash
   git push origin feat/my-feature
   ```
7. In the PR description, explain what the change does, why it's needed, and how to test it. Add a
   screenshot/clip for anything visible in the UI.

**Changelog (required).** Every pull request must add an entry to [`CHANGELOG.md`](CHANGELOG.md)
under the `## Unreleased` heading (create it if missing), grouped under
`### Added` / `### Changed` / `### Fixed` / `### Security`, with `(#N)` referencing the issue or PR.
CI enforces this. If a change genuinely warrants no entry (a docs-only PR, a CI-config tweak, a typo
fix), apply the `skip-changelog` label to bypass the check. At release time, `## Unreleased` is
renamed to the new version.

**Tracking staged fixes (`fixed-pending-merge`).** When a PR implements the fix for an open issue or
a security alert (Dependabot / code-scanning), maintainers label it `fixed-pending-merge` (and the
issue it closes), so it's easy to see at a glance which problems are fixed and just waiting on a
merge. The label needs no cleanup: on merge the PR closes and any linked issue auto-closes via a
`Closes #N` reference.

**Closing multiple issues from one PR.** Give each issue its own keyword — `Closes #1, Closes #2` —
not `Closes #1, #2`. GitHub only auto-links the number that directly follows a closing keyword, so
the bare `#2` in the second form won't auto-close.

## Issue Templates

File issues with the forms in `.github/ISSUE_TEMPLATE/`:

- **Bug report** — include a clear repro, expected behavior, the app version, your macOS version,
  and how you connect (self-hosted vs hosted instance), plus any Console output.
- **Feature request** — describe the capability, the use case, and which area of the app it touches.

Open-ended questions and "how do I…?" go to
[Discussions](https://github.com/TemujinCalidius/FediHome-macOS/discussions), not Issues.

## Reporting a security issue

Found a vulnerability? **Don't open a public issue, PR, or discussion** — that discloses it before a
fix exists. Report it privately via
[**Security → Report a vulnerability**](https://github.com/TemujinCalidius/FediHome-macOS/security/advisories/new).
See [`SECURITY.md`](SECURITY.md) for the full coordinated-disclosure policy, supported versions, and
scope.

## Code of Conduct

FediHome-macOS is a small project, and we want to keep the community welcoming for everyone.

- **Be kind.** Assume good intent. Disagree respectfully.
- **Be inclusive.** Welcome newcomers. Avoid jargon without explanation.
- **Be constructive.** When reviewing code, suggest improvements rather than just pointing out
  problems. Explain why.
- **No harassment, discrimination, or personal attacks.** This includes issues, PRs, Discussions,
  and any project communication channels.

If someone's behavior makes you uncomfortable, reach out to the maintainers. We will address it.
