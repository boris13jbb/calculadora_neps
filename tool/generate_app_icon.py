"""Genera los iconos base de la app a partir del arte fuente.

Toma el arte generado (`assets/icon/app_icon_source_raw.png`, horizontal) y produce:

- `assets/icon/app_icon.png`        -> icono cuadrado 1024x1024 (fondo + emblema),
                                       usado como base para iOS/Web/Windows/macOS y
                                       el icono clasico de Android.
- `assets/icon/app_icon_foreground.png` -> capa "foreground" 1024x1024 para el icono
                                       adaptativo de Android (emblema centrado dentro
                                       de la zona segura, sobre fondo azul marino solido
                                       con bordes difuminados para fundirse sin costuras).

El emblema (lupa dorada) se localiza automaticamente detectando los pixeles dorados,
de modo que el recorte quede centrado aunque el arte fuente no lo este.

Uso:
    python tool/generate_app_icon.py
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# Rutas relativas a la raiz del proyecto.
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "icon", "app_icon_source_raw.png")
OUT_ICON = os.path.join(ROOT, "assets", "icon", "app_icon.png")
OUT_FOREGROUND = os.path.join(ROOT, "assets", "icon", "app_icon_foreground.png")

CANVAS = 1024
# Azul marino corporativo mas oscuro (AppColors.sidebar / header).
NAVY = (23, 34, 43)  # #17222B


def find_emblem_bbox(rgb: np.ndarray) -> tuple[int, int, int, int]:
    """Devuelve (left, top, right, bottom) del emblema dorado."""
    r = rgb[:, :, 0].astype(int)
    g = rgb[:, :, 1].astype(int)
    b = rgb[:, :, 2].astype(int)
    # Mascara de tonos dorados/claros (anillo, mango y neps).
    gold = (r > 110) & (g > 80) & (b < 150) & ((r - b) > 30)
    ys, xs = np.where(gold)
    if len(xs) == 0:
        # Sin deteccion: usar el centro de la imagen.
        h, w = rgb.shape[:2]
        return (w // 4, h // 4, 3 * w // 4, 3 * h // 4)
    return (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()))


def square_crop(img: Image.Image, cx: int, cy: int, side: int) -> Image.Image:
    """Recorta un cuadrado de lado `side` centrado en (cx, cy), sin salir de la imagen."""
    w, h = img.size
    side = min(side, w, h)
    left = int(round(cx - side / 2))
    top = int(round(cy - side / 2))
    left = max(0, min(left, w - side))
    top = max(0, min(top, h - side))
    return img.crop((left, top, left + side, top + side))


def build_base_icon(src: Image.Image, bbox: tuple[int, int, int, int]) -> Image.Image:
    """Icono cuadrado conservando el degradado y la textura originales."""
    left, top, right, bottom = bbox
    cx = (left + right) // 2
    cy = (top + bottom) // 2
    # Lado = alto completo de la fuente -> maximo detalle, emblema ~60% del marco.
    side = min(src.size)
    crop = square_crop(src, cx, cy, side)
    return crop.resize((CANVAS, CANVAS), Image.LANCZOS)


def emblem_silhouette(crop_rgb: Image.Image) -> Image.Image:
    """Devuelve una mascara (L) con la silueta solida del emblema (lupa + mango).

    Detecta los tonos dorados del anillo/mango, cierra el anillo con una dilatacion
    y rellena su interior mediante un flood-fill del fondo, de modo que la tela vista
    a traves de la lente queda incluida y todo lo exterior queda fuera.
    """
    arr = np.asarray(crop_rgb).astype(int)
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    gold = (r > 110) & (g > 80) & (b < 150) & ((r - b) > 30)

    w, h = crop_rgb.size
    mask = Image.fromarray((gold * 255).astype(np.uint8), mode="L")
    # Cierra micro-huecos del anillo (por anti-aliasing) para poder rellenar el interior.
    close_k = max(3, (min(w, h) // 90) | 1)  # kernel impar
    mask = mask.filter(ImageFilter.MaxFilter(close_k))

    # Flood-fill del fondo exterior: lo que quede sin marcar es el interior del anillo.
    flood = mask.copy()
    ImageDraw.floodfill(flood, (0, 0), 128, thresh=10)
    flood_arr = np.asarray(flood)
    silhouette = (flood_arr != 128).astype(np.uint8) * 255  # interior + anillo + mango

    sil = Image.fromarray(silhouette, mode="L")
    # Suaviza el borde para un alpha limpio y anti-aliased.
    sil = sil.filter(ImageFilter.GaussianBlur(2))
    return sil


def build_foreground(src: Image.Image, bbox: tuple[int, int, int, int]) -> Image.Image:
    """Foreground adaptativo: emblema aislado y centrado en la zona segura sobre navy."""
    left, top, right, bottom = bbox
    cx = (left + right) // 2
    cy = (top + bottom) // 2
    emblem_side = max(right - left, bottom - top)
    # Margen para incluir el emblema completo (anillo + mango) con holgura.
    crop_side = int(emblem_side * 1.18)
    crop = square_crop(src, cx, cy, crop_side).convert("RGB")

    alpha = emblem_silhouette(crop)

    # Tamano del emblema dentro del lienzo: ~54% (holgado dentro del safe zone 66%).
    target = int(CANVAS * 0.54)
    crop = crop.resize((target, target), Image.LANCZOS)
    alpha = alpha.resize((target, target), Image.LANCZOS)
    crop.putalpha(alpha)

    canvas = Image.new("RGB", (CANVAS, CANVAS), NAVY)
    offset = (CANVAS - target) // 2
    canvas.paste(crop, (offset, offset), crop)
    return canvas


def main() -> None:
    if not os.path.exists(SOURCE):
        raise SystemExit(f"No se encontro el arte fuente: {SOURCE}")

    src = Image.open(SOURCE).convert("RGB")
    bbox = find_emblem_bbox(np.asarray(src))

    build_base_icon(src, bbox).save(OUT_ICON)
    build_foreground(src, bbox).save(OUT_FOREGROUND)

    print("Emblema detectado (l, t, r, b):", bbox)
    print("Generado:", OUT_ICON)
    print("Generado:", OUT_FOREGROUND)


if __name__ == "__main__":
    main()
