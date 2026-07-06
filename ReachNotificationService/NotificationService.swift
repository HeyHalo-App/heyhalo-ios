// SPDX-License-Identifier: Apache-2.0
import CloudKit
import HaloReachKit
@preconcurrency import UserNotifications
import os

private let log = Logger(subsystem: "com.silvercommerce.halo", category: "reach.nse")

/// Notification Service Extension for Reach (ADR 0040 follow-up).
///
/// The visible alert push from the `role == halo` query subscription carries a
/// **generic** body ("I've got something for you. Tap to read.") — the reply
/// text is deliberately kept OUT of the APNs payload (privacy contract: message
/// content stays in the user's iCloud, never transits Apple's push servers as
/// readable text). This extension runs after delivery but before display: it
/// fetches the just-created record from the user's private database by the
/// push's `recordID`, reads the plaintext body, and rewrites the notification so
/// the lock screen shows the actual reply instead of the placeholder.
///
/// Fails OPEN: any error (no recordID, fetch failure, timeout) falls back to the
/// generic body the push already carries — the notification still appears.
///
/// Linked against `HaloReachKit` (ADR 0052 slice 3) so field keys and the
/// container identifier come from the single shared wire type rather than inline
/// constants that can drift.
///
/// `@unchecked Sendable`: the system drives an NSE serially — one `didReceive`,
/// then EITHER the single CloudKit fetch completion OR `serviceExtensionTime
/// WillExpire`, never a genuine overlap — and `deliver()`'s one-shot
/// `contentHandler = nil` guard makes a double call a no-op. That lets the fetch
/// completion capture `self` under strict concurrency without a lock the
/// lifecycle doesn't actually need.
final class NotificationService: UNNotificationServiceExtension, @unchecked Sendable {

    /// Lock-screen bodies want to stay short.
    private static let maxBodyLength = 160

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttempt: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        let best = request.content.mutableCopy() as? UNMutableNotificationContent
        self.bestAttempt = best

        guard let best,
            let recordID = Self.recordID(from: request.content.userInfo)
        else {
            // Not a CloudKit query push we can enrich — show what we have.
            contentHandler(request.content)
            return
        }

        let database = CKContainer(identifier: ReachMessage.containerIdentifier).privateCloudDatabase
        database.fetch(withRecordID: recordID) { record, error in
            defer { self.deliver() }
            if let error {
                log.debug("Reach NSE: fetch failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            guard let record,
                (record[ReachMessage.Field.role] as? String) == ReachMessage.Role.halo.rawValue,
                let body = record[ReachMessage.Field.body] as? String,
                !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return }
            best.body = Self.trimmed(body)
        }
    }

    /// The OS is about to kill us — deliver the best we have (enriched if the
    /// fetch already returned, otherwise the generic body).
    override func serviceExtensionTimeWillExpire() {
        deliver()
    }

    /// Call the content handler exactly once with the current best attempt.
    private func deliver() {
        guard let handler = contentHandler, let best = bestAttempt else { return }
        contentHandler = nil  // one-shot
        handler(best)
    }

    /// Pull the changed record's id out of a CloudKit query-notification payload.
    private static func recordID(from userInfo: [AnyHashable: Any]) -> CKRecord.ID? {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
            let query = notification as? CKQueryNotification
        else { return nil }
        return query.recordID
    }

    private static func trimmed(_ body: String) -> String {
        let clean = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > maxBodyLength else { return clean }
        return String(clean.prefix(maxBodyLength - 1)) + "…"
    }
}
