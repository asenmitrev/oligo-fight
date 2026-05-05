#!/usr/bin/env python3
"""Generate asen-gong.png sprite sheet (256x256, 4 frames of 128x128)."""
from PIL import Image, ImageDraw

W, H = 128, 128
frames = []

for i in range(4):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # --- Asen character (centered) ---
    # Conical hat
    d.polygon([(36,22),(60,8),(84,22)], fill="#DAA520", outline="#8B7D2C", width=2)
    d.ellipse([44, 20, 74, 38], fill="#DAA520", outline="#8B7D2C", width=2)
    # Face
    d.ellipse([50, 30, 68, 46], fill="#DEB887")
    # Body / shirt
    d.rectangle([46, 44, 66, 58], fill="#3B4A62")
    # Arms
    d.rectangle([40, 44, 48, 52], fill="#3B4A62")
    d.rectangle([66, 44, 74, 52], fill="#3B4A62")
    # Hands
    d.ellipse([38, 48, 44, 54], fill="#DEB887")
    d.ellipse([70, 48, 76, 54], fill="#DEB887")
    # Legs / jeans
    d.rectangle([48, 60, 56, 82], fill="#2E4057")
    d.rectangle([60, 60, 68, 82], fill="#2E4057")
    # Shoes
    d.rectangle([46, 82, 56, 88], fill="#1a1a1a")
    d.rectangle([60, 82, 70, 88], fill="#1a1a1a")

    # --- Gong (right side) ---
    gong_x, gong_y = 96, 48
    gong_r = 22

    if i == 0:
        # Frame 1: wind-up, arm raised
        d.ellipse([gong_x - gong_r, gong_y - gong_r,
                   gong_x + gong_r, gong_y + gong_r],
                  fill="#DAA520", outline="#8B6914", width=3)
        d.ellipse([gong_x - 14, gong_y - 14,
                   gong_x + 14, gong_y + 14],
                  fill=None, outline="#C49B1F", width=1)
        # Mallet raised
        d.line([(72, 48), (82, 36)], fill="#8B4513", width=3)
        d.ellipse([78, 30, 86, 38], fill="#654321")

    elif i == 1:
        # Frame 2: impact!
        d.ellipse([gong_x - gong_r, gong_y - gong_r,
                   gong_x + gong_r, gong_y + gong_r],
                  fill="#FFD700", outline="#8B6914", width=3)
        # Impact flash
        d.ellipse([gong_x - 8, gong_y - 8,
                   gong_x + 8, gong_y + 8],
                  fill="#FFFFFF")
        # Impact lines
        for angle in range(0, 360, 45):
            import math
            cx, cy = gong_x, gong_y
            x1 = cx + int(10 * math.cos(math.radians(angle)))
            y1 = cy + int(10 * math.sin(math.radians(angle)))
            x2 = cx + int(18 * math.cos(math.radians(angle)))
            y2 = cy + int(18 * math.sin(math.radians(angle)))
            d.line([(x1, y1), (x2, y2)], fill="#FFD700", width=2)
        # Mallet at gong
        d.line([(72, 48), (gong_x - 5, gong_y)], fill="#8B4513", width=3)
        d.ellipse([gong_x - 10, gong_y - 5, gong_x - 2, gong_y + 3], fill="#654321")

    elif i == 2:
        # Frame 3: shockwaves expanding
        d.ellipse([gong_x - gong_r, gong_y - gong_r,
                   gong_x + gong_r, gong_y + gong_r],
                  fill="#DAA520", outline="#8B6914", width=3)
        # Shockwave rings
        d.ellipse([gong_x - 30, gong_y - 30,
                   gong_x + 30, gong_y + 30],
                  fill=None, outline="#FFD700", width=2)
        d.ellipse([gong_x - 40, gong_y - 40,
                   gong_x + 40, gong_y + 40],
                  fill=None, outline="#FFA500", width=1)
        # Radiating lines
        import math
        for angle in range(0, 360, 30):
            cx, cy = gong_x, gong_y
            x1 = cx + int(24 * math.cos(math.radians(angle)))
            y1 = cy + int(24 * math.sin(math.radians(angle)))
            x2 = cx + int(40 * math.cos(math.radians(angle)))
            y2 = cy + int(40 * math.sin(math.radians(angle)))
            d.line([(x1, y1), (x2, y2)], fill="#FFD700", width=1)
        # Follow-through arm
        d.line([(72, 48), (90, 50)], fill="#8B4513", width=3)

    else:
        # Frame 4: big shockwaves, fading
        d.ellipse([gong_x - gong_r, gong_y - gong_r,
                   gong_x + gong_r, gong_y + gong_r],
                  fill="#DAA520", outline="#8B6914", width=3)
        # Big shockwaves
        d.ellipse([gong_x - 45, gong_y - 45,
                   gong_x + 45, gong_y + 45],
                  fill=None, outline="#FFD700", width=2)
        d.ellipse([gong_x - 55, gong_y - 55,
                   gong_x + 55, gong_y + 55],
                  fill=None, outline="#FFA500", width=1)
        d.ellipse([gong_x - 65, gong_y - 65,
                   gong_x + 65, gong_y + 65],
                  fill=None, outline="#FF8C00", width=1)
        # Radiating lines wider
        import math
        for angle in range(0, 360, 25):
            cx, cy = gong_x, gong_y
            x1 = cx + int(28 * math.cos(math.radians(angle)))
            y1 = cy + int(28 * math.sin(math.radians(angle)))
            x2 = cx + int(55 * math.cos(math.radians(angle)))
            y2 = cy + int(55 * math.sin(math.radians(angle)))
            d.line([(x1, y1), (x2, y2)], fill="#FFD700", width=1)
        # Arm returning
        d.line([(72, 48), (78, 42)], fill="#8B4513", width=3)

    frames.append(img)

# Composite into 256x256 sheet (2x2 grid)
sheet = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
positions = [(0, 0), (128, 0), (0, 128), (128, 128)]
for frame, (px, py) in zip(frames, positions):
    sheet.paste(frame, (px, py))

sheet.save("assets/asen/asen-gong.png")
print("Generated assets/asen/asen-gong.png")
