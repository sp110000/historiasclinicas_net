"""Genera las fotos sintéticas de las pruebas del consultorio (5.2).

No son fotos de personas: son siluetas geométricas. Llevan EXIF con una
cámara y una ubicación GPS inventadas, para comprobar que la app las quita.

    python3 tool/e2e/fixtures/consultorio/generar_fotos.py

Necesita Pillow (solo para regenerarlas; la app no lo usa).
"""

from pathlib import Path

from PIL import Image, ImageDraw

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parents[3]


def exif_ficticio():
    img = Image.new("RGB", (1, 1))
    exif = img.getexif()
    exif[0x010F] = "CamaraDePrueba"  # Make
    exif[0x0110] = "Modelo-Sintetico"  # Model
    gps = {
        1: "N",
        2: (1.0, 2.0, 3.0),  # latitud ficticia
        3: "W",
        4: (4.0, 5.0, 6.0),  # longitud ficticia
    }
    exif[0x8825] = gps  # GPSInfo
    return exif


def silueta(ancho, alto, cintura, fondo, nombre, girada=False):
    img = Image.new("RGB", (ancho, alto), fondo)
    d = ImageDraw.Draw(img)
    cx = ancho // 2
    gris = (70, 80, 90)
    # cabeza, tronco con «cintura» variable, piernas
    d.ellipse([cx - ancho * 0.08, alto * 0.05, cx + ancho * 0.08, alto * 0.17], fill=gris)
    d.polygon(
        [
            (cx - ancho * 0.2, alto * 0.2),
            (cx + ancho * 0.2, alto * 0.2),
            (cx + ancho * cintura, alto * 0.45),
            (cx + ancho * 0.22, alto * 0.58),
            (cx - ancho * 0.22, alto * 0.58),
            (cx - ancho * cintura, alto * 0.45),
        ],
        fill=gris,
    )
    d.rectangle([cx - ancho * 0.18, alto * 0.58, cx - ancho * 0.04, alto * 0.95], fill=gris)
    d.rectangle([cx + ancho * 0.04, alto * 0.58, cx + ancho * 0.18, alto * 0.95], fill=gris)
    d.text((10, 10), nombre, fill=(20, 20, 20))
    if girada:
        # Guardada «acostada», con la orientación en el EXIF (como un celular).
        img = img.rotate(90, expand=True)
    return img


def guardar(img, ruta, orientacion=None):
    exif = exif_ficticio()
    if orientacion:
        exif[0x0112] = orientacion
    img.save(ruta, "JPEG", quality=85, exif=exif)
    print(ruta.relative_to(RAIZ), ruta.stat().st_size, "bytes")


# Prueba unitaria: pequeña, con EXIF y GPS.
guardar(silueta(96, 128, 0.17, (235, 240, 245), "T"), RAIZ / "test/fixtures/foto_con_exif.jpg")

# e2e: frontal antes y después (la segunda, con orientación 6 como un celular).
guardar(
    silueta(1500, 2000, 0.19, (230, 236, 242), "frontal 1"),
    AQUI / "foto_frontal_antes.jpg",
)
guardar(
    silueta(1500, 2000, 0.15, (230, 236, 242), "frontal 2", girada=True),
    AQUI / "foto_frontal_despues.jpg",
    orientacion=6,
)
