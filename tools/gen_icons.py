#!/usr/bin/env python3
"""Génère les icônes PNG de l'app (sans dépendance externe).

Dessin neutre : dégradé bleu profond + chevron ascendant en vert/blanc.
Aucun indice géographique. Produit icon-192, icon-512 et icon-512-maskable.
"""
import struct
import zlib
import os

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "icons")

# Palette (RGB)
BG_TOP = (13, 47, 79)      # #0d2f4f
BG_BOT = (7, 26, 46)       # #071a2e
GREEN = (46, 204, 143)     # #2ecc8f
GREEN_SOFT = (84, 224, 170)
WHITE = (234, 242, 251)


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def make_png(size, maskable=False):
    # Cadre du symbole : sur les icônes maskables, on garde une marge de sécurité.
    px = bytearray()
    cx = size / 2.0

    # Géométrie d'un chevron ascendant (deux traits formant un ^), épais.
    scale = 0.62 if maskable else 0.74
    half = size * scale / 2.0
    apex_y = size * (0.50 - 0.20 * scale * 1.0)   # pointe haute
    base_y = size * (0.50 + 0.22 * scale * 1.0)   # extrémités basses
    apex_y = size * 0.34
    base_y = size * 0.70
    left_x = cx - half
    right_x = cx + half
    thickness = size * (0.085 if not maskable else 0.075)

    def dist_to_segment(px_, py_, ax, ay, bx, by):
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy
        if L2 == 0:
            return ((px_ - ax) ** 2 + (py_ - ay) ** 2) ** 0.5
        t = ((px_ - ax) * dx + (py_ - ay) * dy) / L2
        t = max(0.0, min(1.0, t))
        projx, projy = ax + t * dx, ay + t * dy
        return ((px_ - projx) ** 2 + (py_ - projy) ** 2) ** 0.5

    # Deux chevrons superposés pour un effet "ascension".
    chevrons = [
        (apex_y, base_y),
        (apex_y + size * 0.16, base_y + size * 0.16),
    ]

    for y in range(size):
        px.append(0)  # filtre PNG (None) par scanline
        t = y / (size - 1)
        bg = lerp(BG_TOP, BG_BOT, t)
        for x in range(size):
            r, g, b = bg

            # Dégradé radial doux au centre pour donner du relief.
            d = ((x - cx) ** 2 + (y - size * 0.5) ** 2) ** 0.5 / (size * 0.5)
            glow = max(0.0, 1.0 - d)
            r = min(255, round(r + glow * 14))
            g = min(255, round(g + glow * 20))
            b = min(255, round(b + glow * 30))

            # Chevrons
            for idx, (ay, by_) in enumerate(chevrons):
                d1 = dist_to_segment(x, y, left_x, by_, cx, ay)
                d2 = dist_to_segment(x, y, cx, ay, right_x, by_)
                dmin = min(d1, d2)
                if dmin <= thickness:
                    col = GREEN if idx == 0 else WHITE
                    if idx == 1:
                        col = GREEN_SOFT
                    # anti-aliasing simple sur le bord
                    edge = thickness - dmin
                    alpha = max(0.0, min(1.0, edge / 1.5))
                    r = round(r + (col[0] - r) * alpha)
                    g = round(g + (col[1] - g) * alpha)
                    b = round(b + (col[2] - b) * alpha)

            px.append(r)
            px.append(g)
            px.append(b)

    # Encodage PNG (RGB, 8 bits)
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        c += struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        return c

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    idat = zlib.compress(bytes(px), 9)
    png = sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")
    return png


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    specs = [
        ("icon-192.png", 192, False),
        ("icon-512.png", 512, False),
        ("icon-512-maskable.png", 512, True),
    ]
    for name, size, mask in specs:
        data = make_png(size, mask)
        path = os.path.join(OUT_DIR, name)
        with open(path, "wb") as f:
            f.write(data)
        print(f"écrit {name} ({len(data)} octets)")


if __name__ == "__main__":
    main()
