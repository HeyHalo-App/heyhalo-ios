// SPDX-License-Identifier: Apache-2.0
import HaloReachKit
import SwiftUI
import UIKit

/// One chat bubble, ported from the Mac's `ChatBubble` (NotchSubviews): user
/// messages trail right in a brighter glass fill, Halo replies lead left in a
/// subtler fill. Border-free — the fill opacity does the work, exactly as the
/// Mac does it. A message may carry an image (ADR 0052): a photo the user sent
/// or a screenshot the Mac sent, rendered above the text (if any).
struct MessageBubble: View {
    let message: ReachMessage

    private var isUser: Bool { message.role == .user }
    private var hasText: Bool {
        !message.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                if let image = message.image {
                    ReachAttachmentImage(attachment: image)
                }
                if hasText {
                    bubbleText
                        .font(HaloiOSStyle.body)
                        .foregroundStyle(HaloiOSStyle.textPrimary)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: HaloiOSStyle.bubbleRadius, style: .continuous)
                                .fill(isUser ? HaloiOSStyle.userBubble : HaloiOSStyle.haloBubble)
                        )
                }
                // No "Sending / Delivered / read" receipts — Halo isn't a
                // messaging app. The proof your words landed is that Halo
                // immediately starts working (the live activity row), not a
                // delivery checkmark.
            }
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Halo replies render inline Markdown so `[title](url)` links become
    /// tappable (matching the Mac notch). User messages stay literal — we
    /// don't want to reinterpret what someone typed. Falls back to plain
    /// text if the body isn't valid Markdown.
    @ViewBuilder
    private var bubbleText: some View {
        if !isUser,
            let attributed = try? AttributedString(
                markdown: message.body,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
            )
        {
            Text(styledLinks(in: attributed))
                .tint(HaloiOSStyle.accent)
        } else {
            Text(message.body)
        }
    }

    /// Underline link runs so they read as tappable inside the bubble.
    private func styledLinks(in input: AttributedString) -> AttributedString {
        var attributed = input
        for run in attributed.runs where run.link != nil {
            attributed[run.range].underlineStyle = .single
        }
        return attributed
    }

    private var accessibilityLabel: String {
        let who = isUser ? "You" : "Halo"
        switch (message.image != nil, hasText) {
        case (true, true): return "\(who): \(message.body), with a photo"
        case (true, false): return "\(who) sent a photo"
        default: return "\(who): \(message.body)"
        }
    }
}

/// Renders a Reach image attachment. Sized from the encoded `width`/`height` so
/// the bubble doesn't reflow when the file loads, with a placeholder while the
/// asset is loading or if it failed to download. Tap to view full-screen.
private struct ReachAttachmentImage: View {
    let attachment: ReachMessage.ImageAttachment

    @State private var uiImage: UIImage?
    @State private var loadFailed = false
    @State private var zoomed = false

    /// Aspect from the encoded dimensions (falls back to 4:3 if absent).
    private var aspect: CGFloat {
        attachment.width > 0 && attachment.height > 0
            ? CGFloat(attachment.width) / CGFloat(attachment.height)
            : 4.0 / 3.0
    }

    var body: some View {
        content
            .aspectRatio(aspect, contentMode: .fit)
            .frame(maxWidth: 240, maxHeight: 320)
            .clipShape(RoundedRectangle(cornerRadius: HaloiOSStyle.bubbleRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: HaloiOSStyle.bubbleRadius, style: .continuous))
            .onTapGesture { if uiImage != nil { zoomed = true } }
            .task(id: attachment.localURL) { await load() }
            .fullScreenCover(isPresented: $zoomed) {
                if let uiImage { ImageZoomView(image: uiImage) { zoomed = false } }
            }
            .accessibilityAddTraits(uiImage != nil ? .isImage : [])
    }

    @ViewBuilder
    private var content: some View {
        if let uiImage {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: HaloiOSStyle.bubbleRadius, style: .continuous)
                .fill(HaloiOSStyle.haloBubble)
                .overlay {
                    Image(systemName: loadFailed ? "photo.badge.exclamationmark" : "photo")
                        .font(.system(size: 22))
                        .foregroundStyle(HaloiOSStyle.textSecondary)
                }
        }
    }

    private func load() async {
        guard let url = attachment.localURL else {
            loadFailed = true
            return
        }
        // Read the file bytes off the main actor (Data is Sendable; UIImage is
        // not, so decode back on the main actor).
        let data = await Task.detached(priority: .userInitiated) {
            try? Data(contentsOf: url)
        }.value
        if let data, let image = UIImage(data: data) {
            uiImage = image
            loadFailed = false
        } else {
            loadFailed = true
        }
    }
}

/// A minimal full-screen image viewer: the image on a black backdrop, tap
/// anywhere (or the close button) to dismiss.
private struct ImageZoomView: View {
    let image: UIImage
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .ignoresSafeArea()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.black.opacity(0.5)))
            }
            .padding(.trailing, 18)
            .padding(.top, 8)
            .accessibilityLabel("Close photo")
        }
        .contentShape(Rectangle())
        .onTapGesture { onClose() }
    }
}
