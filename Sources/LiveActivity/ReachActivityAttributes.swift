// SPDX-License-Identifier: Apache-2.0
import ActivityKit
import Foundation

/// The Live Activity contract for a Reach turn — the iOS "notch" (Dynamic Island
/// + Lock Screen). Shared between the app (which starts/updates/ends the
/// activity) and the widget extension (which renders it). ADR 0037 §16.
struct ReachActivityAttributes: ActivityAttributes {

    /// The live, updatable part: what Halo is doing right now.
    struct ContentState: Codable, Hashable {
        var phase: Phase
        /// The current breadcrumb / status line ("Looking that up…", the reply…).
        var line: String
        /// The chat this turn belongs to (shown as the title).
        var chatTitle: String
        /// Present only when Halo is asking for a yes/no on a gated action.
        var confirm: Confirm?
    }

    enum Phase: String, Codable, Hashable {
        case thinking  // working, before/!between tools
        case responding  // streaming the answer
        case needsConfirm  // waiting on the user's approve/skip
        case done  // resolved (activity ends shortly after)
    }

    /// A pending approve/skip request surfaced on the island.
    struct Confirm: Codable, Hashable {
        /// Round-trip id from the Mac's confirm prompt.
        var token: String
        /// Short human preview ("Send email to Maya").
        var preview: String
        /// The chat the confirm belongs to.
        var threadID: String?
        /// The system record id the answer should `replyTo`.
        var messageID: String
    }

    /// Static identity, set once when the activity starts.
    var sessionID: String

    /// The chat thread this turn belongs to, set once at start, so a tap on
    /// the island can deep-link straight to the right conversation.
    var threadID: String?
}
