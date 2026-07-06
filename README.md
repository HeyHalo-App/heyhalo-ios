# Hey Halo (iOS)

The open-source iPhone companion for [Halo](https://heyhalo.app): **text your
Mac's Halo from your phone.** Your message rides your own iCloud (Apple relays
it), the thinking happens on your Mac, and nothing passes through anyone else's
servers.

This repo is the phone client. It's open so anyone can read the code and confirm
that claim for themselves: the messages only move through your own private
CloudKit database, never a Halo backend.

## What it does

- One flat chat screen: your messages, Halo's replies, and `needs-confirm`
  prompts rendered as approve/deny cards that answer straight back to the Mac
  (in-app and on the Lock Screen / Dynamic Island).
- Routes through your **private CloudKit database**. Same iCloud account on your
  iPhone and your Mac means one shared private DB and exactly one correct
  recipient. No pairing step.
- Silent push wakes a fetch; a local notification fires on a new reply when the
  app is backgrounded. Live Activities keep the island updated.
- Account screen with plan status and in-app account deletion.

## Requirements

- Xcode 26+, iOS 26 SDK (the app targets iOS 17+).
- Ruby with the [`xcodeproj`](https://github.com/CocoaPods/Xcodeproj) gem
  (`gem install xcodeproj`) — the `.xcodeproj` is generated, not checked in.
- To actually text a Mac: [Halo](https://heyhalo.app) running on a Mac signed
  into the same iCloud account.

## Build

```bash
ruby generate_xcodeproj.rb        # generates HaloiOS.xcodeproj
open HaloiOS.xcodeproj             # build/run in Xcode
```

You can explore the whole UI without a Mac using the built-in **demo mode**: on
the sign-in screen choose the email option and enter `appreview@heyhalo.app` — it
signs in offline with canned replies.

## Building your own fork

The project is wired for Hey Halo's Apple team and iCloud container. To ship your
own, override them:

```bash
HALO_IOS_TEAM=YOURTEAMID HALO_IOS_BUNDLE_ID=com.you.halo ruby generate_xcodeproj.rb
```

Then change the iCloud container from `iCloud.com.silvercommerce.halo` to your own
in three places: the two `*.entitlements` files, and `containerIdentifier` in the
[HaloReachKit](https://github.com/itsSilver/heyhalo-reach-kit) package. Also update
the `halo://` URL scheme in `Resources/Info.plist` if you change the bundle id.

## The shared wire type

The `ReachMessage` wire type lives in its own package,
[**HaloReachKit**](https://github.com/itsSilver/heyhalo-reach-kit), linked here via
Swift Package Manager. The Halo macOS app links the same package, so the phone and
the Mac speak a byte-identical wire and can never drift. The contract test in
`Tests/` pins every field key as a second guard.

## Layout

```
Sources/
├── App/                   # @main app + push AppDelegate
├── Account/               # sign-in + plan gate + account deletion
├── CloudKit/              # ReachCloudKitClient (send/receive)
├── LiveActivity/          # Dynamic Island / Lock Screen
├── Style/                 # design tokens, iOS-native
└── UI/                    # chat, bubbles, presence orb
WidgetSources/             # WidgetKit + Live Activity extension
ReachNotificationService/  # notification service extension (rich reply body)
Tests/                     # wire-protocol round-trip + contract test
```

See [SETUP.md](SETUP.md) for signing + capabilities detail.

## License

Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
