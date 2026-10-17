import os
import numpy as np
from PIL import Image

def make_transparent_background(img, bg_color=(245, 244, 246), tolerance=28):
    """Replaces near-white background with transparent alpha."""
    img = img.convert("RGBA")
    arr = np.array(img, dtype=np.float32)
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    
    # Distance from background color
    dist = np.sqrt((r - bg_color[0])**2 + (g - bg_color[1])**2 + (b - bg_color[2])**2)
    
    # Smooth alpha transition
    alpha = np.clip((dist - 10) / tolerance * 255.0, 0, 255)
    arr[:, :, 3] = np.minimum(a, alpha)
    
    return Image.fromarray(np.uint8(arr), mode="RGBA")

def main():
    branding_dir = "apps/vhunambi_client/assets/branding"
    artwork_dir = "apps/vhunambi_client/assets/artwork"
    os.makedirs(branding_dir, exist_ok=True)
    os.makedirs(artwork_dir, exist_ok=True)

    # -------------------------------------------------------------
    # 1. Slice Vhunambi Music Brand Showcase.png (1536 x 1024)
    # -------------------------------------------------------------
    showcase_path = os.path.join(branding_dir, "Vhunambi Music Brand Showcase.png")
    if os.path.exists(showcase_path):
        img = Image.open(showcase_path).convert("RGBA")
        w, h = img.size
        print(f"Loaded Showcase ({w}x{h})")

        # Top Wordmark: tight bounding box around the brush text & tagline
        wordmark_box = (170, 70, 1370, 480)
        wordmark_raw = img.crop(wordmark_box)
        wordmark_raw.save(os.path.join(branding_dir, "vhunambi_wordmark_raw.png"), "PNG")
        
        # Transparent alpha wordmark
        wordmark_trans = make_transparent_background(wordmark_raw, bg_color=(246, 245, 247), tolerance=30)
        wordmark_trans.save(os.path.join(branding_dir, "vhunambi_wordmark.png"), "PNG")
        print("Saved vhunambi_wordmark.png (transparent)")

        # Dark App Icon Squircle
        # Bounding box of the dark squircle: x: 310 to 715, y: 535 to 940 (size 405x405)
        dark_box = (316, 545, 712, 941)
        dark_squircle = img.crop(dark_box)
        dark_1024 = dark_squircle.resize((1024, 1024), Image.Resampling.LANCZOS)
        dark_1024.save(os.path.join(branding_dir, "app_icon_dark.png"), "PNG")
        print("Saved app_icon_dark.png (1024x1024)")

        # Full-Bleed Dark App Icon (for iOS/Android launcher store icons)
        # Background color sampled from center of dark squircle: (8, 16, 36)
        fullbleed_bg = Image.new("RGBA", (1024, 1024), (8, 16, 36, 255))
        # Center the scaled glyph inside fullbleed_bg
        glyph_crop = dark_squircle.crop((40, 40, dark_squircle.width - 40, dark_squircle.height - 40))
        glyph_scaled = glyph_crop.resize((900, 900), Image.Resampling.LANCZOS)
        fullbleed_bg.paste(glyph_scaled, (62, 62), glyph_scaled)
        fullbleed_bg.save(os.path.join(branding_dir, "app_icon_fullbleed.png"), "PNG")
        print("Saved app_icon_fullbleed.png (1024x1024)")

        # Android Launcher Mipmaps
        res_dir = "apps/vhunambi_client/android/app/src/main/res"
        mipmaps = {
            "mipmap-mdpi": 48,
            "mipmap-hdpi": 72,
            "mipmap-xhdpi": 96,
            "mipmap-xxhdpi": 144,
            "mipmap-xxxhdpi": 192,
        }
        for folder, size in mipmaps.items():
            fpath = os.path.join(res_dir, folder)
            if os.path.exists(fpath):
                icon_resized = fullbleed_bg.resize((size, size), Image.Resampling.LANCZOS)
                icon_resized.save(os.path.join(fpath, "ic_launcher.png"), "PNG")
                print(f"Updated Android {folder}/ic_launcher.png ({size}x{size})")

        # Light App Icon Squircle
        light_box = (824, 545, 1220, 941)
        light_squircle = img.crop(light_box)
        light_1024 = light_squircle.resize((1024, 1024), Image.Resampling.LANCZOS)
        light_1024.save(os.path.join(branding_dir, "app_icon_light.png"), "PNG")
        print("Saved app_icon_light.png (1024x1024)")

        # Isolated V Glyph (512x512)
        dw, dh = dark_squircle.size
        glyph_box = (int(dw * 0.12), int(dh * 0.12), int(dw * 0.88), int(dh * 0.88))
        glyph = dark_squircle.crop(glyph_box).resize((512, 512), Image.Resampling.LANCZOS)
        glyph.save(os.path.join(branding_dir, "vhunambi_glyph.png"), "PNG")
        print("Saved vhunambi_glyph.png (512x512)")

    # -------------------------------------------------------------
    # 2. Slice Vhunambi_ Five Voices, One Vision.png (1672 x 941)
    # -------------------------------------------------------------
    voices_path = os.path.join(artwork_dir, "Vhunambi_ Five Voices, One Vision.png")
    if os.path.exists(voices_path):
        img_v = Image.open(voices_path).convert("RGBA")
        vw, vh = img_v.size
        print(f"Loaded Five Voices ({vw}x{vh})")

        # Fine-tuned bounding boxes for each character to eliminate text bleed
        # Col 0: Griot / Elder
        elder_box = (15, 175, 335, 495)
        # Col 1: Youthful Poet (starts y:215 to avoid orange wordmark "M")
        poet_box = (345, 215, 665, 535)
        # Col 2: Soulful Crooner (starts y:225 to avoid "MUSIC • FEEL • ESCAPE")
        crooner_box = (678, 225, 998, 545)
        # Col 3: Ceremonial Cantor (adjusted x to avoid right panel border line)
        cantor_box = (1005, 185, 1318, 498)
        # Col 4: Modern Producer (x:1340 to 1660)
        producer_box = (1340, 180, 1660, 500)

        timbre_configs = [
            ("timbre_elder.png", elder_box),
            ("timbre_poet.png", poet_box),
            ("timbre_crooner.png", crooner_box),
            ("timbre_cantor.png", cantor_box),
            ("timbre_producer.png", producer_box),
        ]

        for fname, box in timbre_configs:
            crop = img_v.crop(box)
            # Ensure exact 1:1 square
            cw, ch = crop.size
            side = min(cw, ch)
            sq_crop = crop.crop((0, 0, side, side))
            avatar_512 = sq_crop.resize((512, 512), Image.Resampling.LANCZOS)
            avatar_512.save(os.path.join(artwork_dir, fname), "PNG")
            print(f"Saved {fname} (512x512 - pixel perfected)")

    # -------------------------------------------------------------
    # 3. Heritage Crate Cover: Vhunambi_ African Sunset Melodies.png
    # -------------------------------------------------------------
    melodies_path = os.path.join(artwork_dir, "Vhunambi_ African Sunset Melodies.png")
    if os.path.exists(melodies_path):
        img_m = Image.open(melodies_path).convert("RGBA")
        crate_512 = img_m.resize((512, 512), Image.Resampling.LANCZOS)
        crate_512.save(os.path.join(artwork_dir, "heritage_crate_cover.png"), "PNG")
        print("Saved heritage_crate_cover.png (512x512)")

    # -------------------------------------------------------------
    # 4. Splash Hero: Vhunambi_ Music, Feel, Escape.png
    # -------------------------------------------------------------
    splash_src = os.path.join(artwork_dir, "Vhunambi_ Music, Feel, Escape.png")
    if os.path.exists(splash_src):
        img_s = Image.open(splash_src).convert("RGBA")
        splash_opt = img_s.resize((720, 1280), Image.Resampling.LANCZOS)
        splash_opt.save(os.path.join(artwork_dir, "splash_hero.png"), "PNG")
        print("Saved splash_hero.png (720x1280)")

    print("\n[SUCCESS] All production assets sliced, tuned, and optimized!")

if __name__ == "__main__":
    main()
