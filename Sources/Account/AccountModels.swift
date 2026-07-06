// SPDX-License-Identifier: Apache-2.0
import Foundation

/// The shape of `GET /v1/account/me` (services/api/src/routes/account.ts). Only
/// the fields the phone shows or gates on are decoded; unknown fields are
/// ignored. Times are epoch milliseconds (the API uses `Date.getTime()`).
struct AccountMe: Decodable, Sendable, Equatable {
    var authenticated: Bool
    var user: User
    var subscription: Subscription?
    var team: Team?
    var usage: Usage?

    struct User: Decodable, Sendable, Equatable {
        var id: String
        var email: String
        var name: String?
        var role: String?
    }

    struct Subscription: Decodable, Sendable, Equatable {
        var status: String
        var period_end: Double?
        var trial_end: Double?
        var plan: String?
    }

    struct Team: Decodable, Sendable, Equatable {
        var id: String
        var name: String
        var role: String?
        var seats: Int?
        var status: String?
        var period_end: Double?
    }

    struct Usage: Decodable, Sendable, Equatable {
        var period: String?
        var messages: Int
        var tokens_total: Int
        var est_cost_usd: Double?
        var caps: Caps?
        var messages_remaining: Int?
        var tokens_remaining: Int?
        var over_cap: Bool?
        var resets_at: Double?

        struct Caps: Decodable, Sendable, Equatable {
            var messages: Int?
            var tokens: Int?
        }
    }

    // MARK: - Derived

    /// True when the account has the admin role — bypasses the subscription
    /// gate entirely (aligns with the backend's admin bypass + the Mac's
    /// `EntitlementStore`). `role` is admin-assigned server-side only.
    var isAdmin: Bool { user.role == "admin" }

    /// The statuses the relay treats as entitled (`grantingStates` in
    /// inference.ts) — trialing / active / past_due — provided the period
    /// hasn't lapsed. Mirrors `EntitlementStore.canUseHaloCloud`. Admins bypass.
    var isEntitled: Bool {
        if isAdmin { return true }
        guard let sub = subscription else { return false }
        let granting: Set<String> = ["trialing", "active", "past_due"]
        guard granting.contains(sub.status) else { return false }
        // period_end is the renewal/trial boundary; if present and past, deny.
        if let end = sub.period_end {
            return Date().timeIntervalSince1970 < end / 1000.0
        }
        return true
    }

    /// A warm, human plan label for the account header.
    var planLabel: String {
        if isAdmin { return "Admin" }
        if let team, !team.name.isEmpty { return "\(team.name) team" }
        if let plan = subscription?.plan, !plan.isEmpty {
            return plan.capitalized
        }
        switch subscription?.status {
        case "trialing": return "Free trial"
        case "active": return "Halo plan"
        case "past_due": return "Payment due"
        default: return "No plan"
        }
    }
}

// MARK: - App Review demo

extension AccountMe {
    /// A synthetic, entitled account used only by the offline App Review demo
    /// (`HaloAccount.enterDemoMode`, gated to the demo email). Never comes from
    /// the network. Entitled via an active subscription rather than the admin
    /// role, so it reaches the chat without unlocking any admin-only surface.
    static func demo(email: String) -> AccountMe {
        AccountMe(
            authenticated: true,
            user: User(id: "demo-reviewer", email: email, name: "App Review", role: nil),
            subscription: Subscription(status: "active", period_end: nil, trial_end: nil, plan: "Demo"),
            team: nil,
            usage: nil
        )
    }
}
