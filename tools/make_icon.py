"""Generates assets/icon.png (1024x1024). Run: python3 tools/make_icon.py"""
from PIL import Image, ImageDraw

S, K = 1024, 4  # final size, supersampling factor
W = S * K

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

# Diagonal gradient background.
bg = Image.new("RGB", (W, W))
px = bg.load()
c1, c2 = (44, 62, 140), (120, 70, 190)
for y in range(W):
    for x in range(W):
        px[x, y] = lerp(c1, c2, (x + y) / (2 * W))

mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, W - 1], radius=int(W * 0.225), fill=255)

card = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(card)
u = W / 1024

def window(x0, y0, x1, y1, body, bar, dots):
    d.rounded_rectangle([x0 * u, y0 * u, x1 * u, y1 * u], radius=60 * u, fill=body)
    d.rounded_rectangle([x0 * u, y0 * u, x1 * u, (y0 + 90) * u], radius=60 * u, fill=bar)
    d.rectangle([x0 * u, (y0 + 50) * u, x1 * u, (y0 + 90) * u], fill=bar)
    for i in range(3):
        cx, cy = (x0 + 60 + i * 52) * u, (y0 + 45) * u
        d.ellipse([cx - 14 * u, cy - 14 * u, cx + 14 * u, cy + 14 * u], fill=dots[i])

# Back window (the next tab stop), then the front, selected window with an accent ring.
window(250, 200, 840, 640, (255, 255, 255, 120), (255, 255, 255, 150), [(255, 255, 255, 200)] * 3)
d.rounded_rectangle([170 * u, 330 * u, 760 * u, 830 * u], radius=70 * u, outline=(255, 214, 102, 255), width=int(14 * u))
window(184, 344, 746, 816, (250, 250, 255, 255), (226, 230, 245, 255),
       [(255, 95, 86, 255), (255, 189, 46, 255), (39, 201, 63, 255)])
# Content lines in the front window.
for i, wd in enumerate((420, 340, 380)):
    d.rounded_rectangle([240 * u, (480 + i * 90) * u, (240 + wd) * u, (510 + i * 90) * u], radius=15 * u, fill=(190, 196, 225, 255))

out = Image.new("RGBA", (W, W), (0, 0, 0, 0))
out.paste(bg, (0, 0), mask)
out.alpha_composite(Image.composite(card, Image.new("RGBA", (W, W), (0, 0, 0, 0)), mask))
out.resize((S, S), Image.LANCZOS).save("assets/icon.png")
