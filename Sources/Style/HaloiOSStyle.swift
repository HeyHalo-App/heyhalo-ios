// SPDX-License-Identifier: Apache-2.0
import SwiftUI

/// The Halo design language, ported iOS-native (no AppKit) from the Mac's
/// notch / chat aesthetic so the phone feels like the same product.
///
/// The look is *holographic and alive*: a near-black glass
/// canvas, a single holographic cyan accent that means "system aware," warm
/// off-white text, and a breathing presence orb that encodes Halo's state.
///
/// Sizes are scaled up from the Mac's notch-tight 11pt toward comfortable phone
/// reading (15pt body), keeping the same proportions, palette, and corner /
/// padding rhythm.
enum HaloiOSStyle {

    // MARK: - Palette (mirrors the Mac "Jarvis" colors)

    /// Holographic cyan — the one accent. "System aware," not a cold blue.
    /// Mac: RGB(125, 212, 253) / #7DD4FD.
    static let accent = Color(red: 0.49, green: 0.83, blue: 0.99)

    /// Warm off-white primary text. Reads less clinical than pure white.
    /// Mac: RGB(235, 235, 230) / #EBEBE6.
    static let textPrimary = Color(red: 0.92, green: 0.92, blue: 0.90)

    /// Secondary / dim text and inactive controls.
    static let textSecondary = Color.white.opacity(0.55)

    /// Attention amber — distinct from cyan so it doesn't read as alarm.
    /// Mac: RGB(250, 191, 36) / #FABF24.
    static let attention = Color(red: 0.98, green: 0.75, blue: 0.14)

    /// The near-black canvas behind everything (matches the notch card).
    static let canvasTop = Color(red: 0.05, green: 0.06, blue: 0.08)
    static let canvasBottom = Color.black

    // MARK: - Bubble fills (mirror NotchSubviews ChatBubble)

    /// User bubble fill — semi-transparent white (Mac: white @ 0.16).
    static let userBubble = Color.white.opacity(0.16)
    /// Halo bubble fill — very subtle glass (Mac: white @ 0.06).
    static let haloBubble = Color.white.opacity(0.07)
    /// Confirm / system card fill — cyan glass (Mac: cyan @ 0.10).
    static let confirmFill = Color(red: 0.49, green: 0.83, blue: 0.99).opacity(0.10)
    static let confirmStroke = Color(red: 0.49, green: 0.83, blue: 0.99).opacity(0.45)

    // MARK: - Shape rhythm

    /// Bubble corner radius (Mac uses 9pt notch-tight; 18pt reads right at
    /// phone scale while keeping the continuous, soft-pill feel).
    static let bubbleRadius: CGFloat = 18
    /// Card corner radius for the confirm / system prompt.
    static let cardRadius: CGFloat = 16

    // MARK: - Typography (system font, like the Mac)

    static let body = Font.system(size: 16)
    static let bodyEmphasis = Font.system(size: 16, weight: .medium)
    static let title = Font.system(size: 17, weight: .semibold)
    static let caption = Font.system(size: 12, weight: .medium)
    static let captionMono = Font.system(size: 12, weight: .medium, design: .monospaced)

    // MARK: - The canvas

    /// The app background: a near-black vertical wash, like the expanded notch.
    static var canvas: some View {
        LinearGradient(
            colors: [canvasTop, canvasBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
