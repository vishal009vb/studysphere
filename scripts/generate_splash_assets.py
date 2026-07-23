import math
from PIL import Image, ImageDraw, ImageFilter

def generate_splash_assets():
    # Canvas dimensions for high-res screen (3x scale)
    w, h = 1242, 2688
    scale = 3.0  # 1 dp = 3 px

    # ---------------------------------------------------------
    # 1. CREATE BACKGROUND IMAGE (assets/splash_bg.png)
    # ---------------------------------------------------------
    bg = Image.new('RGBA', (w, h))
    draw = ImageDraw.Draw(bg)

    # Hero Gradient: #7B72E9 -> #9F97F2 -> #B8B2FF
    c0 = (123, 114, 233)
    c1 = (159, 151, 242)
    c2 = (184, 178, 255)

    for y in range(h):
        for x in range(w):
            t = (x / w + y / h) / 2.0
            if t <= 0.5:
                t2 = t * 2.0
                r = int(c0[0] + (c1[0] - c0[0]) * t2)
                g = int(c0[1] + (c1[1] - c0[1]) * t2)
                b = int(c0[2] + (c1[2] - c0[2]) * t2)
            else:
                t2 = (t - 0.5) * 2.0
                r = int(c1[0] + (c2[0] - c1[0]) * t2)
                g = int(c1[1] + (c2[1] - c1[1]) * t2)
                b = int(c1[2] + (c2[2] - c1[2]) * t2)
            draw.point((x, y), fill=(r, g, b, 255))

    # Floating Orbs
    orb1_r = int(40 * scale)
    orb1_cx = int(w * 0.07) + orb1_r
    orb1_cy = int(h * 0.08) + orb1_r
    orb1_layer = Image.new('RGBA', (w, h), (0,0,0,0))
    ImageDraw.Draw(orb1_layer).ellipse(
        [orb1_cx - orb1_r, orb1_cy - orb1_r, orb1_cx + orb1_r, orb1_cy + orb1_r],
        fill=(255, 255, 255, 20)
    )
    bg = Image.alpha_composite(bg, orb1_layer)

    orb2_r = int(60 * scale)
    orb2_cx = int(w * 0.95) - orb2_r
    orb2_cy = int(h * 0.88) - orb2_r
    orb2_layer = Image.new('RGBA', (w, h), (0,0,0,0))
    ImageDraw.Draw(orb2_layer).ellipse(
        [orb2_cx - orb2_r, orb2_cy - orb2_r, orb2_cx + orb2_r, orb2_cy + orb2_r],
        fill=(255, 255, 255, 15)
    )
    bg = Image.alpha_composite(bg, orb2_layer)

    orb3_r = int(50 * scale)
    orb3_cx = w + int(30 * scale) - orb3_r
    orb3_cy = int(h * 0.35) + orb3_r
    orb3_layer = Image.new('RGBA', (w, h), (0,0,0,0))
    ImageDraw.Draw(orb3_layer).ellipse(
        [orb3_cx - orb3_r, orb3_cy - orb3_r, orb3_cx + orb3_r, orb3_cy + orb3_r],
        fill=(255, 255, 255, 13)
    )
    bg = Image.alpha_composite(bg, orb3_layer)

    lcx = w // 2
    lcy = (h // 2) - int(104 * scale)

    # Concentric background rings
    ring_layer = Image.new('RGBA', (w, h), (0,0,0,0))
    rd = ImageDraw.Draw(ring_layer)
    ring_w = int(1.5 * scale)
    for r_dp, alpha in [(80, 38), (80, 30), (80, 23)]:
        r_px = int(r_dp * scale)
        rd.ellipse([lcx - r_px, lcy - r_px, lcx + r_px, lcy + r_px], outline=(255, 255, 255, alpha), width=ring_w)
    bg = Image.alpha_composite(bg, ring_layer)

    # Star particles
    positions = [
        [0.15, 0.18], [0.78, 0.12], [0.45, 0.07], [0.88, 0.45],
        [0.05, 0.55], [0.65, 0.82], [0.25, 0.88], [0.92, 0.72],
    ]
    particle_layer = Image.new('RGBA', (w, h), (0,0,0,0))
    pd = ImageDraw.Draw(particle_layer)
    for i, pos in enumerate(positions):
        t_val = (0.0 + i * 0.13) % 1.0
        opacity_val = (t_val * 2.0 if t_val < 0.5 else (1.0 - t_val) * 2.0) * 0.7
        alpha = int(opacity_val * 255)
        p_sz = int((4 + (i % 3) * 2.0) * scale)
        px_pos = int(w * pos[0])
        py_pos = int(h * pos[1])
        pd.ellipse([px_pos, py_pos, px_pos + p_sz, py_pos + p_sz], fill=(255, 255, 255, alpha))
    bg = Image.alpha_composite(bg, particle_layer)

    # Save background image
    bg.save("assets/splash_bg.png")
    print("Full Native Splash background saved to assets/splash_bg.png!")

    # ---------------------------------------------------------
    # 2. CREATE SPLASH LOGO (assets/splash_logo.png)
    # ---------------------------------------------------------
    # 512 x 512 px square icon canvas containing the logo card & glow ring
    sz = 512
    logo_img = Image.new('RGBA', (sz, sz), (0, 0, 0, 0))
    cx, cy = sz // 2, sz // 2

    # A) Outer Glow Circle: 390px, white 6% (15/255)
    outer_r = 195
    outer_layer = Image.new('RGBA', (sz, sz), (0,0,0,0))
    ImageDraw.Draw(outer_layer).ellipse([cx - outer_r, cy - outer_r, cx + outer_r, cy + outer_r], fill=(255, 255, 255, 15))
    logo_img = Image.alpha_composite(logo_img, outer_layer)

    # B) Card Shadows
    card_sz = 300
    card_r = 84
    s2_layer = Image.new('RGBA', (sz, sz), (0,0,0,0))
    ImageDraw.Draw(s2_layer).rounded_rectangle([cx - 160, cy - 160, cx + 160, cy + 160], radius=94, fill=(124, 114, 232, 102))
    s2_blur = s2_layer.filter(ImageFilter.GaussianBlur(radius=25))
    logo_img = Image.alpha_composite(logo_img, s2_blur)

    # C) Inner Card
    card_layer = Image.new('RGBA', (sz, sz), (0,0,0,0))
    ImageDraw.Draw(card_layer).rounded_rectangle(
        [cx - card_sz//2, cy - card_sz//2, cx + card_sz//2, cy + card_sz//2],
        radius=card_r, fill=(255, 255, 255, 38), outline=(255, 255, 255, 102), width=6
    )
    logo_img = Image.alpha_composite(logo_img, card_layer)

    # D) Brain Logo image inside Card
    logo_src = Image.open('assets/logo.png').convert('RGBA')
    logo_fit = 204
    logo_resized = logo_src.resize((logo_fit, logo_fit), Image.Resampling.LANCZOS)
    logo_img.paste(logo_resized, (cx - logo_fit//2, cy - logo_fit//2), mask=logo_resized)

    logo_img.save("assets/splash_logo.png")
    print("Splash logo created successfully at assets/splash_logo.png!")

if __name__ == "__main__":
    generate_splash_assets()
