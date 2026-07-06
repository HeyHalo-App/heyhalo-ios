#!/usr/bin/env python3
"""Generate the HaloiOS app icon (1024x1024, opaque) from the same halo mark
the app draws in SwiftUI (`Sources/Branding/HaloLogo.swift`).

Re-run after changing the mark: `python3 generate_appicon.py`. Writes
AppIcon-1024.png into Assets.xcassets/AppIcon.appiconset/. Kept reproducible
(like generate_xcodeproj.rb) instead of checking in an opaque binary blob with
no provenance.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "Assets.xcassets", "AppIcon.appiconset", "AppIcon-1024.png")

# Canvas: near-black vertical wash (HaloiOSStyle.canvasTop -> black). Opaque:
# iOS icons must not carry an alpha channel.
TOP = (13, 15, 20)
BOT = (0, 0, 0)


def color_at(t):
    """Cyan->purple folded gradient (HaloLogo.colorAt, .idle)."""
    low = (0.30, 0.72, 1.00)
    high = (0.66, 0.50, 0.98)
    folded = abs(t - 0.5) * 2.0
    mix = 0.5 + 0.5 * math.cos(folded * math.pi)
    return tuple(low[i] + (high[i] - low[i]) * mix for i in range(3))


def build_background():
    bg = Image.new("RGB", (SIZE, SIZE), BOT)
    d = ImageDraw.Draw(bg)
    for y in range(SIZE):
        f = y / (SIZE - 1)
        r = int(TOP[0] + (BOT[0] - TOP[0]) * f)
        g = int(TOP[1] + (BOT[1] - TOP[1]) * f)
        b = int(TOP[2] + (BOT[2] - TOP[2]) * f)
        d.line([(0, y), (SIZE, y)], fill=(r, g, b))
    return bg


def draw_dots(layer, scale_dot, alpha_mul):
    """Draw the three dot-rings onto an RGBA layer. `scale_dot`/`alpha_mul`
    let the caller render a fat, faint copy for the glow pass."""
    d = ImageDraw.Draw(layer)
    center = SIZE / 2
    outer = SIZE / 2 * 0.82
    rings = [
        (outer, 0.55, 0.0),
        (outer * 0.92, 1.00, math.pi / 36),
        (outer * 0.84, 0.65, math.pi / 18),
    ]
    dot_count = 96  # denser than the live view for a full halo at icon scale
    base = SIZE / 60.0
    peak = 0.62
    for radius, dot_scale, offset in rings:
        for i in range(dot_count):
            t = i / dot_count
            angle = t * 2 * math.pi - math.pi / 2 + offset
            x = center + math.cos(angle) * radius
            y = center + math.sin(angle) * radius
            raw = abs(t - peak)
            wrap = min(raw, 1 - raw)
            envelope = max(0.0, math.cos(wrap * math.pi))
            brightness = envelope
            size = base * dot_scale * (0.45 + 0.85 * brightness) * scale_dot
            opacity = (0.18 + 0.82 * brightness) * alpha_mul
            cr, cg, cb = color_at(t)
            col = (int(cr * 255), int(cg * 255), int(cb * 255), int(min(1.0, opacity) * 255))
            d.ellipse([x - size / 2, y - size / 2, x + size / 2, y + size / 2], fill=col)


def main():
    bg = build_background()

    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw_dots(glow, scale_dot=2.4, alpha_mul=0.5)
    glow = glow.filter(ImageFilter.GaussianBlur(radius=18))

    crisp = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw_dots(crisp, scale_dot=1.0, alpha_mul=1.0)

    out = bg.convert("RGBA")
    out.alpha_composite(glow)
    out.alpha_composite(crisp)
    out.convert("RGB").save(OUT)
    print("Wrote", OUT)


if __name__ == "__main__":
    main()
