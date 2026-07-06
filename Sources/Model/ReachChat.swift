// SPDX-License-Identifier: Apache-2.0
import Foundation

/// One on-device chat (ADR 0037 §15). A chat is one `threadID`; the phone owns
/// the list locally and tags every `ReachMessage` it sends with the chat's id so
/// the Mac can echo it back on the reply. Metadata only — the messages
/// themselves live in CloudKit and are grouped by `threadID` at render time.
struct ReachChat: Identifiable, Codable, Equatable, Sendable {
    /// The thread id (a UUID), used as `ReachMessage.threadID`.
    let id: String
    /// User-facing title; auto-derived from the first message, editable later.
    var title: String
    /// When the chat was created (orders brand-new, message-less chats).
    var createdAt: Date

    static let defaultTitle = "New chat"
}
