<!-- Thanks for contributing to FediHome-macOS! -->
<!-- Code PRs target `dev`. Documentation-only PRs may target `main` (apply `skip-changelog`). -->

## Summary

<!-- What does this change do, and why? -->

## How to test

<!-- Steps to verify: build/run the app, what to do, and what you should see.
     Include a screenshot/clip for visible UI behavior. -->

## Checklist

- [ ] Added an entry to **`CHANGELOG.md`** under `## Unreleased` (or applied the `skip-changelog` label if no entry is warranted — e.g. a CI-only or trivial docs change)
- [ ] Build + tests pass (CI is green)
- [ ] **No secrets or personal data added** — tokens live in the Keychain, never in code, logs, or the repo (this repo is destined to be public)
- [ ] **Portable layer stays UI-agnostic** — the API client / data-model package imports no `SwiftUI` or `AppKit` and stays reusable by iOS
