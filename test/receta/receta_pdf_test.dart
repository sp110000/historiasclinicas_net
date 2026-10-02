import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/models/medico.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';
import 'package:historiasclinicas_net/core/pdf/receta_pdf.dart';
import 'package:historiasclinicas_net/core/receta/receta.dart';

import '../ejemplos.dart';

/// Medidas de cada página: `[ancho, alto]` en puntos.
List<List<double>> paginas(Uint8List pdf) {
  final texto = latin1.decode(pdf);
  return [
    for (final m in RegExp(
      r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]',
    ).allMatches(texto))
      [double.parse(m.group(1)!), double.parse(m.group(2)!)],
  ];
}

ItemReceta item(int n) => ItemReceta(
  id: 'i$n',
  medicamento: n.isEven ? 'Amoxicilina' : 'Paracetamol',
  concentracion: '500 mg',
  forma: n.isEven ? 'cápsula' : 'tableta',
  dosis: '1 ${n.isEven ? 'cápsula' : 'tableta'}',
  via: 'oral',
  frecuencia: 'cada 8 horas',
  duracion: '7 días',
  cantidad: 21,
  unidad: n.isEven ? 'cápsulas' : 'tabletas',
  nota: n == 1 ? 'Si hay dolor o fiebre; no exceder 4 g al día.' : '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FuentesPdf fuentes;
  setUpAll(() async => fuentes = await FuentesPdf.cargar());

  final copia = instantaneaMedico(medicoEjemplo(), pais: Pais.colombia);
  final medico = Autor.desdeMapa(copia.autor);

  DocumentoReceta documento({
    List<ItemReceta>? items,
    Pais pais = Pais.colombia,
    Autor? conMedico,
    bool sinMedico = false,
  }) => DocumentoReceta(
    receta: Receta(
      id: 'r1',
      historiaId: 'h1',
      fecha: DateTime(2026, 10, 2, 9, 30),
      numero: 'R-000123',
      items: items ?? [item(0), item(1)],
      indicaciones:
          'Líquidos abundantes. Volver si hay dificultad para respirar.',
    ),
    paciente: PacienteReceta.deHistoria(historiaCompleta()),
    pais: pais,
    medico: sinMedico ? null : (conMedico ?? medico),
    recursos: sinMedico ? const {} : copia.recursos,
  );

  Future<Uint8List> pdf(DocumentoReceta d) =>
      generarPdfReceta(d, fuentes: fuentes, generadoEn: DateTime(2026, 10, 2));

  test('una hoja A5 vertical con firma, sello y logo', () async {
    final bytes = await pdf(documento());
    final p = paginas(bytes);
    expect(p, hasLength(1));
    expect(p.single[0], closeTo(PdfMedidas.a5Ancho, 0.5));
    expect(p.single[1], closeTo(PdfMedidas.a5Alto, 0.5));
    // Logo, firma y sello, cada uno con su máscara de transparencia.
    final imagenes = RegExp(
      r'/Subtype\s*/Image',
    ).allMatches(latin1.decode(bytes)).length;
    expect(imagenes, 6);
    _guardarMuestra('receta_a5.pdf', bytes);
  });

  test('sin médico ni imágenes también se genera', () async {
    final bytes = await pdf(documento(sinMedico: true, items: const []));
    expect(paginas(bytes), hasLength(1));
    expect(RegExp(r'/Subtype\s*/Image').hasMatch(latin1.decode(bytes)), false);
  });

  test('muchos medicamentos: continúa en otra hoja A5', () async {
    final bytes = await pdf(
      documento(items: [for (var n = 0; n < 14; n++) item(n)]),
    );
    final p = paginas(bytes);
    expect(p.length, greaterThan(1));
    expect(p.every((x) => (x[1] - PdfMedidas.a5Alto).abs() < 0.5), isTrue);
    _guardarMuestra('receta_varias_hojas.pdf', bytes);
  });

  test('España: se genera con la fecha de nacimiento', () async {
    final bytes = await pdf(documento(pais: Pais.espana));
    expect(paginas(bytes), hasLength(1));
  });
}

abstract final class PdfMedidas {
  static const a5Ancho = 148 / 25.4 * 72;
  static const a5Alto = 210 / 25.4 * 72;
}

/// Con `MUESTRAS_PDF=carpeta` guarda los PDF para revisarlos a ojo.
void _guardarMuestra(String nombre, Uint8List bytes) {
  final carpeta = Platform.environment['MUESTRAS_PDF'];
  if (carpeta == null) return;
  File('$carpeta/$nombre').writeAsBytesSync(bytes);
}
