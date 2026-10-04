import 'dart:typed_data';

import '../../pdf/historia_pdf.dart';
import '../../models/mapa.dart';

/// Genera el PDF de soporte (`DocumentReferenceEPIRDA`): el resumen
/// clínico de la atención, con capa de texto y sin contraseña. Se genera una
/// vez por versión del documento y queda dentro del Bundle persistido, así
/// que los reintentos envían los mismos bytes.
abstract interface class GeneradorPdfSoporte {
  Future<Uint8List> generar(Map<String, Object?> datos, int revision);
}

/// Reutiliza el generador de PDF de la historia del repositorio
/// (`generarPdfHistoria`, paquete `pdf`): texto real (no imagen) y sin
/// cifrado. La fecha de generación es la del cierre de la atención.
class GeneradorPdfHistoria implements GeneradorPdfSoporte {
  const GeneradorPdfHistoria();

  @override
  Future<Uint8List> generar(Map<String, Object?> datos, int revision) =>
      generarPdfHistoria(
        datos: datos,
        revision: revision,
        generadoEn: datos.fecha('finalizadaEn'),
      );
}
