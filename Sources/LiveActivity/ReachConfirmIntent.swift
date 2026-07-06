// SPDX-License-Identifier: Apache-2.0
import AppIntents
import CloudKit
import Foundation
import HaloReachKit
import os

/// The intent behind the **Approve / Skip buttons on the Dynamic Island and
/// Lock Screen** (ADR 0037 slice C). A Live Activity button's intent must be a
/// type both the widget (to build the button) and the app (to run it) can see,
/// so this lives in a file compiled into both targets.
///
/// It writes the confirm ANSWER straight to the user's private CloudKit
/// database using the shared `ReachMessage` wire type — it never touches the
/// app-only `ReachCloudKitClient`. That is deliberate: as a `LiveActivityIntent`
/// its `perform()` runs in the app's process (foreground, or background-launched
/// for the tap), and writing CloudKit directly means the answer lands the same
/// way whether the app was open, suspended, or relaunched for the tap — no
/// dependency on any in-memory client being alive. The Mac reads this record
/// exactly like an in-app Approve/Skip (same token, same `Router.confirmAnswers`
/// path), so the two entry points are indistinguishable on the wire.
///
/// The visual follow-up (island flips to "On it…", then the reply) rides the
/// existing path: the Mac runs the staged tool and writes its breadcrumb/reply,
/// which the app applies to the activity on its next fetch. Answering twice
/// (island then in-app, or the reverse) is safe: both records carry the same
/// `confirmToken`, and the Mac resolves a token exactly once.
struct ReachConfirmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Answer Halo"

    /// The Mac's confirm-prompt token this answer resolves.
    @Parameter(title: "Token") var token: String
    /// Whether the user approved (true) or skipped (false).
    @Parameter(title: "Approved") var approved: Bool
    /// The chat thread the confirm belongs to, echoed back so the Mac routes the
    /// reply to the right conversation.
    @Parameter(title: "Thread") var threadID: String?

    init() {}

    init(token: String, approved: Bool, threadID: String?) {
        self.token = token
        self.approved = approved
        self.threadID = threadID
    }

    func perform() async throws -> some IntentResult {
        let log = Logger(subsystem: "com.silvercommerce.halo", category: "reach.ios")
        let container = CKContainer(identifier: ReachMessage.containerIdentifier)
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: ReachMessage.zoneName)

        // Same shape the in-app ConfirmCard writes (ReachCloudKitClient
        // .answerConfirm): a fresh `user` record tagged with the prompt's token,
        // body "yes"/"no". `.plaintext` crypto matches the client's default.
        let answer = ReachMessage(
            role: .user,
            body: approved ? "yes" : "no",
            status: .sent,
            confirmToken: token,
            threadID: threadID
        )
        let record = answer.makeRecord(in: zoneID)

        do {
            let response = try await database.modifyRecords(saving: [record], deleting: [])
            if case .failure(let saveError)? = response.saveResults[record.recordID] {
                throw saveError
            }
            log.info(
                "Reach iOS: island confirm answered approved=\(approved, privacy: .public) token=\(token, privacy: .public)"
            )
        } catch {
            log.error(
                "Reach iOS: island confirm answer failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
        return .result()
    }
}
