"""Altera una evolución de un PDF de historiasclinicas.net (para pruebas).

Cambia el texto de la evolución N dentro de historia.json y recalcula el
hash de la envoltura, como haría alguien que edita el JSON "con cuidado".
La cadena de huellas de la app debe detectarlo igualmente.

Uso: python3 alterar_pdf.py entrada.pdf salida.pdf [N]
Requiere: pip install pikepdf
"""

import hashlib
import json
import sys

import pikepdf


def canonico(valor):
    # Igual que jsonCanonico() de la app: claves ordenadas, sin espacios,
    # solo ASCII.
    return json.dumps(valor, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def main():
    entrada, salida = sys.argv[1], sys.argv[2]
    n = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    pdf = pikepdf.open(entrada)
    adjunto = pdf.attachments["historia.json"]
    paquete = json.loads(adjunto.get_file().read_bytes())
    evolucion = paquete["datos"]["evoluciones"][n - 1]
    evolucion["texto"] = evolucion["texto"] + " (texto modificado fuera de la app)"
    paquete["sha256"] = hashlib.sha256(canonico(paquete["datos"]).encode("ascii")).hexdigest()
    pdf.attachments["historia.json"] = pikepdf.AttachedFileSpec(
        pdf, canonico(paquete).encode("ascii"), mime_type="application/json"
    )
    pdf.save(salida)
    print(f"evolución {n} alterada → {salida}")


if __name__ == "__main__":
    main()
