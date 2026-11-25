import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/archivos/archivos.dart';
import 'package:historiasclinicas_net/core/consultorio/almacen/almacen.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/documento.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/plantillas.dart';
import 'package:historiasclinicas_net/core/consultorio/fotos/jpeg.dart';
import 'package:historiasclinicas_net/core/consultorio/fotos/procesar_foto.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/foto.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';
import 'package:historiasclinicas_net/core/pdf/historia_pdf.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/consultorio_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/pacientes_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/rutas_consultorio.dart';
import 'package:historiasclinicas_net/features/receta/estado/receta_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';
import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';

final fotoConExif = File('test/fixtures/foto_con_exif.jpg').readAsBytesSync();

/// Contiene la secuencia [aguja] dentro de [pajar].
bool contieneBytes(List<int> pajar, List<int> aguja) {
  outer:
  for (var i = 0; i + aguja.length <= pajar.length; i++) {
    for (var j = 0; j < aguja.length; j++) {
      if (pajar[i + j] != aguja[j]) continue outer;
    }
    return true;
  }
  return false;
}

/// Consultorio abierto con un paciente; con [consentimiento], firmado el
/// de imagen (uso clínico).
Future<(BancoConsultorio, String)> _paciente({
  bool consentimiento = true,
}) async {
  final b = BancoConsultorio();
  await b.servicio.crear(fraseDePrueba);
  final r = await b.servicio.registrarHistoria(
    HistoriaPendiente(
      datos: historiaSintetica(),
      revision: 1,
      origen: OrigenArchivo.importado,
    ),
  );
  if (consentimiento) {
    await b.servicio.documentos.aprobar(TipoPlantilla.consentimientoImagen);
    await b.servicio.documentos.firmarDocumento(
      TipoPlantilla.consentimientoImagen,
      ficha: b.servicio.indice.ficha(r!.pacienteId)!,
      firmaPng: firmaDePrueba,
      medico: medicoCompleto(),
      pais: Pais.colombia,
      permisos: const PermisosImagen(clinico: true),
      fuentes: await FuentesPdf.cargar(),
    );
  }
  return (b, r!.pacienteId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JPEG sin metadatos', () {
    test('se quitan el EXIF y la ubicación GPS; la imagen queda igual', () {
      expect(tieneExif(fotoConExif), isTrue);
      expect(
        contieneBytes(fotoConExif, ascii.encode('CamaraDePrueba')),
        isTrue,
      );
      final limpia = quitarMetadatos(fotoConExif);
      expect(tieneExif(limpia), isFalse);
      expect(contieneBytes(limpia, ascii.encode('CamaraDePrueba')), isFalse);
      expect(contieneBytes(limpia, ascii.encode('Exif')), isFalse);
      expect(dimensionesJpeg(limpia), (ancho: 96, alto: 128));
      expect(limpia.length, lessThan(fotoConExif.length));
      // Lo comprimido (desde SOS) no cambia.
      final sos = [0xFF, 0xDA];
      int desde(Uint8List b) {
        for (var i = 0; i < b.length - 1; i++) {
          if (b[i] == sos[0] && b[i + 1] == sos[1]) return i;
        }
        return -1;
      }

      expect(
        limpia.sublist(desde(limpia)),
        fotoConExif.sublist(desde(fotoConExif)),
      );
    });

    test('lo que no es JPEG se rechaza', () {
      expect(
        () => quitarMetadatos(Uint8List.fromList(utf8.encode('hola'))),
        throwsFormatException,
      );
      expect(dimensionesJpeg(Uint8List.fromList([1, 2, 3])), isNull);
    });

    test('procesar la foto la deja sin metadatos', () async {
      final p = await procesarFoto(fotoConExif);
      expect(tieneExif(p.jpeg), isFalse);
      expect(tieneExif(p.miniatura), isFalse);
      expect((p.ancho, p.alto), (96, 128));
    });
  });

  group('Fotos en el almacén', () {
    test('sin consentimiento de imagen no se guardan', () async {
      final (b, id) = await _paciente(consentimiento: false);
      expect(
        () async => b.servicio.seguimiento.guardarFoto(
          pacienteId: id,
          vista: VistaFoto.frontal,
          procesada: await procesarFoto(fotoConExif),
        ),
        throwsStateError,
      );
    });

    test('cifradas en reposo, ligadas al consentimiento y borrables', () async {
      final (b, id) = await _paciente();
      final s = b.servicio.seguimiento;
      final p = await procesarFoto(fotoConExif);
      final f = await s.guardarFoto(
        pacienteId: id,
        vista: VistaFoto.frontal,
        procesada: p,
        fecha: DateTime(2026, 10, 2, 9),
      );
      final g = await s.guardarFoto(
        pacienteId: id,
        vista: VistaFoto.frontal,
        procesada: p,
      );
      final ficha = b.servicio.indice.ficha(id)!;
      expect(f.consentimientoId, ficha.consentimientoImagenId);
      expect(s.fotosDe(id).map((x) => x.id), [f.id, g.id]);
      expect(s.anterior(id, VistaFoto.frontal, antesDe: g.fecha)!.id, f.id);
      expect(await s.bytesFoto(f.id), p.jpeg);

      await b.servicio.repositorio.esperarEscrituras();
      // Ni los marcadores del JPEG ni el JFIF quedan en claro.
      expect(contieneBytes(b.todosLosBytes, p.jpeg.sublist(0, 64)), isFalse);
      expect(contieneTexto(b.todosLosBytes, 'JFIF'), isFalse);

      await s.borrarFoto(f.id);
      expect(s.foto(f.id), isNull);
      final binarios = b.almacen.datos[Deposito.binarios]!.keys;
      expect(binarios.where((k) => k.contains(f.id)), isEmpty);
      expect(binarios.where((k) => k.contains(g.id)), hasLength(2));
    });

    test('las fotos no entran al PDF de la historia', () async {
      final (b, id) = await _paciente();
      final p = await procesarFoto(fotoConExif);
      await b.servicio.seguimiento.guardarFoto(
        pacienteId: id,
        vista: VistaFoto.frontal,
        procesada: p,
      );
      final h = b.servicio.indice.historiasDe(id).single;
      final datos = await b.servicio.indice.datosDe(h.id);
      final pdf = await generarPdfHistoria(
        datos: datos!,
        revision: 1,
        fuentes: await FuentesPdf.cargar(),
      );
      final medio = p.jpeg.length ~/ 2;
      expect(contieneBytes(pdf, p.jpeg.sublist(medio, medio + 48)), isFalse);
    });
  });

  test(
    'los rótulos de la guía se leen aun sobre una foto blanca (≥ 4,5:1)',
    () {
      // Peor caso: el fondo negro al 55 % del rótulo encima de un blanco.
      final fondo = Color.alphaBlend(
        Colors.black.withValues(alpha: 0.55),
        Colors.white,
      );
      final l1 = Colors.white.computeLuminance();
      final l2 = fondo.computeLuminance();
      expect((l1 + 0.05) / (l2 + 0.05), greaterThanOrEqualTo(4.5));
    },
  );

  group('Pantalla', () {
    Future<void> montar(
      WidgetTester t,
      BancoConsultorio b,
      String id, {
      Size tamano = const Size(1440, 1000),
    }) async {
      t.view
        ..physicalSize = tamano
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          preferenciasProvider.overrideWithValue(prefs),
          rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
          servicioConsultorioProvider.overrideWithValue(b.servicio),
          elegirFotoProvider.overrideWithValue(
            () async => ArchivoAbierto(nombre: 'foto.jpg', bytes: fotoConExif),
          ),
        ],
      );
      addTearDown(c.dispose);
      final router = crearRouterConsultorio(ubicacionInicial: '/pacientes/$id');
      addTearDown(router.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp.router(
            theme: temaClaro(),
            routerConfig: router,
            locale: const Locale('es'),
            supportedLocales: const [Locale('es')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Fotos'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await t.ensureVisible(find.text('Fotos'));
      await t.pumpAndSettle();
      await t.tap(find.text('Fotos'));
      await t.pumpAndSettle();
    }

    Future<void> pulsar(WidgetTester t, Finder f) async {
      await t.ensureVisible(f);
      await t.pumpAndSettle();
      await t.tap(f);
      await t.pumpAndSettle();
    }

    testWidgets('sin consentimiento no aparece «Tomar fotos»', (t) async {
      final (b, id) = await _paciente(consentimiento: false);
      await montar(t, b, id);
      expect(
        find.textContaining('hace falta el consentimiento de uso de imagen'),
        findsOneWidget,
      );
      expect(find.text('Tomar fotos'), findsNothing);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('secuencia, galería, comparación y cortina', (t) async {
      final (b, id) = await _paciente();
      // Una foto frontal de antes, para alinear y comparar.
      await b.servicio.seguimiento.guardarFoto(
        pacienteId: id,
        vista: VistaFoto.frontal,
        procesada: await procesarFoto(fotoConExif),
        fecha: DateTime(2026, 10, 2, 9),
      );
      await montar(t, b, id);

      await pulsar(t, find.text('Tomar fotos'));
      expect(find.text('Frontal (1 de 5)'), findsOneWidget);
      expect(find.text('Ver la anterior en transparencia'), findsOneWidget);
      await pulsar(t, find.text('Tomar o elegir foto'));
      expect(find.text('Repetir'), findsOneWidget);
      await pulsar(t, find.text('Repetir'));
      await pulsar(t, find.text('Tomar o elegir foto'));
      await pulsar(t, find.text('Aceptar'));
      expect(find.text('Lateral derecha (2 de 5)'), findsOneWidget);
      await pulsar(t, find.text('Terminar'));
      expect(find.text('1 foto guardada.'), findsOneWidget);
      expect(b.servicio.seguimiento.fotosDe(id), hasLength(2));

      expect(find.text('COMPARAR'), findsOneWidget);
      expect(find.text('Diferencia: 50 días'), findsOneWidget);
      expect(find.textContaining('Antes · 02/10/2026'), findsOneWidget);
      expect(find.textContaining('Después · 21/11/2026'), findsOneWidget);
      await pulsar(t, find.text('Cortina'));
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('GALERÍA'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('320 px: fotos y secuencia sin desbordes', (t) async {
      final (b, id) = await _paciente();
      await b.servicio.seguimiento.guardarFoto(
        pacienteId: id,
        vista: VistaFoto.frontal,
        procesada: await procesarFoto(fotoConExif),
      );
      await montar(t, b, id, tamano: const Size(320, 640));
      expect(t.takeException(), isNull);
      // Con un solo día de fotos no hay comparación de una foto consigo.
      expect(
        find.textContaining('Para comparar hace falta otra sesión'),
        findsOneWidget,
      );
      expect(find.textContaining('Diferencia:'), findsNothing);
      expect(find.text('Cortina'), findsNothing);
      await t.drag(find.byType(Scrollable).last, const Offset(0, -2000));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      // De vuelta arriba y, desde ahí, hasta «Tomar fotos».
      final lista = find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first;
      await t.drag(lista, const Offset(0, 4000));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Tomar fotos'),
        150,
        scrollable: lista,
      );
      await pulsar(t, find.text('Tomar fotos'));
      expect(t.takeException(), isNull);
      await t.pump(const Duration(seconds: 5));
    });
  });
}
