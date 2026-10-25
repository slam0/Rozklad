#!/usr/bin/env python3
"""Rysuje ikonę i ekrany startowe aplikacji (Resources/*.png). Wymaga Pillow: pip install pillow."""
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources")
FONT_DIR = "/usr/share/fonts/opentype/inter/"
NAME = "Waluty"
FOOT = "nazarOvsky 2024-2026"
ACCENT_T, ACCENT_B = (140, 220, 105), (40, 140, 40)       # zielony żel (motyw Zieleń)

def font(name, size):
    for p in (FONT_DIR + name, "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            pass
    return ImageFont.load_default()

def vgrad(size, top, bot):
    w, h = size
    g = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return g.resize((w, h))

def rounded_mask(size, r):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], r, fill=255)
    return m

def coin(base, cx, cy, r, glyph, top, bot, rim_top, rim_bot, gfont):
    """moneta z metaliczną obwódką i błyszczącą górą"""
    S = base.size[0]
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    # cień
    sh = Image.new("L", base.size, 0)
    ImageDraw.Draw(sh).ellipse([cx - r, cy - r + r * 0.10, cx + r, cy + r + r * 0.10], fill=190)
    sh = sh.filter(ImageFilter.GaussianBlur(S * 0.012))
    base.paste((0, 0, 0), (0, 0), sh)
    # obwódka
    rim = vgrad((S, S), rim_top, rim_bot)
    m = Image.new("L", base.size, 0)
    ImageDraw.Draw(m).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    base.paste(rim, (0, 0), m)
    # tarcza
    r2 = r * 0.86
    face = vgrad((S, S), top, bot)
    m2 = Image.new("L", base.size, 0)
    ImageDraw.Draw(m2).ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=255)
    base.paste(face, (0, 0), m2)
    # połysk
    gl = Image.new("L", base.size, 0)
    gd = ImageDraw.Draw(gl)
    gd.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=255)
    cut = Image.new("L", base.size, 0)
    ImageDraw.Draw(cut).ellipse([cx - r2 * 1.5, cy - r2 * 0.25, cx + r2 * 1.5, cy + r2 * 2.2], fill=255)
    gl = ImageChops.subtract(gl, cut).filter(ImageFilter.GaussianBlur(S * 0.004))
    base.paste((255, 255, 255), (0, 0), gl.point(lambda v: int(v * 0.45)))
    # znak
    d = ImageDraw.Draw(base)
    bb = d.textbbox((0, 0), glyph, font=gfont)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    tx, ty = cx - tw / 2 - bb[0], cy - th / 2 - bb[1]
    d.text((tx, ty + S * 0.008), glyph, font=gfont, fill=(20, 70, 20))
    d.text((tx, ty), glyph, font=gfont, fill=(250, 255, 245))

def make_icon(S=1024):
    img = vgrad((S, S), (92, 94, 98), (14, 14, 16))
    # zielona poświata pośrodku
    glow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(glow).ellipse([S * 0.18, S * 0.30, S * 0.82, S * 0.82], fill=150)
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.10))
    img.paste((70, 190, 70), (0, 0), glow.point(lambda v: int(v * 0.55)))
    gfont = font("Inter-Black.otf", int(S * 0.34))
    # tylna moneta (dolar), przednia (euro)
    coin(img, S * 0.60, S * 0.38, S * 0.25, "$", (110, 150, 110), (30, 80, 35), (205, 215, 205), (90, 100, 90), gfont)
    coin(img, S * 0.40, S * 0.60, S * 0.28, "€", ACCENT_T, ACCENT_B, (235, 240, 235), (110, 120, 110), gfont)
    # szklany połysk na górnej połowie
    gloss = Image.new("L", (S, S), 0)
    gd = ImageDraw.Draw(gloss)
    gd.ellipse([-S * 0.35, -S * 1.05, S * 1.35, S * 0.52], fill=255)
    gloss = gloss.filter(ImageFilter.GaussianBlur(S * 0.004))
    topfade = vgrad((S, S), (255, 255, 255), (255, 255, 255)).convert("L")
    img.paste((255, 255, 255), (0, 0), gloss.point(lambda v: int(v * 0.22)))
    return img

def save_resized(img, size, name):
    img.resize((size, size), Image.LANCZOS).convert("RGB").save(os.path.join(OUT, name))

def make_splash(icon, W, H):
    cx, cy = W / 2, H * 0.40
    img = Image.new("RGB", (W, H), (14, 14, 14))
    d = ImageDraw.Draw(img)
    n = 24
    R = math.hypot(W, H)
    for i in range(n):
        a0 = 2 * math.pi * i / n
        a1 = 2 * math.pi * (i + 1) / n
        if i % 2 == 0:
            d.polygon([(cx, cy), (cx + R * math.cos(a0), cy + R * math.sin(a0)), (cx + R * math.cos(a1), cy + R * math.sin(a1))], fill=(70, 70, 72))
    # delikatne przyciemnienie rogów
    vig = Image.new("L", (W, H), 0)
    ImageDraw.Draw(vig).ellipse([-W * 0.4, -H * 0.2, W * 1.4, H * 1.2], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(W * 0.15))
    dark = Image.new("RGB", (W, H), (0, 0, 0))
    img = Image.composite(img, dark, vig.point(lambda v: int(120 + v * 135 / 255)))
    # ikona z zaokrąglonymi rogami i odbiciem
    sz = int(W * 0.37)
    ic = icon.resize((sz, sz), Image.LANCZOS)
    m = rounded_mask((sz, sz), int(sz * 0.22))
    x0, y0 = int(cx - sz / 2), int(cy - sz / 2)
    refl = ic.transpose(Image.FLIP_TOP_BOTTOM)
    fade = vgrad((sz, sz), (110, 110, 110), (0, 0, 0)).convert("L")
    rm = ImageChops.multiply(ImageChops.multiply(m.transpose(Image.FLIP_TOP_BOTTOM), fade), Image.new("L", (sz, sz), 255))
    refl_layer = Image.new("RGB", (sz, sz))
    refl_layer.paste(refl, (0, 0))
    img.paste(refl_layer.crop((0, 0, sz, int(sz * 0.45))), (x0, y0 + sz - int(sz * 0.12)), rm.crop((0, 0, sz, int(sz * 0.45))).point(lambda v: int(v * 0.5)))
    img.paste(ic, (x0, y0), m)
    d = ImageDraw.Draw(img)
    tf = font("Inter-BlackItalic.otf", int(W * 0.15))
    bb = d.textbbox((0, 0), NAME, font=tf)
    ty = int(cy + sz / 2 + H * 0.045)
    d.text((cx - (bb[2] - bb[0]) / 2 - bb[0] + 2, ty + 3 - bb[1]), NAME, font=tf, fill=(0, 0, 0))
    d.text((cx - (bb[2] - bb[0]) / 2 - bb[0], ty - bb[1]), NAME, font=tf, fill=(255, 255, 255))
    ff = font("Inter-Medium.otf", int(W * 0.033))
    spaced = " ".join(FOOT) if False else FOOT
    track = int(W * 0.006)
    widths = [d.textlength(ch, font=ff) + track for ch in spaced]
    total = sum(widths) - track
    x = cx - total / 2
    y = H - int(H * 0.045) - int(W * 0.033)
    for ch, w in zip(spaced, widths):
        d.text((x, y), ch, font=ff, fill=(235, 235, 235))
        x += w
    return img

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    icon = make_icon(1024)
    save_resized(icon, 114, "Icon@2x.png")
    save_resized(icon, 57, "Icon.png")
    save_resized(icon, 58, "Icon-Small@2x.png")
    save_resized(icon, 29, "Icon-Small.png")
    s = make_splash(icon, 640, 960)
    s.save(os.path.join(OUT, "Default@2x.png"))
    s.resize((320, 480), Image.LANCZOS).save(os.path.join(OUT, "Default.png"))
    make_splash(icon, 640, 1136).save(os.path.join(OUT, "Default-568h@2x.png"))
    icon.resize((512, 512), Image.LANCZOS).convert("RGB").save(os.path.join(OUT, "..", "icon-512.png"))
    print("gotowe")
