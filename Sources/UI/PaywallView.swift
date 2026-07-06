// SPDX-License-Identifier: Apache-2.0
import SwiftUI

/// Shown when the user is signed in but their account has no active Halo plan.
/// Reach is part of a paid Halo plan, set up on the Mac app or the website. As a
/// companion to that multiplatform service, this screen only *reads* the
/// account's plan state and unlocks Reach when it's active. It never sells a plan
/// or links out to a purchase (App Store rules for multiplatform services). So
/// the only actions here are: re-check the account, or sign out.
struct PaywallView: View {
    @EnvironmentObject private var account: HaloAccount

    var body: some View {
        ZStack {
            HaloiOSStyle.canvas

            VStack(spacing: 26) {
                Spacer()

                HaloPresenceMark(isThinking: false, diameter: 84)

                VStack(spacing: 10) {
                    Text("Reach is a Halo plan feature")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(HaloiOSStyle.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(bodyCopy)
                        .font(HaloiOSStyle.body)
                        .foregroundStyle(HaloiOSStyle.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 8)

                Button {
                    Task { await account.refreshAccount() }
                } label: {
                    Text(account.busy ? "Checking…" : "Check again")
                        .font(HaloiOSStyle.bodyEmphasis)
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(HaloiOSStyle.accent)
                        )
                }
                .buttonStyle(.plain)
                .disabled(account.busy)

                Button("Sign out") { account.signOut() }
                    .font(HaloiOSStyle.caption)
                    .foregroundStyle(HaloiOSStyle.textSecondary)
                    .padding(.top, 4)

                Spacer()
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 520)
        }
        .preferredColorScheme(.dark)
    }

    private var bodyCopy: String {
        if let email = account.account?.user.email, !email.isEmpty {
            return
                "You're signed in as \(email), but this account doesn't have an active Halo plan yet. Reach unlocks here automatically once your plan is active."
        }
        return
            "This account doesn't have an active Halo plan yet. Reach unlocks here automatically once your plan is active."
    }
}
