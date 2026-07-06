// SPDX-License-Identifier: Apache-2.0
import BackgroundTasks
import CloudKit
import UIKit
import UserNotifications
import os

private let log = Logger(subsystem: "com.silvercommerce.halo", category: "reach.ios")

/// The push adaptor (spec §7): register for remote notifications, and on a
/// silent CloudKit push trigger a fetch on the live ``ReachCloudKitClient``.
/// When a new `halo` reply arrives while the app is backgrounded, post a
/// user-visible local notification so the user knows Halo answered.
///
/// CloudKit sends `content-available` silent pushes for the zone subscription;
/// iOS wakes the app, calls `didReceiveRemoteNotification`, and we fetch the
/// new records and merge them into the conversation.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    /// The live client, handed over by the app root once the scene is up so the
    /// push path and the UI share one instance. Optional because a push can
    /// (rarely) land before the scene's `.task` runs; we no-op until it's set.
    weak var reach: ReachCloudKitClient?

    /// BGTaskScheduler identifier — MUST match Info.plist's
    /// `BGTaskSchedulerPermittedIdentifiers`.
    static let refreshTaskID = "com.silvercommerce.halo.reach.refresh"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task { await requestNotificationAuthorization() }
        // Silent CloudKit pushes don't need user authorization to wake the app;
        // registering for remote notifications is what enrols us for them.
        application.registerForRemoteNotifications()

        // Fallback delivery: iOS throttles (and in Development often drops) the
        // silent CloudKit push for suspended apps, which can strand a reply
        // until the user reopens the app. A periodic background refresh re-syncs
        // the zone on iOS's schedule, belt-and-suspenders on top of the push +
        // the 4s foreground poll, so a reply can't sit undelivered for long.
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshTaskID,
            using: nil
        ) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleAppRefresh(refreshTask)
        }
        scheduleAppRefresh()
        return true
    }

    // MARK: - Background refresh fallback

    /// Ask iOS to run a refresh no sooner than ~15 min from now (the system
    /// picks the actual time based on usage + battery). Re-submitted after each
    /// run so the fallback keeps ticking.
    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            log.debug(
                "Reach iOS: could not schedule background refresh: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// A background refresh fired — chain the next one, then re-sync the zone so
    /// any reply the push missed is pulled in. Bounded by iOS's expiration.
    private func handleAppRefresh(_ task: BGAppRefreshTask) {
        scheduleAppRefresh()
        let refresh = Task { @MainActor [weak self] in
            await self?.reach?.fetch()
            _ = self?.reach?.drainNewHaloReplies()
        }
        task.expirationHandler = { refresh.cancel() }
        Task {
            _ = await refresh.value
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - APNs registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // CloudKit manages the push routing server-side via the subscription;
        // we don't ship the token anywhere. Log for diagnostics only.
        log.info("Reach iOS: registered for remote notifications (\(deviceToken.count, privacy: .public) byte token)")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        log.error("Reach iOS: remote notification registration failed: \(error.localizedDescription, privacy: .public)")
    }

    // MARK: - Silent push → fetch

    /// A silent CloudKit push landed — fetch the new records and, if the app is
    /// backgrounded and a fresh `halo` reply arrived, post a local notification.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        // Confirm it's a CloudKit notification before acting (defensive).
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else {
            return .noData
        }
        log.info("Reach iOS: push received, syncing")

        guard let reach else { return .noData }
        // Sync the conversation so the message is already present when the user
        // opens the app. The user-VISIBLE notification is now shown by CloudKit's
        // alert subscription (`role == halo`), so it lands even when this wake
        // never happens (suspended / killed app) — and posting one here too would
        // double up. Drain the pending queue so it can't grow unbounded.
        await reach.fetch()
        _ = reach.drainNewHaloReplies()
        return .newData
    }

    // MARK: - Local notifications

    private func requestNotificationAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            log.error("Reach iOS: notification authorization failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Show banners even when the app is in the foreground so a reply that lands
    /// while you're looking at another screen still announces itself.
    /// `nonisolated` because the delegate callback arrives off the main actor
    /// with non-Sendable params; the body touches no actor state.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
