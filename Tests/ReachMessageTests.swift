// SPDX-License-Identifier: Apache-2.0
import HaloReachKit
import Testing

@testable import HaloiOS

/// iOS-only behavior on top of the shared `ReachMessage` wire type. The pure
/// wire-format round-trip + contract-constant tests now live once in
/// `HaloReachKitTests` (ADR 0052 slice 0); what remains here is phone-specific:
/// the local-only stall notice (an iOS extension on the shared type) and the
/// breadcrumb coalescing that the phone's `ReachCloudKitClient` applies to a
/// thread before rendering.
struct ReachMessageTests {

    // MARK: - Local stall notice (iOS-only extension)

    @Test func stallNoticeIsLocalIdempotentAndLinksTheTurn() {
        let a = ReachMessage.stallNotice(for: "msg-1", threadID: "thread-1")
        let b = ReachMessage.stallNotice(for: "msg-1", threadID: "thread-1")
        // Same pending message ⇒ same id ⇒ a repeat stall can't duplicate it.
        #expect(a.id == b.id)
        #expect(a.id.hasPrefix(ReachMessage.localNoticeIDPrefix))
        #expect(a.isLocalNotice)
        #expect(a.role == .system)
        #expect(a.replyTo == "msg-1")
        #expect(a.threadID == "thread-1")
        // A different pending message gets its own note.
        #expect(ReachMessage.stallNotice(for: "msg-2", threadID: "thread-1").id != a.id)
    }

    // MARK: - Breadcrumb coalescing (iOS-only, ReachCloudKitClient)

    @Test func coalesceDropsBreadcrumbsOnceTheTurnIsAnswered() {
        let user = ReachMessage(id: "u1", role: .user, body: "hi", createdAt: .init(timeIntervalSince1970: 0))
        let crumb1 = ReachMessage(id: "c1", role: .system, body: "Looking…", createdAt: .init(timeIntervalSince1970: 1), status: .inProgress, replyTo: "u1")
        let crumb2 = ReachMessage(id: "c2", role: .system, body: "Almost…", createdAt: .init(timeIntervalSince1970: 2), status: .inProgress, replyTo: "u1")
        let reply = ReachMessage(id: "r1", role: .halo, body: "Done.", createdAt: .init(timeIntervalSince1970: 3), replyTo: "u1")

        let out = ReachCloudKitClient.coalescingBreadcrumbs([user, crumb1, crumb2, reply])
        // Turn answered ⇒ no breadcrumbs survive; user + reply remain.
        #expect(out.map(\.id) == ["u1", "r1"])
    }

    @Test func coalesceKeepsOnlyLatestBreadcrumbWhileAwaiting() {
        let user = ReachMessage(id: "u1", role: .user, body: "hi", createdAt: .init(timeIntervalSince1970: 0))
        let crumb1 = ReachMessage(id: "c1", role: .system, body: "Looking…", createdAt: .init(timeIntervalSince1970: 1), status: .inProgress, replyTo: "u1")
        let crumb2 = ReachMessage(id: "c2", role: .system, body: "Almost…", createdAt: .init(timeIntervalSince1970: 2), status: .inProgress, replyTo: "u1")

        let out = ReachCloudKitClient.coalescingBreadcrumbs([user, crumb1, crumb2])
        // No reply yet ⇒ user + only the latest breadcrumb survive.
        #expect(out.map(\.id) == ["u1", "c2"])
    }
}
