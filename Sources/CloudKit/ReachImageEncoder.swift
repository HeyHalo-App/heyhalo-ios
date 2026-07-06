// SPDX-License-Identifier: Apache-2.0
import HaloReachKit
import UIKit

/// Turns a picked photo into the outbound Reach image attachment (ADR 0052
/// slice 1): downscale so the longest side is at most 1024 px (matching the
/// Mac vision model's tiling clamp, so it never has to re-shrink), JPEG-encode,
/// and write to a temp file the `CKAsset` uploads from. Pure UIKit; the Mac's
/// `JPEGCodec` lives in a Mac-only package, so the phone encodes with `UIImage`.
enum ReachImageEncoder {
    /// Longest-side cap in pixels. Mirrors the vision model's `maxImageSide`.
    static let maxSide: CGFloat = 1024
    /// JPEG quality: legible for a screenshot / photo, well under a few hundred KB.
    static let quality: CGFloat = 0.7

    /// Decode raw image bytes (from `PhotosPicker`) then downscale + encode.
    /// Takes `Data` (Sendable) so the whole encode can run in a detached task
    /// off the main actor; `UIImage` is not Sendable.
    static func makeAttachment(from data: Data) -> ReachMessage.ImageAttachment? {
        guard let image = UIImage(data: data) else { return nil }
        return makeAttachment(from: image)
    }

    /// Downscale + JPEG-encode `image` to a temp file and return the attachment
    /// (its `localURL` is the file the `CKAsset` uploads from). Returns `nil` if
    /// encoding or the temp write fails.
    static func makeAttachment(from image: UIImage) -> ReachMessage.ImageAttachment? {
        guard let encoded = downscaledJPEG(image) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reach-outgoing-\(UUID().uuidString).jpg")
        do {
            try encoded.data.write(to: url, options: .atomic)
        } catch {
            return nil
        }
        return ReachMessage.ImageAttachment(
            localURL: url,
            mimeType: "image/jpeg",
            width: encoded.width,
            height: encoded.height
        )
    }

    /// Downscale to the longest-side cap and JPEG-encode. Renders at scale 1 so
    /// the point size equals the pixel size (the dimensions we put on the wire).
    static func downscaledJPEG(_ image: UIImage) -> (data: Data, width: Int, height: Int)? {
        let pixels = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
        guard pixels.width > 0, pixels.height > 0 else { return nil }
        let longest = max(pixels.width, pixels.height)
        let factor = longest > maxSide ? maxSide / longest : 1
        let target = CGSize(
            width: max(1, (pixels.width * factor).rounded()),
            height: max(1, (pixels.height * factor).rounded())
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let data = rendered.jpegData(compressionQuality: quality) else { return nil }
        return (data, Int(target.width), Int(target.height))
    }
}
