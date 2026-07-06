// SPDX-License-Identifier: Apache-2.0
import SwiftUI

/// The launch / loading moment. Halo's mark loads in place: the bright arc
/// sweeps around the halo's own dots while the whole mark breathes — the ring
/// itself is the spinner, not a separate circle around it. Used on cold launch
/// and the "checking your account / connecting" state, so the motion covers
/// real work rather than a fixed timer.
struct SplashView: View {
    /// Optional line under the mark ("Connecting…", "Checking your plan…").
    var status: String?

    /// Diameter of the loading mark.
    private let markSize: CGFloat = 140

    var body: some View {
        ZStack {
            HaloiOSStyle.canvas

            VStack(spacing: 30) {
                AnimatedHaloLogo(
                    size: markSize,
                    activity: .thinking,
                    period: 2.6,
                    sweeps: true
                )

                VStack(spacing: 8) {
                    Text("Halo")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(HaloiOSStyle.textPrimary)
                    if let status {
                        Text(status)
                            .font(HaloiOSStyle.caption)
                            .foregroundStyle(HaloiOSStyle.textSecondary)
                            .transition(.opacity)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
