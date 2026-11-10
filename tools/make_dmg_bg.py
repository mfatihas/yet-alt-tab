"""Generates assets/dmg-bg.png (600x400), the DMG window background. Run: python3 tools/make_dmg_bg.py"""
from PIL import Image, ImageDraw, ImageFont

W, H, K = 600, 400, 3
img = Image.new("RGB", (W * K, H * K))
px = img.load()
c1, c2 = (246, 247, 252), (226, 228, 244)
for y in range(H * K):
    t = y / (H * K)
    row = tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))
    for x in range(W * K):
        px[x, y] = row
d = ImageDraw.Draw(img)
col = (120, 90, 190)
# Arrow between the app icon (x=150) and the Applications link (x=450), both centered at y=190.
y = 190 * K
d.line([(215 * K, y), (365 * K, y)], fill=col, width=10 * K)
d.polygon([(385 * K, y), (350 * K, y - 28 * K), (350 * K, y + 28 * K)], fill=col)
font = ImageFont.load_default(size=22 * K)
text = "Drag YetAltTab to Applications"
w = d.textlength(text, font=font)
d.text(((W * K - w) / 2, 320 * K), text, fill=(90, 90, 120), font=font)
img.resize((W, H), Image.LANCZOS).save("assets/dmg-bg.png")
