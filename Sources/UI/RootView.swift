// SPDX-License-Identifier: Apache-2.0
import SwiftUI

/// Decides what the user sees on launch: the welcome / onboarding moment, or
/// straight into the chat (with the connection indicator in the header).
///
/// Rules (task spec):
/// - **First launch ever** → onboarding (one `UserDefaults` flag records that
///   it's been seen). Afterward, a returning user drops straight into chat.
/// - **Not signed into iCloud** (no account / restricted / unavailable) → always
///   show onboarding, even for a returning user, because the chat can't send.
/// - Tapping **Start** from the signed-in onboarding state records first-run
///   done and reveals the chat.
struct RootView: View {
    @EnvironmentObject private var reach: ReachCloudKitClient

    /// Persisted once the user has gotten past the welcome screen at least once.
    @AppStorage("reach.ios.onboardingSeen") private var onboardingSeen = false

    var body: some View {
        Group {
            if shouldShowOnboarding {
                OnboardingView(onStart: { onboardingSeen = true })
                    .transition(.opacity)
            } else {
                ChatListView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: shouldShowOnboarding)
    }

    /// Onboarding shows on first launch, or any time the phone isn't signed into
    /// iCloud (so the user is never dumped into a chat that can't send). Once
    /// `.checking` resolves to `.signedIn` for a returning user, the chat shows.
    private var shouldShowOnboarding: Bool {
        // The App Review demo drops straight into the chat — no iCloud setup.
        if reach.isDemo { return false }
        if !onboardingSeen { return true }
        switch reach.connection {
        case .signedIn, .checking:
            return false
        case .noAccount, .restricted, .couldNotDetermine:
            return true
        }
    }
}
