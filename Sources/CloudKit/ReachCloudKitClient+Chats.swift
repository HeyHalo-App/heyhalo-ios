// SPDX-License-Identifier: Apache-2.0
import Foundation
import HaloReachKit
import os

private let log = Logger(subsystem: "com.silvercommerce.halo", category: "reach.ios")

/// Multi-chat layer over the CloudKit message log (ADR 0037 §15). The phone
/// owns a local list of chats; messages are grouped by `threadID` (a `nil`
/// threadID — a pre-multi-chat record — buckets into ``legacyThreadID``).
extension ReachCloudKitClient {

    /// One row in the chat list: the chat plus a derived preview + activity time.
    struct ChatSummary: Identifiable, Equatable {
        let chat: ReachChat
        let preview: String
        let messageCount: Int
        let lastActivity: Date
        var id: String { chat.id }
    }

    /// The thread a message belongs to (`nil` ⇒ the legacy bucket).
    func threadKey(of message: ReachMessage) -> String {
        message.threadID ?? Self.legacyThreadID
    }

    /// Messages in the currently-open chat, time-ordered (the chat screen binds
    /// to this instead of the full log).
    ///
    /// Breadcrumb (`in-progress`) records are *coalesced* rather than hidden
    /// (ADR 0037 §17): live progress is worth showing, but a thread littered with
    /// stale "Looking that up…" lines is not. Per turn (keyed by the inbound
    /// `user` message the breadcrumb is working on — its `replyTo`):
    ///   • once a final `halo` reply for that turn exists, ALL the turn's
    ///     breadcrumbs are dropped, so the thread settles on the answer; and
    ///   • while still awaiting the reply, only the LATEST breadcrumb survives,
    ///     shown as a dim/italic bubble (`MessageBubble` keys off `.inProgress`).
    /// A breadcrumb with no `replyTo` (shouldn't happen, but be safe) is keyed by
    /// its own id so it's treated as its own one-off turn.
    var currentMessages: [ReachMessage] {
        guard let tid = currentThreadID else { return [] }
        let thread = messages.filter { threadKey(of: $0) == tid }
        return Self.coalescingBreadcrumbs(thread)
    }

    /// Drop answered turns' breadcrumbs and keep only the latest unanswered one
    /// per turn. Input is assumed time-ordered (the merge keeps `messages` so);
    /// output preserves that order. Pure + `nonisolated` static so it's
    /// unit-testable off the main actor and the prune path can reuse the
    /// "answered turns" decision.
    nonisolated static func coalescingBreadcrumbs(_ thread: [ReachMessage]) -> [ReachMessage] {
        let answered = answeredTurnIDs(thread)
        // The latest breadcrumb id per still-open turn (last wins in time order).
        var latestBreadcrumbByTurn: [String: String] = [:]
        for msg in thread where msg.status == .inProgress {
            let turn = msg.replyTo ?? msg.id
            guard !answered.contains(turn) else { continue }
            latestBreadcrumbByTurn[turn] = msg.id
        }
        let keepBreadcrumbIDs = Set(latestBreadcrumbByTurn.values)
        return thread.filter { msg in
            guard msg.status == .inProgress else { return true }
            return keepBreadcrumbIDs.contains(msg.id)
        }
    }

    /// Turn ids (the `user` message a reply answers) that already have a final
    /// `halo` reply in `thread`. A breadcrumb whose turn is in this set is dead.
    nonisolated static func answeredTurnIDs(_ thread: [ReachMessage]) -> Set<String> {
        Set(thread.compactMap { $0.role == .halo ? $0.replyTo : nil })
    }

    /// Chats for the list, newest-active first. A brand-new (message-less) chat
    /// sorts by its creation time. Breadcrumbs (`in-progress`) are excluded from
    /// the preview + count so the list shows the last real exchange, never a
    /// transient "Looking that up…" line.
    var orderedChats: [ChatSummary] {
        chats.map { chat in
            let msgs = messages.filter { threadKey(of: $0) == chat.id && $0.status != .inProgress }
            let last = msgs.max { $0.createdAt < $1.createdAt }
            return ChatSummary(
                chat: chat,
                preview: last?.body ?? "Tap to start",
                messageCount: msgs.count,
                lastActivity: last?.createdAt ?? chat.createdAt
            )
        }
        .sorted { $0.lastActivity > $1.lastActivity }
    }

    /// Start a fresh chat and make it current. Returns its thread id.
    ///
    /// Lazy: the chat is NOT added to the list here — it joins the list only
    /// once it has a first message (``ensureChat`` on send). So opening a new
    /// chat and backing out without sending leaves nothing behind (ADR 0037).
    @discardableResult
    func newChat() -> String {
        let id = UUID().uuidString
        currentThreadID = id
        persistCurrentThread()
        return id
    }

    /// Open an existing chat.
    func selectChat(_ id: String) {
        currentThreadID = id
        persistCurrentThread()
    }

    /// Route to a thread from a Live Activity / island tap: select it and
    /// signal the chat list to navigate there. Safe if the thread isn't loaded
    /// yet — the list pushes it and `ChatView` fetches its history on appear.
    func openThread(_ id: String) {
        selectChat(id)
        deepLinkThread = id
    }

    /// The active thread, creating a chat on first send if none is open.
    func activeThreadID() -> String {
        if let tid = currentThreadID { return tid }
        return newChat()
    }

    /// Ensure a chat exists for `threadID`; name it from `titleSeed` while it's
    /// still untitled. Idempotent.
    func ensureChat(for threadID: String, titleSeed: String?) {
        if let index = chats.firstIndex(where: { $0.id == threadID }) {
            if chats[index].title == ReachChat.defaultTitle,
                let seed = titleSeed?.trimmingCharacters(in: .whitespacesAndNewlines),
                !seed.isEmpty {
                chats[index].title = Self.deriveTitle(from: seed)
                persistChats()
            }
            return
        }
        let title = titleSeed.map(Self.deriveTitle) ?? ReachChat.defaultTitle
        chats.append(ReachChat(id: threadID, title: title, createdAt: Date()))
        persistChats()
    }

    /// Create chats for any thread that appears on the wire but isn't in the
    /// list yet (replies to a chat the phone didn't start, or legacy records).
    func reconcileChats(from incoming: [ReachMessage]) {
        let known = Set(chats.map(\.id))
        let seen = Set(incoming.map(threadKey(of:)))
        for thread in seen where !known.contains(thread) && !deletedThreadIDs.contains(thread) {
            // Title from the first user message in that thread, if any.
            let seed =
                messages
                .filter { threadKey(of: $0) == thread && $0.role == .user }
                .min { $0.createdAt < $1.createdAt }?
                .body
            let title =
                thread == Self.legacyThreadID
                ? "Main"
                : (seed.map(Self.deriveTitle) ?? ReachChat.defaultTitle)
            chats.append(ReachChat(id: thread, title: title, createdAt: Date()))
        }
        if seen.subtracting(known).isEmpty == false { persistChats() }
    }

    // MARK: - Breadcrumb retention

    /// Trim dead `in-progress` breadcrumbs out of the in-memory log so it can't
    /// grow unbounded with spent progress lines (ADR 0037 §17 retention). A
    /// breadcrumb is dropped when EITHER:
    ///   • its turn already has a final `halo` reply (the answer is in, the
    ///     "Looking that up…" trail is now noise), OR
    ///   • it's older than ``breadcrumbRetention`` (a defensive ceiling for a
    ///     turn that never got a reply — e.g. the Mac went away mid-work — so a
    ///     stuck turn's crumbs don't linger forever).
    /// This is the storage-side twin of ``coalescingBreadcrumbs(_:)`` (which is
    /// the display-side coalesce); pruning here keeps `messages` small while the
    /// view-time coalesce still collapses any survivors of the same turn.
    func pruneBreadcrumbs(now: Date = Date()) {
        // Answered turns across the WHOLE log (breadcrumbs and replies may sit in
        // different threads only in theory — replyTo is the join key regardless).
        let answered = Set(messages.compactMap { $0.role == .halo ? $0.replyTo : nil })
        let cutoff = now.addingTimeInterval(-Self.breadcrumbRetention)
        let before = messages.count
        removeMessages { msg in
            guard msg.status == .inProgress else { return false }
            let turn = msg.replyTo ?? msg.id
            return answered.contains(turn) || msg.createdAt < cutoff
        }
        if messages.count != before {
            log.debug("Reach iOS: pruned \(before - self.messages.count, privacy: .public) dead breadcrumb(s)")
        }
    }

    /// How long an unanswered breadcrumb is allowed to linger before pruning.
    /// Comfortably past the await timeout (75s) so a slow-but-live turn's latest
    /// crumb still shows; old enough that a dead turn's crumbs don't pile up.
    private static let breadcrumbRetention: TimeInterval = 10 * 60

    // MARK: - Persistence

    func persistChats() {
        guard let data = try? JSONEncoder().encode(chats) else { return }
        UserDefaults.standard.set(data, forKey: Self.chatsDefaultsKey)
    }

    func persistCurrentThread() {
        UserDefaults.standard.set(currentThreadID, forKey: Self.currentThreadDefaultsKey)
    }

    static func loadChats() -> [ReachChat] {
        guard let data = UserDefaults.standard.data(forKey: chatsDefaultsKey),
            let decoded = try? JSONDecoder().decode([ReachChat].self, from: data)
        else { return [] }
        // Drop empty/untitled chats left over from before lazy creation — a real
        // chat always gets a title from its first message, so a `defaultTitle`
        // entry is an empty shell that should never have been listed.
        return decoded.filter { $0.title != ReachChat.defaultTitle }
    }

    /// Title for a thread, for the Live Activity / header (falls back to "Halo").
    func chatTitle(for threadID: String?) -> String {
        guard let threadID, let chat = chats.first(where: { $0.id == threadID }) else { return "Halo" }
        return chat.title == ReachChat.defaultTitle ? "Halo" : chat.title
    }

    /// Drive the Live Activity (the iOS notch) from freshly-fetched records:
    /// a breadcrumb updates the line, a confirm shows the yes/no, a reply ends it.
    func updateLiveActivity(from incoming: [ReachMessage]) async {
        for msg in incoming.sorted(by: { $0.createdAt < $1.createdAt }) {
            let title = chatTitle(for: msg.threadID)
            switch msg.role {
            case .halo:
                thinkingLine = nil
                await ReachLiveActivityController.finish(reply: msg.body, chatTitle: title)
            case .system where msg.status == .needsConfirm:
                guard let token = msg.confirmToken else { continue }
                await ReachLiveActivityController.confirm(
                    .init(token: token, preview: msg.body, threadID: msg.threadID, messageID: msg.id),
                    chatTitle: title
                )
            case .system where msg.status == .inProgress:
                thinkingLine = msg.body
                await ReachLiveActivityController.breadcrumb(msg.body, threadID: msg.threadID, chatTitle: title)
            default:
                break
            }
        }
    }

    /// A short, human title from the first message (first line, clipped).
    static func deriveTitle(from body: String) -> String {
        let firstLine =
            body
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? body
        let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 40 { return trimmed.isEmpty ? ReachChat.defaultTitle : trimmed }
        return String(trimmed.prefix(40)) + "…"
    }
}
