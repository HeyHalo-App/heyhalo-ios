// SPDX-License-Identifier: Apache-2.0
import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Halo's presence on the phone's Dynamic Island + Lock Screen during a Reach
/// turn: the mark, the current breadcrumb, and — when Halo asks — the yes/no
/// prompt. ADR 0037 §16.
///
/// While awaiting a reply (`thinking` / `responding`) the mark pulses and a
/// small system spinner runs, so it clearly reads "working." (Live Activities
/// only honor a limited animation set; the system `ProgressView` is the
/// reliable motion, the pulse is the branded touch where it renders.)
struct ReachLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReachActivityAttributes.self) { context in
            LockScreenView(state: context.state, threadID: context.attributes.threadID)
                .activityBackgroundTint(Color.black.opacity(0.88))
                .activitySystemActionForegroundColor(HaloWidgetStyle.accent)
        } dynamicIsland: { context in
            let state = context.state
            let working = isWorking(state.phase)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PulsingHaloMark(size: 30, activity: activity(for: state.phase), animated: working)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(badge(for: state.phase))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(HaloWidgetStyle.accent)
                        .contentTransition(.opacity)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(state.chatTitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(state.line)
                            .font(.callout)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .contentTransition(.opacity)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let confirm = state.confirm {
                            ConfirmButtons(confirm: confirm)
                        }
                    }
                }
            } compactLeading: {
                PulsingHaloMark(size: 20, activity: activity(for: state.phase), animated: working)
            } compactTrailing: {
                // Only a confirm prompt warrants a trailing glyph. Working state
                // is conveyed by the pulsing halo on the leading side alone.
                if state.phase == .needsConfirm {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundStyle(HaloWidgetStyle.accent)
                }
            } minimal: {
                PulsingHaloMark(size: 18, activity: activity(for: state.phase), animated: working)
            }
            .widgetURL(Self.chatURL(context.attributes.threadID))
        }
    }

    /// Deep link for a tap on the island / Live Activity: route to this turn's
    /// chat when we know it, otherwise just bring the app forward.
    static func chatURL(_ threadID: String?) -> URL? {
        if let threadID, !threadID.isEmpty {
            return URL(string: "halo://chat/\(threadID)")
        }
        return URL(string: "halo://chat")
    }

    private func isWorking(_ phase: ReachActivityAttributes.Phase) -> Bool {
        phase == .thinking || phase == .responding
    }

    private func activity(for phase: ReachActivityAttributes.Phase) -> HaloLogo.Activity {
        switch phase {
        case .thinking: return .thinking
        case .responding: return .responding
        case .needsConfirm: return .listening
        case .done: return .idle
        }
    }

    private func badge(for phase: ReachActivityAttributes.Phase) -> String {
        switch phase {
        case .thinking: return "Working"
        case .responding: return "Answering"
        case .needsConfirm: return "Needs you"
        case .done: return "Done"
        }
    }
}

/// The Lock Screen / banner presentation.
struct LockScreenView: View {
    let state: ReachActivityAttributes.ContentState
    let threadID: String?

    private var working: Bool { state.phase == .thinking || state.phase == .responding }

    var body: some View {
        HStack(spacing: 12) {
            PulsingHaloMark(size: 40, activity: activity, animated: working)
            VStack(alignment: .leading, spacing: 3) {
                Text(state.chatTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                Text(state.line)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .contentTransition(.opacity)
                if let confirm = state.confirm {
                    ConfirmButtons(confirm: confirm)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .widgetURL(ReachLiveActivityWidget.chatURL(threadID))
    }

    private var activity: HaloLogo.Activity {
        switch state.phase {
        case .thinking: return .thinking
        case .responding: return .responding
        case .needsConfirm: return .listening
        case .done: return .idle
        }
    }
}

/// Approve / Skip buttons for a `needsConfirm` prompt, shared by the Dynamic
/// Island expanded view and the Lock Screen. Each button runs
/// ``ReachConfirmIntent`` in the app's process (background-launched for the tap
/// if needed), which writes the answer straight to CloudKit — so the user
/// approves or skips a gated action right from the island, without opening the
/// app. Tapping elsewhere on the activity still deep-links into the chat.
struct ConfirmButtons: View {
    let confirm: ReachActivityAttributes.Confirm

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: ReachConfirmIntent(token: confirm.token, approved: true, threadID: confirm.threadID)) {
                Label("Approve", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .tint(HaloWidgetStyle.accent)

            Button(intent: ReachConfirmIntent(token: confirm.token, approved: false, threadID: confirm.threadID)) {
                Label("Skip", systemImage: "xmark")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .tint(.white.opacity(0.6))
        }
        .buttonStyle(.bordered)
        .tint(HaloWidgetStyle.accent)
    }
}

/// The brand mark, pulsing (opacity + scale) while Halo is working. The pulse is
/// a `repeatForever` animation — Live Activities render it where they can; the
/// `WorkingSpinner` is the guaranteed motion alongside it.
struct PulsingHaloMark: View {
    let size: CGFloat
    let activity: HaloLogo.Activity
    let animated: Bool

    @State private var pulse = false

    var body: some View {
        HaloLogo(size: size, activity: activity)
            .opacity(animated ? (pulse ? 1.0 : 0.45) : 1.0)
            .scaleEffect(animated ? (pulse ? 1.0 : 0.9) : 1.0)
            .onAppear {
                guard animated else { return }
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

enum HaloWidgetStyle {
    static let accent = Color(red: 0.49, green: 0.83, blue: 0.99)
}
