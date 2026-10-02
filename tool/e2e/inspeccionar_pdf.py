"""Resume lo que guarda un PDF de historiasclinicas.net (para pruebas).

Imprime en JSON: signos vitales, médico de la historia, autores de las
evoluciones, número de imágenes en `recursos` (y si cada una coincide con su
SHA-256), cuántas imágenes dibuja cada página y cuántas hay en total sin
repetir.

Uso: python3 inspeccionar_pdf.py historia.pdf
Requiere: pip install pikepdf
"""

import base64
import hashlib
import json
import sys

import pikepdf


def main():
    pdf = pikepdf.open(sys.argv[1])
    paquete = json.loads(pdf.attachments["historia.json"].get_file().read_bytes())
    datos = paquete["datos"]
    recursos = datos.get("recursos", {})
    imagenes_por_pagina = []
    unicas = set()
    for pagina in pdf.pages:
        xobjetos = pagina.Resources.get("/XObject", {})
        imagenes = [
            xobjetos[k] for k in xobjetos.keys() if xobjetos[k].get("/Subtype") == "/Image"
        ]
        imagenes_por_pagina.append(len(imagenes))
        unicas.update(i.objgen for i in imagenes)
    print(
        json.dumps(
            {
                "revision": paquete["revision"],
                "signos": datos.get("signosVitales"),
                "medico": datos.get("medico"),
                "autores": [e.get("autor") for e in datos.get("evoluciones", [])],
                "recursos": len(recursos),
                "recursosCorrectos": all(
                    hashlib.sha256(base64.b64decode(v)).hexdigest() == k
                    for k, v in recursos.items()
                ),
                "imagenesPorPagina": imagenes_por_pagina,
                "imagenesUnicas": len(unicas),
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
