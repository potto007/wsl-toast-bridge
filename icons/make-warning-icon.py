#!/usr/bin/env python3
"""Draw the amber warning-triangle toast icon (512x512 RGBA PNG)."""
import sys

from PIL import Image, ImageDraw

out = sys.argv[1] if len(sys.argv) > 1 else "warning.png"
S = 512
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
tri = [(S * 0.5, S * 0.06), (S * 0.97, S * 0.90), (S * 0.03, S * 0.90)]
d.polygon(tri, fill=(255, 179, 0, 255))
w = S * 0.055
d.rounded_rectangle([S * 0.5 - w, S * 0.32, S * 0.5 + w, S * 0.62], radius=w, fill=(40, 30, 0, 255))
r = S * 0.062
d.ellipse([S * 0.5 - r, S * 0.72 - r, S * 0.5 + r, S * 0.72 + r], fill=(40, 30, 0, 255))
img.save(out)
print(f"saved {out}")
