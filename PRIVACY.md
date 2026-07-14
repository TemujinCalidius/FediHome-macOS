# Privacy Policy — FediHome for macOS

_Last updated: 2026-07-14_

FediHome for macOS ("the app") is a native client for **[FediHome](https://github.com/TemujinCalidius/FediHome)**,
a self-hosted, single-user Fediverse server. In short: **the app collects nothing about you, and
sends nothing to its developer or any third party.**

## What the app connects to
The app communicates **only** with the FediHome instance you choose to connect to, over **HTTPS**.
It does not contact any analytics service, advertising network, or other third party.

## What the app stores on your Mac
- **Your access token.** When you sign in, the app stores a scoped OAuth 2.0 access token for your
  instance in the macOS **Keychain**. It is never written to a file or log, and is sent only to your
  own instance to authenticate your requests.
- **Local preferences.** Settings (poll intervals, default filters, last-used section) are stored
  locally in standard macOS preferences.
- **A media cache.** Images and media from your feed are cached locally to avoid re-downloading, as
  any web client does. This cache stays on your Mac.

## What the app does NOT do
- No analytics, telemetry, tracking, or advertising identifiers.
- No data is collected by, or transmitted to, the developer.
- No data is shared with third parties.
- No account is created with the developer — you authenticate directly with your own instance.

## The content you see
Your timeline, posts, direct messages, and profile come from your FediHome instance and are governed
by that instance's own policies. The app displays and lets you interact with that content; it does
not send it anywhere other than your instance.

## Data deletion
Disconnecting (Me → Disconnect) removes the stored token from your Keychain. Deleting the app removes
its local caches and preferences.

## Children
The app is not directed at children and collects no personal information from anyone.

## Contact
Questions about this policy? Open an issue or discussion on the project's repository:
<https://github.com/TemujinCalidius/FediHome-macOS>

## Changes
Any updates to this policy will be published in this file in the repository.
