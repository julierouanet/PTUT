#!/usr/bin/env python3
"""
Régénère les icônes PWA (écran d'accueil iOS/Android) à partir du logo source
de l'hôpital. Script one-shot, à relancer manuellement si le logo change —
non branché sur un pipeline npm/flutter.

Usage :
    python -X utf8 scripts/generate_pwa_icons.py

Source  : flutter-app/assets/images/logo_hopital.png
Sorties : flutter-app/web/icons/Icon-192.png
          flutter-app/web/icons/Icon-512.png
          flutter-app/web/icons/Icon-maskable-192.png
          flutter-app/web/icons/Icon-maskable-512.png
          flutter-app/web/icons/Icon-apple-180.png
"""

import sys
from pathlib import Path
from PIL import Image

# Forcer UTF-8 sur la sortie standard (terminal Windows cp1252) — même garde que log_feature.py,
# nécessaire pour l'emoji ✅ affiché plus bas.
if sys.stdout.encoding and sys.stdout.encoding.lower() not in ('utf-8', 'utf8'):
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "flutter-app" / "assets" / "images" / "logo_hopital.png"
OUT_DIR = ROOT / "flutter-app" / "web" / "icons"

BACKGROUND = (255, 255, 255, 255)  # fond blanc opaque — iOS affiche le canal alpha en noir sinon

# Cible : (nom de fichier, taille, couverture logo/canevas).
# 90 % = icônes normales et apple-touch (aucun masque de forme appliqué par l'OS).
# 80 % = icônes maskable (safe-zone du disque visible après masque circulaire/squircle Android).
TARGETS = [
    ("Icon-192.png", 192, 0.90),
    ("Icon-512.png", 512, 0.90),
    ("Icon-maskable-192.png", 192, 0.80),
    ("Icon-maskable-512.png", 512, 0.80),
    ("Icon-apple-180.png", 180, 0.90),
]


def load_source() -> Image.Image:
    im = Image.open(SOURCE).convert("RGBA")
    # Recadre sur le contenu réel (bbox du canal alpha) pour repartir d'un logo sans marge parasite.
    bbox = im.split()[-1].getbbox()
    if bbox:
        im = im.crop(bbox)
    return im


def render_on_square(logo: Image.Image, size: int, coverage: float) -> Image.Image:
    """Compose le logo, centré et redimensionné, sur un carré opaque `size`x`size`."""
    canvas = Image.new("RGBA", (size, size), BACKGROUND)

    target = int(size * coverage)
    ratio = min(target / logo.width, target / logo.height)
    new_w, new_h = max(1, round(logo.width * ratio)), max(1, round(logo.height * ratio))
    resized = logo.resize((new_w, new_h), Image.LANCZOS)

    offset = ((size - new_w) // 2, (size - new_h) // 2)
    canvas.alpha_composite(resized, offset)
    return canvas.convert("RGB")  # aplati opaque — aucun canal alpha résiduel


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"Logo source introuvable : {SOURCE}")
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    logo = load_source()

    for name, size, coverage in TARGETS:
        render_on_square(logo, size, coverage=coverage).save(OUT_DIR / name, "PNG")
        print(f"✅ {name} ({size}x{size}, couverture {int(coverage * 100)}%)")


if __name__ == "__main__":
    main()
