// SPDX-License-Identifier: Apache-2.0
import SwiftUI

// Mirrored from `packages/HaloUI/Sources/HaloUI/HaloLogo.swift` (the canonical
// brand mark). Vendored here — like `ReachMessage` — because the iOS target
// doesn't yet link the (Mac-leaning) `HaloUI` package; keep the drawing in sync
// with the canonical source until both are extracted into a shared
// pure-SwiftUI branding package. The AppKit `nsImage` renderer is intentionally
// omitted (it's macOS-only; iOS uses `ImageRenderer`/`UIImage` if ever needed).

/// Halo's brand mark — a dotted halo ring rendered procedurally so it stays
/// sharp at any size and can animate (breathing pulse, state colour shift).
/// Two slightly-offset concentric rings of dots with a brightness peak on the
/// lower-left arc and a cyan→purple gradient — "lit from one side," not a flat
/// halftone circle.
struct HaloLogo: View {

    enum Activity: Sendable, Equatable {
        case idle
        case listening
        case thinking
        case responding
        case paused
    }

    let size: CGFloat
    let activity: Activity
    /// 0…1, gates the breathing pulse. Drive it from a `TimelineView`
    /// (see ``AnimatedHaloLogo``) to animate.
    let intensity: Double
    /// Position (0…1, around the ring) of the bright arc — the "lit from one
    /// side" peak. Default 0.62 (lower-left, the resting look). Animate it 0→1
    /// to sweep the brightness around the halo's own dots — a loading spinner
    /// made of the mark itself, not a separate ring. (iOS addition over the
    /// canonical source.)
    let peak: Double
    /// Force a single tone (e.g. `.white`). When non-nil the cyan→purple
    /// gradient is bypassed and every dot uses this colour with the usual
    /// brightness/opacity envelope.
    let monochromeTint: Color?

    init(
        size: CGFloat = 64,
        activity: Activity = .idle,
        intensity: Double = 1.0,
        peak: Double = 0.62,
        monochromeTint: Color? = nil
    ) {
        self.size = size
        self.activity = activity
        self.intensity = intensity
        self.peak = peak
        self.monochromeTint = monochromeTint
    }

    var body: some View {
        Canvas(opaque: false) { context, canvasSize in
            let center = CGPoint(
                x: canvasSize.width / 2,
                y: canvasSize.height / 2
            )
            let outerRadius = min(canvasSize.width, canvasSize.height) / 2 * 0.84

            // Two concentric rings, slightly offset in angle so the dots don't
            // perfectly overlap. Outer ring uses smaller dots; inner uses
            // larger ones, giving the "lit halo" feel.
            let rings: [(radius: CGFloat, dotScale: CGFloat, angleOffset: Double)] = [
                (outerRadius, 0.55, 0.0),
                (outerRadius * 0.92, 1.00, .pi / 36),
                (outerRadius * 0.84, 0.65, .pi / 18)
            ]

            // Dot count scales with size — too few looks blocky big; too many
            // goes muddy small.
            let dotCount = max(28, min(72, Int(size * 0.9)))

            for ring in rings {
                for i in 0..<dotCount {
                    let t = Double(i) / Double(dotCount)
                    let angle = t * 2 * .pi - .pi / 2 + ring.angleOffset

                    let x = center.x + cos(angle) * ring.radius
                    let y = center.y + sin(angle) * ring.radius

                    // Brightness peaks at `peak` (default lower-left, t ≈ 0.62;
                    // animated when loading). `wrapDist` is the shortest distance
                    // around the ring to the peak.
                    let raw = abs(t - peak)
                    let wrapDist = min(raw, 1 - raw)
                    let envelope = max(0, cos(wrapDist * .pi))
                    let brightness = envelope * intensity

                    let baseDotSize = (size / 60) * ring.dotScale
                    let dotSize = baseDotSize * (0.45 + 0.85 * brightness)
                    let opacity = 0.18 + 0.82 * brightness

                    let color =
                        monochromeTint
                        ?? Self.colorAt(angleT: t, activity: activity)

                    let rect = CGRect(
                        x: x - dotSize / 2,
                        y: y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(color.opacity(opacity))
                    )
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Halo")
    }

    /// Brand-gradient palette, optionally tinted by activity. Idle is the
    /// canonical cyan→purple; listening warms to red; thinking cools to cyan;
    /// responding shifts mint; paused desaturates.
    private static func colorAt(angleT t: Double, activity: Activity) -> Color {
        let (low, high): (RGB, RGB)
        switch activity {
        case .idle:
            low = RGB(0.30, 0.72, 1.00)
            high = RGB(0.66, 0.50, 0.98)
        case .listening:
            low = RGB(1.00, 0.45, 0.55)
            high = RGB(1.00, 0.70, 0.40)
        case .thinking:
            low = RGB(0.30, 0.85, 1.00)
            high = RGB(0.40, 0.65, 1.00)
        case .responding:
            low = RGB(0.40, 0.95, 0.80)
            high = RGB(0.50, 0.80, 1.00)
        case .paused:
            low = RGB(0.55, 0.58, 0.62)
            high = RGB(0.70, 0.72, 0.78)
        }
        // Fold t∈[0,1] so opposite sides share a colour family — reads as a
        // halo, not a rainbow.
        let folded = abs(t - 0.5) * 2.0
        let mix = 0.5 + 0.5 * cos(folded * .pi)
        let rgb = low.lerp(to: high, t: mix)
        return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    private struct RGB {
        let r, g, b: Double
        init(_ r: Double, _ g: Double, _ b: Double) {
            self.r = r
            self.g = g
            self.b = b
        }
        func lerp(to other: RGB, t: Double) -> RGB {
            RGB(
                r + (other.r - r) * t,
                g + (other.g - g) * t,
                b + (other.b - b) * t
            )
        }
    }
}

// MARK: - Breathing wrapper

/// Wraps ``HaloLogo`` in a `TimelineView` that drives a slow breathing pulse via
/// `intensity`. Use anywhere the logo is on screen for more than a second — the
/// static version reads as a flat icon.
///
/// iOS addition over the canonical source: a `period` so callers can speed the
/// breath up while Halo is working (the old presence orb's 0.45s-vs-2.2s cue).
struct AnimatedHaloLogo: View {
    let size: CGFloat
    let activity: HaloLogo.Activity
    let monochromeTint: Color?
    /// Seconds per breath. ~4s at rest; drop to ~1s for a "thinking" cadence.
    let period: Double
    /// When true, the bright arc also travels around the ring — the halo loading
    /// as a spinner made of its OWN dots (splash, sign-in, thinking), instead of
    /// a separate ring orbiting outside it.
    let sweeps: Bool
    /// Seconds for one full lap of the bright arc.
    let sweepPeriod: Double

    init(
        size: CGFloat = 64,
        activity: HaloLogo.Activity = .idle,
        monochromeTint: Color? = nil,
        period: Double = 4.0,
        sweeps: Bool = false,
        sweepPeriod: Double = 1.6
    ) {
        self.size = size
        self.activity = activity
        self.monochromeTint = monochromeTint
        self.period = period
        self.sweeps = sweeps
        self.sweepPeriod = sweepPeriod
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            // Eased so the pulse lingers at the peak.
            let phase = sin(elapsed * .pi * 2 / max(0.2, period))
            // While loading, keep the dots brighter overall so the travelling
            // arc reads clearly; at rest it's a calmer breath.
            let intensity =
                sweeps
                ? 0.9 + 0.1 * (phase * 0.5 + 0.5)
                : 0.78 + 0.22 * (phase * 0.5 + 0.5)
            // Loading: the lit arc walks around the ring (0→1). At rest: fixed.
            let peak =
                sweeps
                ? (elapsed / max(0.3, sweepPeriod)).truncatingRemainder(dividingBy: 1)
                : 0.62
            HaloLogo(
                size: size,
                activity: activity,
                intensity: intensity,
                peak: peak,
                monochromeTint: monochromeTint
            )
        }
    }
}
