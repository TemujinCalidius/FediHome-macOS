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

**Publish the GitHub Release** with the DMG attached. `--discussion-category "Announcements"` also
posts a linked **announcement** in the Discussions tab automatically:
```bash
gh release create vX.Y.Z build/FediHome-X.Y.Z.dmg \
  --title "FediHome vX.Y.Z" \
  --discussion-category "Announcements" \
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

## 5. App Store upload from CI (no local Xcode needed)

The **[`App Store` workflow](../.github/workflows/release-appstore.yml)** builds, signs, and uploads
to App Store Connect on a GitHub-hosted macOS runner (release Xcode + release macOS). Use it when
your local machine can't produce an App-Store-valid build (e.g. you're on a macOS/Xcode **beta** —
Apple rejects beta-built binaries). It's **free** on this public repo (unlimited standard-runner
minutes). It signs with **Apple Distribution** and stamps a unique build number
(`CURRENT_PROJECT_VERSION = the run number`), so re-uploads never collide.

### One-time — Apple portal
1. Register the bundle id **`social.fedihome.macos`** at
   [Identifiers](https://developer.apple.com/account/resources/identifiers/list).
2. Create the **App Store Connect app record** (macOS · name · bundle id · SKU).
3. Create an **Apple Distribution** certificate (Xcode → Settings → Accounts → Manage Certificates →
   `+` → *Apple Distribution*, or on the portal). Then in **Keychain Access**, export it *with its
   private key* as a password-protected **`.p12`**.
4. Create an **App Store Connect API key** ([Users and Access → Integrations →
   App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api)) with the
   **App Manager** role. Download the **`.p8`** (one-time) and note its **Key ID** + **Issuer ID**.

### One-time — GitHub secrets (set them yourself; the values never leave your machine)
Run these locally (each `--body`/prompt keeps the value on your machine and sends it straight to
GitHub — Claude never sees them):
```bash
gh secret set DIST_CERT_P12_BASE64  < <(base64 -i /path/to/Distribution.p12)
gh secret set DIST_CERT_PASSWORD                     # paste the .p12 export password
gh secret set ASC_KEY_P8_BASE64     < <(base64 -i /path/to/AuthKey_XXXX.p8)
gh secret set ASC_KEY_ID                             # the API Key ID
gh secret set ASC_ISSUER_ID                          # the API Issuer ID
gh secret set APPLE_TEAM_ID                          # your 10-char Team ID
```

### Each upload
Actions tab → **App Store** → **Run workflow** (or `gh workflow run "App Store"`). It archives,
provisions via the API key (`-allowProvisioningUpdates`), and uploads. Then finish in App Store
Connect: pick the build, add screenshots (1280×800 / 2560×1600), set the privacy label to
**"Data Not Collected"**, and submit for review.

> The local `./scripts/package-macos.sh appstore` path (§4) still works if you ever have a release
> Xcode locally — but the CI workflow is the beta-proof, zero-setup-per-release option.

---

## 6. App Review Information (App Store Connect)

Apple reviews **every** new build before public release, so set this once — it carries forward
to each update. In App Store Connect → the version → **App Review Information**:

- **Sign-In required:** ✅
- **User Name:** `admin` (FediHome has no username — clarified in the notes)
- **Password:** the demo instance's **admin secret** — paste it straight into ASC; **never commit it**
- **Contact:** your name / phone / email
- **Notes:** the template below

**Access approach.** FediHome signs in via OAuth, whose authorize step uses the site's
`ADMIN_SECRET`. For **v1.0** we hand the reviewer the **demo** instance's `ADMIN_SECRET`
(`fedihome.social` is a throwaway test server) and **rotate it after approval**. Longer term,
replace this with a **scoped, revocable reviewer token** — no master key, no per-update rotation —
once **FediHome#255** (admin "generate scoped app token") and **FediHome-macOS#60** (sign in with a
token) ship. Then the same token stays in the notes across every future update.

**Review-notes template** (the secret lives only in the Password field — nothing sensitive here):

```
ABOUT
FediHome is a native macOS menu-bar client for FediHome — a self-hosted, single-user
Fediverse (ActivityPub) server, similar to how a mail client connects to your own mail
server. The account you sign into is the single owner account for one specific instance;
FediHome is one-account-per-instance by design. The app creates no account with the
developer and connects only to the instance you point it at, over HTTPS. The access
token is stored in the macOS Keychain.

HOW THE FEED WORKS
The timeline is a plain, chronological feed of posts from the accounts the instance
owner follows — nothing else. There is no recommendation algorithm, no "suggested" or
promoted content, no engagement ranking, and no infinite-scroll or notification
mechanics designed to maximize time in the app. It is simply people's own posts in the
order they were made — much like an RSS reader. (This demo account already follows
several accounts, so the feed is populated.)

HOW TO SIGN IN (demo instance provided)
1. Launch FediHome — it appears in the menu bar and opens the main window.
2. When prompted for an instance, enter:  https://fedihome.social
3. You'll be taken to that site's own sign-in page. There is no username — enter the
   admin secret from the Password field above, then approve the consent screen.
4. The app loads the Feed.

WHAT TO TRY
- Switch sections with Cmd-1 to Cmd-6 (Feed, Notifications, New Post, People, Messages,
  My Posts). Post with Cmd-N. Refresh with Cmd-R.
- Read the feed, open a profile, check notifications, compose a post (optionally attach
  a photo). The app also lives in the menu bar for quick posting and native notifications.

NOTES
- The app requires connecting to a FediHome instance; the demo above is a test server,
  ready to use — no setup needed.
- Open source (MIT). No analytics, tracking, or third-party data collection.
- HTTPS only; ITSAppUsesNonExemptEncryption = false (export-compliance exempt).

Contact: <your support / Apple ID email>
```

Store-listing copy (description, subtitle, promotional text, keywords, "What's New") lives in
[`appstore-listing.md`](./appstore-listing.md).
