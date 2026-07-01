# Security Policy

Thanks for helping keep FediHome-macOS — and the people who run it against their instance — safe.

## Reporting a vulnerability

**Please don't report security vulnerabilities through public GitHub issues, discussions, or pull
requests** — a public report discloses the problem before a fix exists.

Instead, report it privately via GitHub's
**[Report a vulnerability](https://github.com/TemujinCalidius/FediHome-macOS/security/advisories/new)**
form (the repo's **Security → Advisories → Report a vulnerability**). Only the maintainers can see it.

Please include what you can:

- the affected file(s) / component / app version,
- the impact and how it could be exploited (e.g. a way to exfiltrate the stored token or a request
  the app makes that a malicious instance or network could abuse),
- steps to reproduce or a proof of concept,
- any suggested fix.

## What happens next

FediHome-macOS is small and mostly solo-maintained, so this is best-effort:

1. We aim to **acknowledge** your report within a few days.
2. We confirm the issue and develop a fix **privately**.
3. We **release the fix first**, then publish a **GitHub Security Advisory** (requesting a CVE where
   warranted) and **credit you** — unless you'd prefer to stay anonymous.

We practice **coordinated disclosure**: please give us a reasonable window to ship a fix before
disclosing publicly, so people running the app can update first.

## Supported versions

Security fixes ship against the **latest release** only. Keep the app updated to the newest release.

| Version | Supported |
|---------|-----------|
| Latest release | ✅ |
| Anything older | ❌ — please update |

## Scope

FediHome-macOS is a **native client** that talks to a user's own FediHome instance and stores an app
token in the macOS **Keychain**.

- **In scope:** vulnerabilities in the **FediHome-macOS code in this repository** — anything that
  puts the user, their token, or their data at risk (e.g. insecure token storage, a request that
  leaks credentials, trusting a response in a way a hostile instance or network could abuse,
  improper TLS handling).
- **Out of scope here:** vulnerabilities in the **FediHome server** itself (report those to the
  [FediHome repo](https://github.com/TemujinCalidius/FediHome/security/advisories/new)), a specific
  instance's misconfiguration, and bugs in third-party dependencies or Apple's frameworks (report
  those upstream — though we're glad to hear about ones that materially affect FediHome-macOS).

The app is also only as safe as the instance and machine it runs on: **serve FediHome over HTTPS**,
keep your app token secret, and run the latest release of both the app and your instance.

## How we handle security internally

Most hardening lands openly as normal issues and PRs. We run **Dependabot** (dependency alerts +
security updates) and a periodic triage. Genuinely sensitive, high-severity findings go through the
private advisory process above instead, so a fix is available before any public disclosure.
