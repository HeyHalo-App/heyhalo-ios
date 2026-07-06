# Security Policy

Thanks for helping keep Hey Halo and its users safe.

## Reporting a vulnerability

**Please do not open a public issue for security problems.**

Report privately, either way:

- **Preferred:** use GitHub's [private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
  — the **"Report a vulnerability"** button on the Security tab of this repo.
- **Or email:** hello@heyhalo.app with "SECURITY" in the subject.

Please include what you found, the steps to reproduce it, and the impact you
think it has. We'll acknowledge your report as soon as we can and keep you
updated as we work on a fix. We'll credit you when the fix ships, unless you'd
rather stay anonymous.

## Scope

This repository is the **client** app. In scope:

- Anything that could expose a user's messages, tokens, or data on the device or
  in transit.
- Signing, entitlement, or CloudKit misconfigurations that weaken the privacy
  model.
- Dependency vulnerabilities that affect the shipped app.

Out of scope here (report separately to hello@heyhalo.app):

- The Halo backend / API.
- Findings that require a jailbroken device, physical access, or a
  already-compromised Mac.
- Social-engineering or spam reports.

## Supported versions

We support the latest released version. Fixes land on the current release line.
