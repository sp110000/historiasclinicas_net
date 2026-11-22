import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/documento.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/ficha_paciente.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/medicion.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/certificacion.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/plan_tratamiento.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/plantilla_procedimiento.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/procedimientos.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/sesion.dart';
import 'package:historiasclinicas_net/core/consultorio/procedimientos/valoracion.dart';
import 'package:historiasclinicas_net/core/consultorio/repositorio/bitacora.dart';
import 'package:historiasclinicas_net/core/consultorio/reglas/sesion.dart';
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
import 'ayudas_procedimientos.dart';
import 'documentos_test.dart' show textoPdf;

final _hoy = DateTime(2026, 11, 21, 9, 30);

FichaPaciente _ficha({DateTime? nacimiento}) => FichaPaciente(
  id: 'p',
  clave: '',
  creado: DateTime(2026),
  actualizado: DateTime(2026),
  tipoDocumento: 'CC',
  numeroDocumento: '1',
  nombres: 'Ana',
  primerApellido: 'Prueba',
  fechaNacimiento: nacimiento ?? DateTime(1990, 3, 15),
);

PlantillaProcedimiento _plantilla({bool aprobada = true}) {
  final d = protocoloDePrueba(hidrolipoclasiaBase.ultima.definicion);
  return PlantillaProcedimiento(
    id: 'hidrolipoclasia',
    versiones: [
      VersionProcedimiento(
        version: 1,
        definicion: d,
        aprobadaEn: aprobada ? DateTime(2026, 11, 1) : null,
      ),
    ],
  );
}

Valoracion _valoracion({
  ResultadoValoracion resultado = ResultadoValoracion.apto,
  DateTime? hasta,
}) => Valoracion(
  id: 'v',
  pacienteId: 'p',
  plantillaId: 'hidrolipoclasia',
  version: 1,
  fecha: DateTime(2026, 11, 1),
  creado: DateTime(2026, 11, 1),
  resultado: resultado,
  vigenteHasta: resultado == ResultadoValoracion.apto
      ? (hasta ?? DateTime(2027, 1, 30))
      : null,
  huellaEvolucion: 'h',
);

DocumentoConsultorio _consentimiento({
  EstadoDocumento estado = EstadoDocumento.vigente,
  List<String> zonas = const ['Abdomen inferior', 'Flancos'],
  int sesiones = 4,
}) => DocumentoConsultorio(
  id: 'ci',
  creado: DateTime(2026, 11, 2),
  estado: estado,
  cambioEstado: estado == EstadoDocumento.vigente
      ? null
      : DateTime(2026, 11, 10),
  datos: {
    'tipo': 'consentimientoInformado',
    'numero': 'CI-000001',
    'fechaHora': '2026-11-02T10:00',
    'plan': PlanTratamiento(
      plantillaId: 'hidrolipoclasia',
      version: 1,
      procedimiento: 'Hidrolipoclasia',
      zonas: zonas,
      sesiones: sesiones,
      producto: 'Componente A de prueba',
    ).aMapa(),
  },
);

const _lote = LoteSesion(lote: 'L1', vence: null);

/// Una sesión que cumple todo (con el protocolo de prueba: máximo 7 mg/kg a
/// 20 mg/mL; 10 mL en 69 kg son 2,9 mg/kg).
Sesion _sesion() {
  final d = _plantilla().vigente!.definicion;
  final vence = DateTime(2027, 3, 31);
  return Sesion(
    id: '',
    pacienteId: 'p',
    plantillaId: 'hidrolipoclasia',
    version: 1,
    fecha: _hoy,
    numero: 1,
    sesionesPlan: 4,
    consentimientoId: 'ci',
    consentimientoNumero: 'CI-000001',
    verificacion: {for (final i in d.listaVerificacion) i: true},
    zonas: const [ZonaSesion(zona: 'Abdomen inferior', volumenMl: 300)],
    componentes: [
      for (final c in d.componentes)
        ComponenteSesion(
          nombre: c,
          lote: LoteSesion(lote: 'C-1', vence: vence),
        ),
    ],
    anestesico: AnestesicoSesion(
      nombre: 'Anestésico de prueba',
      concentracionMgMl: 20,
      maximoMgKg: 7,
      volumenMl: 10,
      lote: LoteSesion(lote: 'L2345', vence: vence),
    ),
    pesoKg: 69,
    fechaPeso: DateTime(2026, 11, 12),
    duracionMin: 45,
  );
}

EvaluacionSesion _evaluar({
  Sesion? s,
  FichaPaciente? ficha,
  PlantillaProcedimiento? plantilla,
  Valoracion? valoracion,
  bool sinValoracion = false,
  List<DocumentoConsultorio>? consentimientos,
  Sesion? anterior,
  bool certificada = true,
}) => evaluarSesion(
  s: s ?? _sesion(),
  ficha: ficha ?? _ficha(),
  plantilla: plantilla ?? _plantilla(),
  valoracion: sinValoracion ? null : (valoracion ?? _valoracion()),
  consentimientos: consentimientos ?? [_consentimiento()],
  anterior: anterior,
  certificada: certificada,
  ahora: _hoy,
);

Future<(BancoConsultorio, String)> _listo() async {
  final b = BancoConsultorio();
  await b.servicio.crear(fraseDePrueba);
  final r = await b.servicio.registrarHistoria(
    HistoriaPendiente(
      datos: historiaSintetica(),
      revision: 1,
      origen: OrigenArchivo.importado,
    ),
  );
  final id = r!.pacienteId;
  // Peso reciente (el de la historia es del 02/10/2026, de hace más de 30
  // días).
  await b.servicio.seguimiento.guardarMedicion(
    Medicion(
      id: '',
      pacienteId: id,
      fecha: DateTime(2026, 11, 20, 9),
      creado: DateTime(2026, 11, 20, 9),
      peso: 64,
    ),
  );
  await aprobarHidrolipoclasia(b);
  await valorarAptoDePrueba(b, id);
  await consentimientoDePrueba(b, id);
  return (b, id);
}

/// Llena el borrador para que cumpla todo.
Sesion _completar(Sesion s) {
  final vence = DateTime(2027, 3, 31);
  return s.copyWith(
    verificacion: {for (final k in s.verificacion.keys) k: true},
    zonas: const [ZonaSesion(zona: 'Abdomen inferior', volumenMl: 300)],
    componentes: [
      for (final c in s.componentes)
        ComponenteSesion(
          nombre: c.nombre,
          lote: LoteSesion(lote: 'C-1', vence: vence),
        ),
    ],
    anestesico: s.anestesico!.copyWith(
      volumenMl: 10.0,
      lote: LoteSesion(lote: 'L2345', vence: vence),
    ),
    duracionMin: 45,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FuentesPdf fuentes;
  setUpAll(() async => fuentes = await FuentesPdf.cargar());

  group('Reglas de la sesión (por tabla)', () {
    test('todo en orden: se puede sellar, sin avisos', () {
      final e = _evaluar();
      expect(e.bloqueos, isEmpty);
      expect(e.avisos, isEmpty);
    });

    final casos = <(String, EvaluacionSesion Function(), String)>[
      (
        'menor de 18 años',
        () => _evaluar(ficha: _ficha(nacimiento: DateTime(2010, 1, 1))),
        'menor de 18 años',
      ),
      (
        'valoración «no apto»',
        () => _evaluar(
          valoracion: _valoracion(resultado: ResultadoValoracion.noApto),
        ),
        'La valoración fue «no apto»',
      ),
      (
        'valoración «diferir»',
        () => _evaluar(
          valoracion: _valoracion(resultado: ResultadoValoracion.diferir),
        ),
        'La valoración fue «diferir»',
      ),
      (
        'valoración vencida',
        () => _evaluar(valoracion: _valoracion(hasta: DateTime(2026, 11, 20))),
        'La valoración venció el 20/11/2026',
      ),
      (
        'sin valoración',
        () => _evaluar(sinValoracion: true),
        'Falta la valoración del procedimiento.',
      ),
      (
        'consentimiento faltante',
        () => _evaluar(consentimientos: const []),
        'Falta el consentimiento firmado.',
      ),
      (
        'consentimiento revocado',
        () => _evaluar(
          consentimientos: [_consentimiento(estado: EstadoDocumento.revocado)],
        ),
        'El consentimiento CI-000001 fue revocado el 10/11/2026',
      ),
      (
        'zona fuera del consentimiento',
        () => _evaluar(
          consentimientos: [
            _consentimiento(zonas: ['Flancos']),
          ],
        ),
        'La zona «Abdomen inferior» no está en el consentimiento CI-000001',
      ),
      (
        'más sesiones que el plan',
        () => _evaluar(consentimientos: [_consentimiento(sesiones: 0)]),
        'El consentimiento CI-000001 cubre 0 sesiones',
      ),
      (
        'plantilla sin aprobar',
        () => _evaluar(plantilla: _plantilla(aprobada: false)),
        'no está aprobada',
      ),
      (
        'dosis por encima del máximo',
        () => _evaluar(
          s: _sesion().copyWith(
            anestesico: _sesion().anestesico!.copyWith(volumenMl: 30.0),
          ),
        ),
        'Dosis por encima del máximo del protocolo: 8,7 mg/kg',
      ),
      (
        'lote vencido',
        () => _evaluar(
          s: _sesion().copyWith(
            anestesico: _sesion().anestesico!.copyWith(
              lote: LoteSesion(lote: 'L2345', vence: DateTime(2026, 11, 1)),
            ),
          ),
        ),
        'El lote L2345 de «Anestésico de prueba» venció el 01/11/2026.',
      ),
      (
        'lote sin escribir',
        () => _evaluar(
          s: _sesion().copyWith(
            anestesico: _sesion().anestesico!.copyWith(lote: _lote),
          ),
        ),
        'Escribe el lote y el vencimiento de «Anestésico de prueba».',
      ),
      (
        'peso de hace más de 30 días',
        () => _evaluar(s: _sesion().copyWith(fechaPeso: DateTime(2026, 10, 1))),
        'Pesa al paciente: la última medición es del 01/10/2026',
      ),
      (
        'lista de verificación incompleta',
        () => _evaluar(
          s: _sesion().copyWith(
            verificacion: {
              ..._sesion().verificacion,
              'Embarazo descartado': false,
            },
          ),
        ),
        'Falta marcar en la lista de verificación: «Embarazo descartado».',
      ),
      (
        'volumen por zona sobre el máximo',
        () => _evaluar(
          s: _sesion().copyWith(
            zonas: const [ZonaSesion(zona: 'Flancos', volumenMl: 600)],
          ),
        ),
        '«Flancos» supera el volumen máximo por zona del protocolo (500 mL).',
      ),
    ];
    for (final (caso, evaluar, bloqueo) in casos) {
      test('bloquea: $caso', () {
        final e = evaluar();
        expect(e.permiteSellar, isFalse);
        expect(
          e.bloqueos.any((b) => b.contains(bloqueo)),
          isTrue,
          reason: 'bloqueos: ${e.bloqueos}',
        );
      });
    }

    test('avisa sin bloquear: dosis al 80 % o más', () {
      final e = _evaluar(
        s: _sesion().copyWith(
          anestesico: _sesion().anestesico!.copyWith(volumenMl: 20.0),
        ),
      );
      expect(e.permiteSellar, isTrue);
      expect(e.avisos.single, startsWith('Dosis al 83 % del máximo'));
    });

    test('avisa sin bloquear: técnica sin certificación', () {
      final e = _evaluar(certificada: false);
      expect(e.permiteSellar, isTrue);
      expect(
        e.avisos.single,
        'Sin certificación vigente para «Lipólisis por infiltración».',
      );
    });

    test('avisa sin bloquear: menos días que el intervalo', () {
      final e = _evaluar(
        anterior: _sesion().copyWith(fecha: DateTime(2026, 11, 18)),
      );
      expect(e.permiteSellar, isTrue);
      expect(
        e.avisos.single,
        'Han pasado 3 días desde la sesión anterior; el protocolo pide 7.',
      );
    });

    test('dosis: mg y mg/kg', () {
      final a = _sesion().anestesico!;
      expect(a.mg, 200);
      expect(textoDosis(a, 69), '200 mg · 2,9 mg/kg');
      expect(a.fraccion(69), closeTo(0.414, 0.001));
    });
  });

  group('Sesión en el consultorio', () {
    test('se sella en la historia y queda numerada; sin certificación, el '
        'aviso queda registrado', () async {
      final (b, id) = await _listo();
      final p = b.servicio.procedimientos;
      final ficha = b.servicio.indice.ficha(id)!;
      final borrador = p.nuevaSesion(ficha, 'hidrolipoclasia');
      expect(borrador.numero, 1);
      expect(borrador.sesionesPlan, 4);
      expect(borrador.consentimientoNumero, 'CI-000001');
      expect(borrador.zonas.map((z) => z.zona), [
        'Abdomen inferior',
        'Flancos',
      ]);
      expect(borrador.pesoKg, 64, reason: 'la última medición');
      expect(borrador.control, DateTime(2026, 11, 28));
      expect(p.evaluar(borrador, ficha).permiteSellar, isFalse);

      final lista = _completar(borrador);
      final e = p.evaluar(lista, ficha);
      expect(e.bloqueos, isEmpty);
      expect(e.avisos.single, startsWith('Sin certificación vigente'));
      final (s1, sellada) = await p.sellarSesion(
        lista,
        ficha,
        medico: medicoCompleto(),
        pais: Pais.colombia,
        fuentes: fuentes,
      );
      // v2: la valoración; v3: la sesión.
      expect(sellada.revision, 3);
      expect(sellada.nombreArchivo, 'Historia_PENA_1032456789_v3.pdf');
      expect(s1.avisos.single, startsWith('Sin certificación vigente'));
      final texto = textoSesion(
        s1,
        p.vigente('hidrolipoclasia').definicion,
        version: 1,
      );
      expect(
        texto,
        startsWith(
          'Sesión 1 de 4 de Hidrolipoclasia (plantilla v1). Consentimiento '
          'CI-000001. Lista de verificación previa completa (11/11). Zonas: '
          'Abdomen inferior 300 mL (total 300 mL).',
        ),
      );
      expect(
        texto,
        contains(
          'Anestésico: Anestésico de prueba 20 mg/mL, 10 mL (lote L2345, vence '
          '31/03/2027): 200 mg · 3,1 mg/kg con peso de 64 kg del 20/11/2026; '
          'máximo del protocolo 7 mg/kg.',
        ),
      );
      expect(texto, contains('Eventos adversos: Ninguno.'));
      // Lo que el médico escribe con punto final no queda con «..».
      expect(texto, contains('Indicaciones: Indicaciones de prueba. '));
      expect(texto, isNot(contains('..')));
      expect(
        texto,
        contains(
          'Aviso: Sin certificación vigente para «Lipólisis por infiltración».',
        ),
      );
      expect(texto, contains('Control: 28/11/2026.'));
      // La evolución lleva el próximo control.
      expect(
        b.servicio.indice.ultimaHistoria(id)!.proximoControl,
        DateTime(2026, 11, 28),
      );
      final pdf = textoPdf(sellada.pdf);
      if (pdf != null) {
        expect(
          pdf.replaceAll(RegExp(r'\s+'), ' '),
          contains('Sesión 1 de 4 de Hidrolipoclasia'),
        );
      }
      final bitacora = await b.servicio.bitacora();
      expect(
        bitacora.map((e) => e.accion),
        contains(AccionBitacora.sesionSinCertificacion),
      );

      // Con certificación vigente: la segunda, sin aviso.
      await p.guardarCertificacion(
        Certificacion(
          id: '',
          familia: 'Lipólisis por infiltración',
          entidad: 'Entidad de prueba',
          fecha: DateTime(2026, 1, 10),
          creado: DateTime(2026, 1, 10),
        ),
        soporte: Uint8List.fromList([1, 2, 3]),
        tipoSoporte: 'pdf',
      );
      final segunda = p.nuevaSesion(ficha, 'hidrolipoclasia');
      expect(segunda.numero, 2);
      final e2 = p.evaluar(_completar(segunda), ficha);
      expect(e2.avisos.single, startsWith('Han pasado 0 días'));
      expect(
        p.certificacionPara('Lipólisis por infiltración (VERIFICAR)'),
        'Lipólisis por infiltración, Entidad de prueba, desde el 10/01/2026',
      );
      expect(contieneTexto(b.todosLosBytes, 'L2345'), isFalse);
      await b.servicio.bloquear();
      await b.servicio.desbloquear(fraseDePrueba);
      expect(b.servicio.procedimientos.sesionesDe(id).single.numero, 1);
      expect(
        await b.servicio.procedimientos.soporteCertificacion(
          b.servicio.procedimientos.certificaciones.single.id,
        ),
        [1, 2, 3],
      );
    });

    test('el peso de hoy queda como medición', () async {
      final (b, id) = await _listo();
      final p = b.servicio.procedimientos;
      final ficha = b.servicio.indice.ficha(id)!;
      final s = _completar(
        p.nuevaSesion(ficha, 'hidrolipoclasia'),
      ).copyWith(pesoKg: 66.0, fechaPeso: DateTime(2026, 11, 21));
      await p.sellarSesion(
        s,
        ficha,
        medico: medicoCompleto(),
        pais: Pais.colombia,
        registrarPeso: true,
        fuentes: fuentes,
      );
      expect(b.servicio.seguimiento.medicionesDe(id).last.peso, 66);
    });

    test('un bloqueo impide sellar', () async {
      final (b, id) = await _listo();
      final p = b.servicio.procedimientos;
      final ficha = b.servicio.indice.ficha(id)!;
      final s = _completar(p.nuevaSesion(ficha, 'hidrolipoclasia'));
      final vencido = s.copyWith(
        anestesico: s.anestesico!.copyWith(
          lote: LoteSesion(lote: 'L0001', vence: DateTime(2026, 11, 1)),
        ),
      );
      expect(
        () => p.sellarSesion(
          vencido,
          ficha,
          medico: medicoCompleto(),
          pais: Pais.colombia,
          fuentes: fuentes,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'mensaje',
            'El lote L0001 de «Anestésico de prueba» venció el 01/11/2026.',
          ),
        ),
      );
      expect(p.sesionesDe(id), isEmpty);
    });
  });

  group('Pantalla', () {
    Future<List<String>> montar(
      WidgetTester t,
      BancoConsultorio b,
      String ruta, {
      Size tamano = const Size(1440, 1200),
    }) async {
      t.view
        ..physicalSize = tamano
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({Claves.pais: 'CO'});
      final prefs = await SharedPreferences.getInstance();
      final descargas = <String>[];
      final c = ProviderContainer(
        overrides: [
          preferenciasProvider.overrideWithValue(prefs),
          rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
          servicioConsultorioProvider.overrideWithValue(b.servicio),
          descargarPdfProvider.overrideWithValue(
            (bytes, nombre) => descargas.add(nombre),
          ),
        ],
      );
      addTearDown(c.dispose);
      final router = crearRouterConsultorio(ubicacionInicial: ruta);
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
      return descargas;
    }

    Future<void> pulsar(WidgetTester t, Finder f) async {
      await t.ensureVisible(f);
      await t.pumpAndSettle();
      await t.tap(f);
      await t.pumpAndSettle();
    }

    Future<void> escribir(WidgetTester t, String etiqueta, String v) async {
      final f = find.ancestor(
        of: find.text(etiqueta),
        matching: find.byType(TextField),
      );
      await t.ensureVisible(f.first);
      await t.enterText(f.first, v);
      await t.pump();
    }

    ButtonStyleButton sellar(WidgetTester t) => t.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Sellar sesión'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );

    testWidgets('sin consentimiento, el botón dice por qué', (t) async {
      final b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      final r = await b.servicio.registrarHistoria(
        HistoriaPendiente(
          datos: historiaSintetica(),
          revision: 1,
          origen: OrigenArchivo.importado,
        ),
      );
      await aprobarHidrolipoclasia(b);
      await valorarAptoDePrueba(b, r!.pacienteId);
      await montar(t, b, '/pacientes/${r.pacienteId}/sesion/hidrolipoclasia');
      expect(find.text('Sin consentimiento'), findsOneWidget);
      expect(find.text('Falta el consentimiento firmado.'), findsOneWidget);
      expect(sellar(t).onPressed, isNull);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('«Peso de hoy» sigue a la vista mientras se escribe', (
      t,
    ) async {
      final b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      final r = await b.servicio.registrarHistoria(
        HistoriaPendiente(
          datos: historiaSintetica(),
          revision: 1,
          origen: OrigenArchivo.importado,
        ),
      );
      final id = r!.pacienteId;
      // Sin medición reciente: el peso de la historia es del 02/10/2026.
      await aprobarHidrolipoclasia(b);
      await valorarAptoDePrueba(b, id);
      await consentimientoDePrueba(b, id);
      await montar(t, b, '/pacientes/$id/sesion/hidrolipoclasia');
      expect(find.text('Peso 64,5 kg del 02/10/2026.'), findsOneWidget);
      await escribir(t, 'Peso de hoy', '6');
      expect(find.text('Peso de hoy'), findsOneWidget);
      await escribir(t, 'Peso de hoy', '64');
      expect(find.text('Peso de hoy'), findsOneWidget);
      expect(find.text('Peso 64 kg del 21/11/2026.'), findsOneWidget);
      // Borrarlo devuelve el peso anterior.
      await escribir(t, 'Peso de hoy', '');
      expect(find.text('Peso 64,5 kg del 02/10/2026.'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('registrar y sellar desde la ficha', (t) async {
      final (b, id) = await _listo();
      final descargas = await montar(t, b, '/pacientes/$id');
      await pulsar(t, find.text('Estética'));
      expect(find.text('Sin sesiones todavía.'), findsOneWidget);
      await pulsar(t, find.text('Registrar sesión'));
      expect(find.text('Sesión 1 de 4 · Hidrolipoclasia'), findsOneWidget);
      expect(find.text('Consentimiento CI-000001'), findsOneWidget);
      expect(find.text('Sin certificación registrada'), findsOneWidget);
      expect(sellar(t).onPressed, isNull);

      for (final c in find.byType(CheckboxListTile).evaluate().toList()) {
        await pulsar(t, find.byWidget(c.widget));
      }
      // Solo una zona: se quita «Flancos».
      await pulsar(t, find.text('Flancos'));
      await escribir(t, 'Volumen (Abdomen inferior)', '300');
      for (final n in ['Componente A de prueba', 'Componente B de prueba']) {
        await escribir(t, 'Lote ($n)', 'C-1');
        await escribir(t, 'Vence ($n)', '31/03/2027');
      }
      await escribir(t, 'Volumen del anestésico', '10');
      await escribir(t, 'Lote (Anestésico de prueba)', 'L2345');
      await escribir(t, 'Vence (Anestésico de prueba)', '01/11/2026');
      expect(
        find.text(
          'El lote L2345 de «Anestésico de prueba» venció el 01/11/2026.',
        ),
        findsOneWidget,
      );
      await escribir(t, 'Vence (Anestésico de prueba)', '31/03/2027');
      expect(find.textContaining('200 mg · 3,1 mg/kg'), findsOneWidget);
      await escribir(t, 'Duración', '45');
      expect(
        find.textContaining('Lista para sellar, con 1 aviso'),
        findsOneWidget,
      );
      await pulsar(t, find.text('Sellar sesión'));

      expect(descargas.single, 'Historia_PENA_1032456789_v3.pdf');
      expect(find.text('Ficha del paciente'), findsOneWidget);
      final s = b.servicio.procedimientos.sesionesDe(id).single;
      expect(s.zonas.single.volumenMl, 300);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('Ajustes: agregar y retirar una certificación', (t) async {
      final b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      await montar(t, b, '/ajustes');
      await t.scrollUntilVisible(
        find.text('Agregar certificación'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await pulsar(t, find.text('Agregar certificación'));
      expect(
        find.widgetWithText(TextField, 'Lipólisis por infiltración'),
        findsOneWidget,
      );
      await escribir(t, 'Entidad que certifica', 'Entidad de prueba');
      await escribir(t, 'Fecha de la certificación', '10/01/2026');
      await pulsar(t, find.widgetWithText(FilledButton, 'Guardar'));
      final c = b.servicio.procedimientos.certificaciones.single;
      expect(c.entidad, 'Entidad de prueba');
      expect(find.text('Vigente desde el 10/01/2026'), findsOneWidget);
      await pulsar(t, find.text('Retirar'));
      await pulsar(t, find.widgetWithText(FilledButton, 'Retirar'));
      expect(find.text('Retirada el 21/11/2026'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('320 px: la sesión plegable sin desbordes', (t) async {
      final (b, id) = await _listo();
      await montar(
        t,
        b,
        '/pacientes/$id/sesion/hidrolipoclasia',
        tamano: const Size(320, 640),
      );
      expect(find.text('Sellar sesión'), findsOneWidget);
      expect(t.takeException(), isNull);
      await pulsar(t, find.textContaining('ANESTÉSICO'));
      expect(t.takeException(), isNull);
      await t.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.pump(const Duration(seconds: 5));
    });
  });
}
