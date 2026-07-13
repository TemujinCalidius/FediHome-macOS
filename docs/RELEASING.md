# Releasing FediHome for macOS

This is the maintainer runbook for cutting a release, shipping the **direct notarized download**
(GitHub Releases — the primary channel, no Apple cut), and submitting to the **Mac App Store**.

> **Prerequisite:** an active **Apple Developer Program** membership, with a **Developer ID
> Application** certificate (for direct download) and an **Apple Distribution** certificate (for the
> App Store) installed in your login keychain. Xcode → Settings → Accounts → *Manage Certificates*
> creates them.

---

## 1. Versioning

- `MARKETING_VERSION` in [`project.yml`](../project.yml) is the user-facing version (e.g. `1.0.0`),
  surfaced as `CFBundleShortVersionString`.
- `CURRENT_PROJECT_VERSION` is the build number (`CFBundleVersion`). **The App Store rejects a
  reused build number**, so bump it (`1` → `2` → …) for every App Store upload, even a resubmission
  of the same marketing version. The direct-download DMG doesn't care.

Semver: **MAJOR** = breaking, **MINOR** = backward-compatible feature, **PATCH** = fix.

---

## 2. Cut the release (git)

FediHome uses a `dev`/`main` model: all code lands on `dev`; a release is a `dev` → `main`
**merge commit** (never a squash — the branches must stay in sync).

The changelog's **`## Unreleased`** accumulator lives on **`dev` only**. `main`'s CHANGELOG must
show **only released versions** — never a pending/`## Unreleased` section (it's confusing on the
released branch). To keep it that way, promote the accumulator *before* merging to `main`, and add
the fresh empty one back to `dev` *after*:

```bash
# 0. Make sure dev is green and you've tested locally (⌘R).
git checkout dev && git pull --ff-only

# 1. Promote the changelog on dev: rename "## Unreleased" to "## X.Y.Z — YYYY-MM-DD"
#    (do NOT add a fresh "## Unreleased" yet), and bump MARKETING_VERSION in project.yml. Commit.

# 2. Merge dev → main as a MERGE COMMIT. Because dev's top is now "## X.Y.Z" (not a bare
#    accumulator), main receives only released versions.
git checkout main && git pull --ff-only
git merge --no-ff dev -m "release: vX.Y.Z"

# 3. Tag and push.
git tag -a vX.Y.Z -m "FediHome vX.Y.Z"
git push origin main --follow-tags

# 4. Back on dev, add a fresh empty "## Unreleased" at the top for the next cycle. dev-only.
git checkout dev
#    …edit CHANGELOG.md: add "## Unreleased" above "## X.Y.Z"…
git commit -am "chore: open the next changelog cycle"
git push origin dev
```

> If a `dev` → `main` merge ever surfaces a bare `## Unreleased` on `main` (e.g. step 1 was
> skipped), just delete that section from `main`'s CHANGELOG — `main` lists released versions only.

---

## 3. Direct download — notarized DMG (primary channel)

Everything is scripted in [`scripts/package-macos.sh`](../scripts/package-macos.sh). It archives,
signs with **Developer ID**, notarizes, staples, builds a DMG, and verifies Gatekeeper. Nothing
personal is committed — it reads your identifiers from the environment.

**One-time:** store your notary credentials (an App Store Connect API key is simplest):
```bash
# Create an API key in App Store Connect → Users and Access → Integrations → App Store Connect API.
export DEVELOPMENT_TEAM=ABCDE12345           # your 10-char Team ID
export NOTARY_KEY_ID=XXXXXXXXXX
export NOTARY_KEY_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export NOTARY_KEY_PATH=~/keys/AuthKey_XXXXXXXXXX.p8
# (Alternatively: xcrun notarytool store-credentials fedihome --team-id "$DEVELOPMENT_TEAM" \
#   --apple-id you@example.com --password <app-specific-password>   then export NOTARY_PROFILE=fedihome)
```

**Build it:**
```bash
./scripts/package-macos.sh          # → build/FediHome-X.Y.Z.dmg (notarized + stapled)
```

Verify on a "clean" state (simulate a fresh download): the script runs `spctl`, but you can also
`xattr -w com.apple.quarantine "0081;0;;" build/FediHome-*.dmg` then open it — Gatekeeper should
accept it with no warning.

**Publish the GitHub Release** with the DMG attached:
```bash
gh release create vX.Y.Z build/FediHome-X.Y.Z.dmg \
  --title "FediHome vX.Y.Z" \
  --notes-file <(sed -n '/## X.Y.Z/,/## /p' CHANGELOG.md | sed '$d')
```
(Or let Claude do the `gh release create` step once you hand over the built DMG path.)

**First-launch note for users** (put this on the download page): a notarized, stapled app opens
normally. If a user ever sees a Gatekeeper prompt (e.g. an un-stapled build), they right-click the
app → **Open** once.

---

## 4. Mac App Store submission (fast follow)

The app is already **sandbox-clean**, hardened-runtime on, category set (Social Networking), icon
complete, and `ITSAppUsesNonExemptEncryption=false` — so there are no code changes. The remaining
steps are all in Apple's portals (only you can do these — they need your account):

1. **Register the bundle id** `social.fedihome.macos` at
   [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list) (Identifiers).
2. **Create the app record** in [App Store Connect](https://appstoreconnect.apple.com) → Apps → **+**:
   platform macOS, name **FediHome**, primary language, bundle id, SKU. Category: **Social
   Networking** (already declared in the build).
3. **Privacy nutrition label:** answer **"Data Not Collected."** The app stores your OAuth token in
   the **Keychain** on-device, sends data only to *your own* instance, and has **no analytics or
   tracking** — a genuine privacy selling point. (Under App Privacy, decline all data-collection
   categories.)
4. **Export compliance:** the build's `ITSAppUsesNonExemptEncryption=false` (HTTPS only, exempt)
   auto-answers this — no annual questionnaire.
5. **Build the package** and upload:
   ```bash
   # bump CURRENT_PROJECT_VERSION in project.yml first if this repeats a marketing version
   ./scripts/package-macos.sh appstore     # → build/export/FediHome.pkg
   ```
   Upload with **Transporter** (Mac App Store app) or:
   ```bash
   xcrun altool --upload-app -f build/export/FediHome.pkg -t macos \
     --apiKey "$NOTARY_KEY_ID" --apiIssuer "$NOTARY_KEY_ISSUER_ID"
   ```
6. **Screenshots** (App Store Connect requires at least one macOS size): capture from the running
   app at **1280×800** or **2560×1600** (16:10). Good shots: the feed, compose, a profile, My Posts.
7. **Metadata:** description, keywords, support URL (the repo or fedihome.social), a marketing URL
   (the demo site's download page — see the FediHome website issue).
8. **Submit for review.** First macOS reviews typically take 1–3 days. TestFlight for macOS is
   optional if you want a beta round first.

---

## 5. Optional — CI release workflow (later)

For now the release is cut locally with the script above (you hold the certs). If you later want a
tag-triggered CI build, add a `release.yml` that imports a base64 `.p12` cert + notary creds from
**GitHub Actions secrets** and runs `scripts/package-macos.sh`. Deferred — the local path is simpler
and keeps signing material off CI.
