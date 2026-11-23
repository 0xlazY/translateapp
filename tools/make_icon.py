#!/usr/bin/env python3
"""Draws the Pandouchka logo: a panda whose ears are the French and Russian flags.
Usage: python3 tools/make_icon.py OUTPUT.png [size]"""
import sys
from PIL import Image, ImageDraw

S = 4096  # draw large, downscale for smooth edges
NAVY = (27, 33, 64)
NAVY2 = (39, 50, 98)
WHITE = (250, 248, 242)
BLACK = (24, 24, 30)
BLUE = (39, 71, 208)
RED = (211, 34, 60)
FR_BLUE = (0, 85, 164)
FR_RED = (239, 65, 53)
RU_BLUE = (0, 57, 166)
RU_RED = (213, 43, 30)
PINK = (244, 160, 170)


def u(v):
    return int(v * S / 1024)


def ear(img, cx, cy, r, kind):
    """A round ear filled with a flag, with a black rim."""
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    flag = Image.new("RGB", (S, S), WHITE)
    d = ImageDraw.Draw(flag)
    x0, y0, w = cx - r, cy - r, 2 * r
    if kind == "fr":
        d.rectangle([x0, y0, x0 + w / 3, y0 + w], fill=FR_BLUE)
        d.rectangle([x0 + 2 * w / 3, y0, x0 + w, y0 + w], fill=FR_RED)
    else:
        d.rectangle([x0, y0 + w / 3, x0 + w, y0 + 2 * w / 3], fill=RU_BLUE)
        d.rectangle([x0, y0 + 2 * w / 3, x0 + w, y0 + w], fill=RU_RED)
    rim = u(26)
    ImageDraw.Draw(img).ellipse([cx - r - rim, cy - r - rim, cx + r + rim, cy + r + rim], fill=BLACK)
    img.paste(flag, (0, 0), mask)


def main():
    out = sys.argv[1]
    size = int(sys.argv[2]) if len(sys.argv) > 2 else 1024
    img = Image.new("RGB", (S, S), NAVY)
    d = ImageDraw.Draw(img)
    # Soft radial glow behind the head.
    for i in range(60, 0, -1):
        t = i / 60
        col = tuple(int(NAVY[k] + (NAVY2[k] - NAVY[k]) * (1 - t)) for k in range(3))
        r = u(150 + 400 * t)
        d.ellipse([S / 2 - r, u(560) - r, S / 2 + r, u(560) + r], fill=col)

    ear(img, u(285), u(300), u(118), "fr")
    ear(img, u(739), u(300), u(118), "ru")
    d = ImageDraw.Draw(img)

    # Head, with a thin outline so the white flag stripe stays separate.
    d.ellipse([u(172), u(262), u(852), u(868)], fill=(205, 208, 222))
    d.ellipse([u(180), u(270), u(844), u(860)], fill=WHITE)

    # Eye patches, tilted teardrops made of two ellipses.
    for side in (-1, 1):
        cx = S / 2 + side * u(135)
        patch = Image.new("L", (S, S), 0)
        pd = ImageDraw.Draw(patch)
        pd.ellipse([cx - u(76), u(455), cx + u(76), u(670)], fill=255)
        patch = patch.rotate(side * 32, center=(cx, u(565)), resample=Image.BICUBIC)
        img.paste(BLACK, (0, 0), patch)
    d = ImageDraw.Draw(img)

    # Eyes.
    for side in (-1, 1):
        cx = S / 2 + side * u(128)
        d.ellipse([cx - u(40), u(520), cx + u(40), u(600)], fill=WHITE)
        d.ellipse([cx - u(24) + side * u(6), u(538), cx + u(24) + side * u(6), u(586)], fill=BLACK)
        d.ellipse([cx - u(12) + side * u(10), u(544), cx + u(2) + side * u(10), u(558)], fill=WHITE)

    # Cheeks.
    for side in (-1, 1):
        cx = S / 2 + side * u(215)
        d.ellipse([cx - u(42), u(680), cx + u(42), u(726)], fill=PINK)

    # Nose and mouth.
    d.rounded_rectangle([S / 2 - u(48), u(660), S / 2 + u(48), u(712)], radius=u(26), fill=BLACK)
    w = u(12)
    d.arc([S / 2 - u(70), u(680), S / 2, u(760)], start=10, end=150, fill=BLACK, width=w)
    d.arc([S / 2, u(680), S / 2 + u(70), u(760)], start=30, end=170, fill=BLACK, width=w)

    # Scarf: a band in the shared blue-white-red.
    band_top = u(842)
    for i, col in enumerate((BLUE, WHITE, RED)):
        y = band_top + i * u(34)
        d.rounded_rectangle([u(250), y, u(774), y + u(34)], radius=u(17), fill=col)

    img = img.resize((size, size), Image.LANCZOS)
    img.save(out)


if __name__ == "__main__":
    main()
