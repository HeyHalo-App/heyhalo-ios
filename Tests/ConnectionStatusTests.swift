// SPDX-License-Identifier: Apache-2.0
import Testing

@testable import HaloiOS

/// The honesty contract for the connection indicator + onboarding copy: the
/// phone can only verify its own iCloud side, so being signed into iCloud must
/// NEVER read as "Connected." Only an actual reply from the Mac
/// (`endToEndConfirmed`) is allowed to claim the full path works (task spec §2).
struct ConnectionStatusTests {

    private func descriptor(
        _ connection: ReachCloudKitClient.ConnectionState,
        confirmed: Bool
    ) -> ConnectionStatusDescriptor {
        ConnectionStatusDescriptor(connection: connection, endToEndConfirmed: confirmed)
    }

    @Test func signedInWithoutAReplyIsNotConnected() {
        let d = descriptor(.signedIn, confirmed: false)
        #expect(d.tone == .signedInPendingMac)
        // The load-bearing claim: never "Connected" on iCloud status alone.
        #expect(d.headerLabel == "Signed into iCloud")
        #expect(!d.headline.contains("Connected"))
        #expect(!d.detail.contains("Connected"))
        // It must name the Mac toggle the phone can't flip itself.
        #expect(d.detail.contains("Listen for messages from my phone"))
        #expect(d.detail.contains("your Mac needs that toggle on"))
    }

    @Test func firstReplyPromotesToConnected() {
        let d = descriptor(.signedIn, confirmed: true)
        #expect(d.tone == .connected)
        #expect(d.headerLabel == "Connected")
        #expect(d.headline.contains("Connected"))
        #expect(d.dotColor == HaloiOSStyle.accent)
    }

    @Test func noAccountAsksToSignIn() {
        let d = descriptor(.noAccount, confirmed: false)
        #expect(d.tone == .needsAttention)
        #expect(d.headerLabel == "Not signed into iCloud")
        #expect(d.detail.contains("Sign into iCloud"))
        // Honest: same account as the Mac is the whole "pairing" step.
        #expect(d.detail.contains("same account as your Mac"))
    }

    @Test func restrictedIsSurfacedDistinctly() {
        let d = descriptor(.restricted, confirmed: false)
        #expect(d.tone == .needsAttention)
        #expect(d.headerLabel == "iCloud is restricted")
    }

    @Test func couldNotDetermineCarriesItsReason() {
        let reason = "I couldn't send that just now. Mind trying again?"
        let d = descriptor(.couldNotDetermine(reason), confirmed: false)
        #expect(d.tone == .needsAttention)
        #expect(d.detail == reason)
    }

    @Test func checkingPulsesAndMakesNoClaim() {
        let d = descriptor(.checking, confirmed: false)
        #expect(d.tone == .checking)
        #expect(d.dotPulses)
        #expect(!d.headerLabel.contains("Connected"))
    }

    @Test func aReturningConnectedUserStaysConnectedEvenWhileChecking() {
        // endToEndConfirmed persists across launches; while re-checking on a
        // relaunch the tone is `.checking` (honest: we're re-verifying), and it
        // resolves to `.connected` once `.signedIn` lands again.
        #expect(descriptor(.checking, confirmed: true).tone == .checking)
        #expect(descriptor(.signedIn, confirmed: true).tone == .connected)
    }
}
