// SPDX-License-Identifier: Apache-2.0
import SwiftUI

/// Halo's presence on the phone — the breathing brand mark. Replaces the old
/// placeholder blue presence dot: wherever Halo "is" (the chat header, the
/// empty state, the answering row, onboarding), it's the logo, in its activity
/// tint, breathing slow at rest and quicker while it's working — never an
/// anonymous dot.
///
/// Keeps the old call shape (`isThinking:` / `diameter:`) so it's a drop-in.
struct HaloPresenceMark: View {
    /// Faster, brighter breath when Halo is working on a reply.
    var isThinking: Bool
    /// Overall size of the mark.
    var diameter: CGFloat = 26

    var body: some View {
        AnimatedHaloLogo(
            size: diameter,
            activity: isThinking ? .thinking : .idle,
            period: isThinking ? 1.1 : 3.4,
            // While working, the bright arc sweeps the ring (loading); at rest it
            // just breathes.
            sweeps: isThinking
        )
        .accessibilityHidden(true)
    }
}
