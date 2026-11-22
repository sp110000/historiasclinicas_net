import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/archivos/archivos.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/documento.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/plantillas.dart';
import 'package:historiasclinicas_net/core/consultorio/fotos/procesar_foto.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/ficha_paciente.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/foto.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/medicion.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/consultorio_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/pacientes_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/rutas_consultorio.dart';
import 'package:historiasclinicas_net/features/receta/estado/receta_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';
import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';

final _foto = File('test/fixtures/foto_con_exif.jpg').readAsBytesSync();

FichaPaciente _borrador(String doc, String nombre) => FichaPaciente(
  id: '',
  clave: '',
  creado: DateTime(2026),
  actualizado: DateTime(2026),
  tipoDocumento: 'CC',
  numeroDocumento: doc,
  nombres: nombre,
  primerApellido: 'Prueba',
);

Medicion _medicion(String pacienteId, double peso, DateTime ahora) => Medicion(
  id: '',
  pacienteId: pacienteId,
  fecha: ahora,
  creado: ahora,
  peso: peso,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FuentesPdf fuentes;
  setUpAll(() async => fuentes = await FuentesPdf.cargar());

  test('el secundario exporta lo suyo y el principal lo combina sin '
      'duplicar', () async {
    // Principal: un paciente y el consentimiento aprobado.
    final a = BancoConsultorio();
    await a.servicio.crear(fraseDePrueba);
    final r = await a.servicio.registrarHistoria(
      HistoriaPendiente(
        datos: historiaSintetica(),
        revision: 1,
        origen: OrigenArchivo.importado,
      ),
    );
    final jose = r!.pacienteId;
    await a.servicio.documentos.aprobar(TipoPlantilla.consentimientoImagen);
    expect(
      a.servicio.exportarPaqueteSecundario,
      throwsStateError,
      reason: 'el principal nunca restauró un respaldo',
    );
    final respaldo = await a.servicio.respaldar();

    // Secundario: restaura el respaldo del principal (comparte la llave).
    final b = BancoConsultorio(ahora: DateTime(2026, 11, 21, 10));
    final v = await b.servicio.verificar(respaldo.bytes, fraseDePrueba);
    await b.servicio.restaurar(v);
    await b.servicio.cambiarEquipoSecundario(true);
    expect(await b.servicio.esEquipoSecundario(), isTrue);
    b.reloj.avanzar(const Duration(minutes: 5));

    // En el secundario: consentimiento, foto, medición y fichas nuevas.
    final cim = await b.servicio.documentos.firmarDocumento(
      TipoPlantilla.consentimientoImagen,
      ficha: b.servicio.indice.ficha(jose)!,
      firmaPng: firmaDePrueba,
      medico: medicoCompleto(),
      pais: Pais.colombia,
      permisos: const PermisosImagen(clinico: true),
      fuentes: fuentes,
    );
    expect(cim.documento.numero, 'CIM-S000001', reason: 'serie propia');
    final foto = await b.servicio.seguimiento.guardarFoto(
      pacienteId: jose,
      vista: VistaFoto.frontal,
      procesada: await procesarFoto(_foto),
    );
    final ahoraB = b.reloj.ahora();
    await b.servicio.seguimiento.guardarMedicion(_medicion(jose, 63.2, ahoraB));
    final maria = await b.servicio.indice.crearFicha(
      _borrador('52222333', 'María'),
    );
    final andresB = await b.servicio.indice.crearFicha(
      _borrador('79333444', 'Andrés'),
    );
    await b.servicio.seguimiento.guardarMedicion(
      _medicion(andresB.id, 70, ahoraB),
    );
    final paquete = await b.servicio.exportarPaqueteSecundario();
    expect(paquete.nombre, 'Paquete_equipo_secundario_2026-11-21.hcpaquete');

    // Mientras tanto, el principal creó la ficha de Andrés por su cuenta.
    final andresA = await a.servicio.indice.crearFicha(
      _borrador('79333444', 'Andrés'),
    );

    final p = await a.servicio.verificarPaqueteSecundario(paquete.bytes);
    expect(p.porColeccion, {
      'pacientes': 2,
      'mediciones': 2,
      'fotos': 1,
      'documentos': 1,
    });
    final res = await a.servicio.combinarPaqueteSecundario(p);
    expect(res.agregados, p.porColeccion);
    expect(res.yaEstaban, 0);
    expect(res.fichasUnidas, 1);

    final ia = a.servicio.indice;
    expect(ia.ficha(maria.id)!.activa, isTrue);
    expect(ia.ficha(andresB.id)!.unidaEn, andresA.id);
    expect(
      a.servicio.seguimiento.medicionesDe(andresA.id).single.peso,
      70,
      reason: 'lo de la ficha del secundario aparece en la del principal',
    );
    final fichaJose = ia.ficha(jose)!;
    expect(fichaJose.consentimientoImagenId, cim.documento.id);
    expect(
      a.servicio.documentos.consentimientoImagenVigente(fichaJose)!.numero,
      'CIM-S000001',
    );
    expect(a.servicio.seguimiento.fotosDe(jose).single.id, foto.id);
    expect(
      await a.servicio.seguimiento.bytesFoto(foto.id),
      await b.servicio.seguimiento.bytesFoto(foto.id),
    );

    // Otra vez el mismo paquete: nada nuevo.
    final otra = await a.servicio.combinarPaqueteSecundario(
      await a.servicio.verificarPaqueteSecundario(paquete.bytes),
    );
    expect(otra.totalAgregados, 0);
    expect(otra.yaEstaban, 6);
    expect(ia.fichasActivas, hasLength(3));
  });

  test('un paquete de otro consultorio o alterado se rechaza', () async {
    final a = BancoConsultorio();
    await a.servicio.crear(fraseDePrueba);
    final r = await a.servicio.registrarHistoria(
      HistoriaPendiente(
        datos: historiaSintetica(),
        revision: 1,
        origen: OrigenArchivo.importado,
      ),
    );
    final respaldo = await a.servicio.respaldar();
    final b = BancoConsultorio(ahora: DateTime(2026, 11, 21, 10));
    await b.servicio.restaurar(
      await b.servicio.verificar(respaldo.bytes, fraseDePrueba),
    );
    b.reloj.avanzar(const Duration(minutes: 1));
    await b.servicio.seguimiento.guardarMedicion(
      _medicion(r!.pacienteId, 64, b.reloj.ahora()),
    );
    final paquete = await b.servicio.exportarPaqueteSecundario();

    // Otro consultorio, con otra llave.
    final c = BancoConsultorio();
    await c.servicio.crear(fraseDePrueba);
    expect(
      () => c.servicio.verificarPaqueteSecundario(paquete.bytes),
      throwsFormatException,
    );

    // Un byte cambiado dentro del paquete.
    final alterado = Uint8List.fromList(paquete.bytes);
    alterado[alterado.length ~/ 2] ^= 0x5a;
    expect(
      () => a.servicio.verificarPaqueteSecundario(alterado),
      throwsFormatException,
    );
    expect(
      () => a.servicio.verificarPaqueteSecundario(Uint8List.fromList([1, 2])),
      throwsFormatException,
    );
  });

  testWidgets('Ajustes: exportar en el secundario y combinar en el principal', (
    t,
  ) async {
    final a = BancoConsultorio();
    await a.servicio.crear(fraseDePrueba);
    final r = await a.servicio.registrarHistoria(
      HistoriaPendiente(
        datos: historiaSintetica(),
        revision: 1,
        origen: OrigenArchivo.importado,
      ),
    );
    final respaldo = await a.servicio.respaldar();
    final b = BancoConsultorio(ahora: DateTime(2026, 11, 21, 10));
    await b.servicio.restaurar(
      await b.servicio.verificar(respaldo.bytes, fraseDePrueba),
    );
    b.reloj.avanzar(const Duration(minutes: 1));
    await b.servicio.seguimiento.guardarMedicion(
      _medicion(r!.pacienteId, 64, b.reloj.ahora()),
    );

    final descargas = <(Uint8List, String)>[];
    Future<void> montar(BancoConsultorio banco, Uint8List? paquete) async {
      t.view
        ..physicalSize = const Size(1440, 1400)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          preferenciasProvider.overrideWithValue(prefs),
          rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
          servicioConsultorioProvider.overrideWithValue(banco.servicio),
          descargarArchivoProvider.overrideWithValue(
            (bytes, nombre) => descargas.add((bytes, nombre)),
          ),
          elegirPaqueteProvider.overrideWithValue(
            () async => paquete == null
                ? null
                : ArchivoAbierto(nombre: 'p.hcpaquete', bytes: paquete),
          ),
        ],
      );
      addTearDown(c.dispose);
      final router = crearRouterConsultorio(ubicacionInicial: '/ajustes');
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
    }

    Future<void> pulsar(Finder f) async {
      await t.ensureVisible(f);
      await t.pumpAndSettle();
      await t.tap(f);
      await t.pumpAndSettle();
    }

    // Secundario: marcarlo y exportar.
    await montar(b, null);
    expect(find.text('Equipo secundario'), findsOneWidget);
    expect(find.textContaining('restaurado el 21/11/2026'), findsOneWidget);
    await pulsar(find.text('Este equipo es el secundario'));
    await pulsar(find.text('Exportar paquete de este equipo'));
    expect(
      descargas.single.$2,
      'Paquete_equipo_secundario_2026-11-21.hcpaquete',
    );

    // Principal: combinar.
    await montar(a, descargas.single.$1);
    await pulsar(find.text('Combinar un paquete'));
    expect(find.text('¿Combinar el paquete?'), findsOneWidget);
    expect(find.textContaining('1 medición'), findsOneWidget);
    await pulsar(find.widgetWithText(FilledButton, 'Combinar'));
    expect(find.text('Paquete combinado: 1 medición.'), findsOneWidget);
    expect(a.servicio.seguimiento.medicionesDe(r.pacienteId).last.peso, 64);
    await t.pump(const Duration(seconds: 5));
  });
}
