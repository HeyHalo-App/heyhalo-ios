# Contributing to Hey Halo (iOS)

Thanks for wanting to help. This is the open-source iPhone companion for
[Halo](https://heyhalo.app). Contributions of all sizes are welcome, from a typo
fix to a new feature.

## Ground rules

- Be kind. See the [Code of Conduct](CODE_OF_CONDUCT.md).
- Keep the privacy model intact: a user's messages only ever travel through
  their own private iCloud (CloudKit). Nothing should route chat content through
  a third-party server.
- Never commit secrets, signing certificates, or your own Apple team / bundle
  IDs. Use the environment overrides below instead.

## Getting set up

Requirements: Xcode 26+, and Ruby with the `xcodeproj` gem
(`gem install xcodeproj`). The `.xcodeproj` is generated, not checked in.

```bash
git clone https://github.com/itsSilver/heyhalo-ios.git
cd heyhalo-ios
ruby generate_xcodeproj.rb
open HaloiOS.xcodeproj
```

You can exercise the whole UI without a Mac running Halo using **demo mode**: on
the sign-in screen, choose the email option and enter `appreview@heyhalo.app`.
It signs in offline with canned replies.

### Building under your own Apple account

```bash
HALO_IOS_TEAM=YOURTEAMID HALO_IOS_BUNDLE_ID=com.you.halo ruby generate_xcodeproj.rb
```

You'll also need to change the iCloud container in the `*.entitlements` files and
in [HaloReachKit](https://github.com/itsSilver/heyhalo-reach-kit). See the README.

## Making a change

1. Fork the repo and create a branch (`git checkout -b fix/thing`).
2. Make your change. Match the style of the surrounding code (Swift 6, strict
   concurrency). Keep changes focused.
3. Run the tests (`swift test` in the package, or the app's test target).
4. If you added or removed files, re-run `ruby generate_xcodeproj.rb`.
5. Open a pull request against `main` and fill in the template.

Small, well-scoped PRs get reviewed fastest. If you're planning something big,
open an issue first so we can agree on the approach before you spend the time.

## Good places to start

Look for issues labelled [`good first issue`](https://github.com/itsSilver/heyhalo-ios/labels/good%20first%20issue).
Questions are welcome in [Discussions](https://github.com/itsSilver/heyhalo-ios/discussions).

## The shared wire type

The `ReachMessage` type lives in a separate package,
[HaloReachKit](https://github.com/itsSilver/heyhalo-reach-kit). If your change
touches the message format, it probably belongs there, and both the app and the
Halo Mac client depend on it, so treat it as a frozen contract.
