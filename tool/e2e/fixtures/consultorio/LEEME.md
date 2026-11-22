# PDF sintéticos para la e2e del consultorio

Datos inventados (ningún paciente real). Los genera
`test/tool/fixtures_e2e_test.dart`:

```
GENERAR_FIXTURES_E2E=1 flutter test test/tool/fixtures_e2e_test.dart
```

| Archivo | Qué es |
|---|---|
| `Pena_1032456789_r2.pdf` | Historia íntegra, revisión 2, con una evolución y próximo control vencido |
| `Munoz_52222333_r1.pdf` | Historia íntegra, revisión 1 |
| `Gomez_79333444_r1_alterada.pdf` | Historia alterada después de sellarla (se importa marcada) |
| `factura.pdf` | PDF ajeno (no es de la app) |

Sin la variable, la misma prueba comprueba que estos archivos se siguen
leyendo como se espera.

## Fotos sintéticas (5.2)

Siluetas dibujadas (ninguna persona real), con EXIF y una ubicación GPS
inventados para comprobar que se quitan. Las genera
`generar_fotos.py` (Pillow):

```
python3 tool/e2e/fixtures/consultorio/generar_fotos.py
```

| Archivo | Qué es |
|---|---|
| `foto_frontal_antes.jpg` | Frontal de 1500 × 2000, con EXIF y GPS |
| `foto_frontal_despues.jpg` | Frontal guardada de lado (2000 × 1500) con orientación EXIF 6: el navegador debe dejarla derecha |
| `test/fixtures/foto_con_exif.jpg` | Versión pequeña (96 × 128) para las pruebas unitarias |
