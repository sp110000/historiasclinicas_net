import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/medicion.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/peso/catalogo_glp1.dart';
import 'package:historiasclinicas_net/core/consultorio/peso/programa_peso.dart';
import 'package:historiasclinicas_net/core/consultorio/peso/programas.dart';
import 'package:historiasclinicas_net/core/consultorio/reglas/glp1.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/consultorio_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/rutas_consultorio.dart';
import 'package:historiasclinicas_net/features/historia/estado/historia_controller.dart';
import 'package:historiasclinicas_net/features/receta/estado/receta_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';
import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';
import 'documentos_test.dart' show textoPdf;

/// Todas en «no» (para la ficha de [sexo]).
Map<String, RespuestaItem> _todasNo({String? sexo = 'F'}) => {
  for (final i in contraindicacionesAplicables(sexo))
    i.id: const RespuestaItem(RespuestaContra.no),
};

RevisionContraindicaciones _revision(Map<String, RespuestaItem> r) =>
    RevisionContraindicaciones(fecha: DateTime(2026, 11, 21), respuestas: r);

Future<(BancoConsultorio, String)> _paciente() async {
  final b = BancoConsultorio();
  await b.servicio.crear(fraseDePrueba);
  final r = await b.servicio.registrarHistoria(
    HistoriaPendiente(
      datos: historiaSintetica(),
      revision: 1,
      origen: OrigenArchivo.importado,
    ),
  );
  return (b, r!.pacienteId);
}

Future<ProgramaPeso> _programa(BancoConsultorio b, String id) =>
    b.servicio.peso.guardar(
      ProgramaPeso(
        id: '',
        pacienteId: id,
        inicio: DateTime(2026, 10, 2),
        creado: DateTime(2026, 10, 2),
        actualizado: DateTime(2026, 10, 2),
        metaPeso: 58,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Contraindicaciones del GLP-1 (por tabla)', () {
    final casos =
        <
          ({
            String caso,
            Map<String, RespuestaItem>? respuestas,
            String? sexo,
            bool permite,
            String? motivo,
          })
        >[
          (
            caso: 'sin revisar',
            respuestas: null,
            sexo: 'F',
            permite: false,
            motivo: 'Falta revisar la lista de contraindicaciones.',
          ),
          (
            caso: 'todas en no',
            respuestas: _todasNo(),
            sexo: 'F',
            permite: true,
            motivo: null,
          ),
          (
            caso: 'absoluta en sí (pancreatitis)',
            respuestas: {
              ..._todasNo(),
              'pancreatitis': const RespuestaItem(RespuestaContra.si),
            },
            sexo: 'F',
            permite: false,
            motivo: 'Contraindicación absoluta: Antecedente de pancreatitis.',
          ),
          (
            caso: 'absoluta sin aclarar (embarazo «no sabe»)',
            respuestas: {
              ..._todasNo(),
              'embarazo': const RespuestaItem(RespuestaContra.desconoce),
            },
            sexo: 'F',
            permite: false,
            motivo: 'Aclara «Embarazo» antes de iniciar.',
          ),
          (
            caso: 'precaución en sí sin nota',
            respuestas: {
              ..._todasNo(),
              'biliar': const RespuestaItem(RespuestaContra.si),
            },
            sexo: 'F',
            permite: false,
            motivo: 'Escribe una nota para «Enfermedad biliar».',
          ),
          (
            caso: 'precaución en sí con nota',
            respuestas: {
              ..._todasNo(),
              'biliar': const RespuestaItem(
                RespuestaContra.si,
                'Colelitiasis asintomática',
              ),
            },
            sexo: 'F',
            permite: true,
            motivo: null,
          ),
          (
            caso: 'ítem sin responder',
            respuestas: {..._todasNo()}..remove('renal'),
            sexo: 'F',
            permite: false,
            motivo:
                'Falta responder «Insuficiencia renal o riesgo de '
                'deshidratación».',
          ),
          (
            caso: 'hombre: no se le pregunta embarazo ni lactancia',
            respuestas: _todasNo(sexo: 'M'),
            sexo: 'M',
            permite: true,
            motivo: null,
          ),
        ];
    for (final c in casos) {
      test(c.caso, () {
        final e = evaluarContraindicaciones(
          c.respuestas == null ? null : _revision(c.respuestas!),
          sexo: c.sexo,
        );
        expect(e.permiteIniciar, c.permite);
        if (c.motivo != null) expect(e.motivos, contains(c.motivo));
      });
    }

    test('la lista de un hombre no trae los ítems de mujeres', () {
      final m = contraindicacionesAplicables('M').map((i) => i.id);
      expect(m, isNot(contains('embarazo')));
      expect(m, isNot(contains('lactancia')));
      expect(m, isNot(contains('fertil')));
      // Sin sexo registrado, se pregunta todo.
      expect(
        contraindicacionesAplicables(null),
        hasLength(contraindicacionesGlp1.length),
      );
    });
  });

  group('Catálogo y plantillas', () {
    test('solo Ozempic trae registro; ningún esquema trae dosis', () async {
      final (b, _) = await _paciente();
      final cat = b.servicio.peso.catalogo;
      expect(cat.map((m) => m.id), [
        'semaglutida_sc',
        'semaglutida_oral',
        'liraglutida',
        'tirzepatida',
      ]);
      expect(cat.first.registroInvima, '2019M-0019473');
      expect(cat.skip(1).every((m) => !m.registroConfirmado), isTrue);
      expect(cat.every((m) => m.esquema.isEmpty), isTrue);
    });

    test('el esquema se aprueba y cambiarlo lo deja sin aprobar', () async {
      final (b, _) = await _paciente();
      final p = b.servicio.peso;
      expect(
        () => p.aprobarEsquema('liraglutida'),
        throwsStateError,
        reason: 'sin pasos no hay nada que aprobar',
      );
      final m = await p.guardarMedicamento(
        p
            .medicamento('liraglutida')!
            .copyWith(
              registroInvima: 'INVIMA-PRUEBA',
              esquema: const [
                PasoEsquema(semana: 0, dosis: 0.6),
                PasoEsquema(semana: 1, dosis: 1.2),
              ],
            ),
      );
      expect(m.esquemaAprobado, isFalse);
      expect(m.pasoEnSemana(1), isNull, reason: 'sin aprobar no sugiere');
      final a = await p.aprobarEsquema('liraglutida');
      expect(a.pasoEnSemana(3)!.dosis, 1.2);
      final cambiado = await p.guardarMedicamento(
        a.copyWith(esquema: const [PasoEsquema(semana: 0, dosis: 0.6)]),
      );
      expect(cambiado.esquemaAprobado, isFalse);
      // Cambiar solo el registro conserva la aprobación.
      await p.aprobarEsquema('liraglutida');
      final soloRegistro = await p.guardarMedicamento(
        p.medicamento('liraglutida')!.copyWith(registroInvima: 'OTRO'),
      );
      expect(soloRegistro.esquemaAprobado, isTrue);
    });

    test('una plantilla de plan en borrador no se asigna; aprobada rellena '
        'los marcadores', () async {
      final (b, _) = await _paciente();
      final p = b.servicio.peso;
      expect(
        () => p.asignarPlan('deficit_moderado', paciente: 'X'),
        throwsStateError,
      );
      await p.aprobarPlan('deficit_moderado');
      final plan = p.asignarPlan(
        'deficit_moderado',
        paciente: 'José Ángel Peña',
        proteina: '1,2 g/kg/día',
        metaPeso: 58,
      );
      expect(plan.version, 1);
      expect(plan.texto, contains('José Ángel Peña'));
      expect(plan.texto, contains('Proteína: 1,2 g/kg/día'));
      expect(plan.texto, contains('Meta de peso: 58 kg'));
      expect(plan.texto, contains('______'), reason: 'apartados en blanco');
    });
  });

  group('Programa y GLP-1', () {
    test('iniciar exige la revisión y bloquea las absolutas', () async {
      final (b, id) = await _paciente();
      final peso = b.servicio.peso;
      final p = await _programa(b, id);
      final dosis = DosisGlp1(fecha: DateTime(2026, 10, 2), dosis: 0.25);
      expect(
        () => peso.iniciarGlp1(
          p.id,
          medicamentoId: 'semaglutida_sc',
          dosis: dosis,
          sexo: 'F',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'mensaje',
            'Falta revisar la lista de contraindicaciones.',
          ),
        ),
      );
      await peso.revisarContraindicaciones(p.id, {
        ..._todasNo(),
        'cmt_men2': const RespuestaItem(RespuestaContra.si),
      }, sexo: 'F');
      expect(
        () => peso.iniciarGlp1(
          p.id,
          medicamentoId: 'semaglutida_sc',
          dosis: dosis,
          sexo: 'F',
        ),
        throwsStateError,
      );
      expect(
        () => peso.revisarContraindicaciones(p.id, {
          ..._todasNo(),
          'renal': const RespuestaItem(RespuestaContra.desconoce),
        }, sexo: 'F'),
        throwsStateError,
        reason: 'una precaución sin aclarar pide nota',
      );
      await peso.revisarContraindicaciones(p.id, {
        ..._todasNo(),
        'renal': const RespuestaItem(
          RespuestaContra.desconoce,
          'Pedir creatinina',
        ),
      }, sexo: 'F');
      final iniciado = await peso.iniciarGlp1(
        p.id,
        medicamentoId: 'semaglutida_sc',
        dosis: dosis,
        sexo: 'F',
      );
      final g = iniciado.glp1!;
      expect(g.nombre, 'Semaglutida (Ozempic®) · Subcutánea semanal');
      expect(g.registroInvima, '2019M-0019473');
      expect(
        textoInicioGlp1(g, iniciado.contraindicaciones),
        'Programa de peso: inicia Semaglutida (Ozempic®) 0,25 mg subcutánea '
        'semanal. Registro Invima 2019M-0019473. Contraindicaciones '
        'revisadas el 21/11/2026: ninguna absoluta; precauciones: '
        'Insuficiencia renal o riesgo de deshidratación (Pedir creatinina).',
      );
      expect(
        () => peso.iniciarGlp1(
          p.id,
          medicamentoId: 'tirzepatida',
          dosis: dosis,
          sexo: 'F',
        ),
        throwsStateError,
        reason: 'ya hay uno activo',
      );

      final d2 = DosisGlp1(fecha: DateTime(2026, 10, 30), dosis: 0.5);
      final conDosis = await peso.cambiarDosis(p.id, d2);
      expect(
        textoCambioDosis(conDosis.glp1!, d2),
        'Programa de peso: Semaglutida (Ozempic®), cambio de dosis a 0,5 mg '
        'subcutánea semanal.',
      );
      await peso.registrarTolerancia(
        p.id,
        RegistroTolerancia(
          fecha: DateTime(2026, 10, 30),
          sintomas: 'Náuseas',
          intensidad: Intensidad.leve,
        ),
      );
      final e = EventoAdverso(
        fecha: DateTime(2026, 11, 5),
        descripcion: 'Vómito',
        gravedad: Gravedad.moderada,
        conducta: 'Mantener la dosis',
        reportadoInvima: true,
      );
      final conEvento = await peso.registrarEvento(p.id, e);
      expect(
        textoEventoAdverso(conEvento.glp1!, e),
        'Evento adverso con Semaglutida (Ozempic®): Vómito (moderada). '
        'Conducta: Mantener la dosis. Reportado a Invima.',
      );
      final suspendido = await peso.suspenderGlp1(p.id, 'Intolerancia');
      expect(suspendido.glp1!.activo, isFalse);
      expect(
        textoSuspension(suspendido.glp1!),
        'Programa de peso: se suspende Semaglutida (Ozempic®). Motivo: '
        'Intolerancia.',
      );

      // Cifrado y legible al volver a abrir.
      expect(contieneTexto(b.todosLosBytes, 'Semaglutida'), isFalse);
      await b.servicio.bloquear();
      await b.servicio.desbloquear(fraseDePrueba);
      final otra = b.servicio.peso.programaDe(id)!;
      expect(otra.glp1!.dosis.map((d) => d.dosis), [0.25, 0.5]);
      expect(otra.glp1!.eventos.single.reportadoInvima, isTrue);
      expect(otra.glp1!.tolerancia.single.sintomas, 'Náuseas');
    });

    test('avance contra la meta', () async {
      final (b, id) = await _paciente();
      final p = await _programa(b, id);
      final s = b.servicio.seguimiento;
      // La historia trae 64,5 kg el 02/10/2026 (el día del inicio).
      await s.guardarMedicion(
        Medicion(
          id: '',
          pacienteId: id,
          fecha: DateTime(2026, 11, 20, 9),
          creado: DateTime(2026, 11, 20, 9),
          peso: 61,
        ),
      );
      final pr = b.servicio.peso.progreso(p, s.medicionesDe(id))!;
      expect(pr.inicial, 64.5);
      expect(pr.actual, 61);
      expect(pr.porcentaje, closeTo(-5.43, 0.01));
      expect(pr.faltan, 3);
    });

    test('indicaciones en PDF con el plan y el recordatorio', () async {
      final (b, id) = await _paciente();
      final peso = b.servicio.peso;
      await peso.aprobarPlan('fuerza_caminata');
      final p = await peso.guardar(
        (await _programa(b, id)).copyWith(
          proteina: '1,2 g/kg/día',
          planEjercicio: peso.asignarPlan('fuerza_caminata', paciente: 'José'),
        ),
      );
      final pdf = await peso.indicacionesPdf(
        p,
        b.servicio.indice.ficha(id)!,
        medico: medicoCompleto(),
        pais: Pais.colombia,
        fuentes: await FuentesPdf.cargar(),
      );
      final crudo = textoPdf(pdf);
      if (crudo == null) return;
      final texto = crudo.replaceAll(RegExp(r'\s+'), ' ');
      expect(texto, contains('INDICACIONES · PROGRAMA DE PESO'));
      expect(texto, contains('Proteína suficiente y entrenamiento de fuerza'));
      expect(texto, contains('Proteína indicada: 1,2 g/kg/día'));
      expect(texto, contains('PLAN DE EJERCICIO · FUERZA Y CAMINATA'));
      expect(texto, contains('peso 58 kg'));
    });
  });

  group('Pantalla', () {
    Future<ProviderContainer> montar(
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
      final c = ProviderContainer(
        overrides: [
          preferenciasProvider.overrideWithValue(prefs),
          rasterizadorProvider.overrideWithValue(rasterizadorDePrueba),
          servicioConsultorioProvider.overrideWithValue(b.servicio),
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
      return c;
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

    testWidgets('programa, contraindicaciones y GLP-1 copiado a la evolución', (
      t,
    ) async {
      final (b, id) = await _paciente();
      await b.servicio.peso.aprobarPlan('deficit_moderado');
      final c = await montar(t, b, '/pacientes/$id');
      await pulsar(t, find.text('Peso'));
      expect(find.text('Sin programa de peso.'), findsOneWidget);

      await pulsar(t, find.text('Iniciar programa'));
      await escribir(t, 'Peso meta', '58');
      await escribir(t, 'Proteína indicada', '1,2 g/kg/día');
      await pulsar(t, find.byType(DropdownButtonFormField<String?>).first);
      await pulsar(t, find.text('Déficit moderado (v1)').last);
      expect(find.textContaining('Proteína: 1,2 g/kg/día'), findsOneWidget);
      await pulsar(t, find.widgetWithText(FilledButton, 'Iniciar programa'));
      expect(find.textContaining('PROGRAMA DE PESO · desde'), findsOneWidget);
      expect(find.textContaining('Meta 58 kg'), findsOneWidget);
      expect(find.textContaining('Proteína suficiente'), findsOneWidget);

      // Sin revisar la lista no se puede iniciar.
      final iniciar = find.ancestor(
        of: find.text('Iniciar GLP-1'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(t.widget<ButtonStyleButton>(iniciar).onPressed, isNull);

      await pulsar(t, find.text('Revisar contraindicaciones'));
      final nos = find.text('No');
      final n = nos.evaluate().length;
      expect(n, contraindicacionesAplicables('F').length);
      for (var i = 0; i < n; i++) {
        await pulsar(t, find.text('No').at(i));
      }
      // Una precaución en «Sí» pide nota.
      await pulsar(t, find.text('Sí').at(5));
      expect(find.text('Nota *'), findsOneWidget);
      await pulsar(t, find.text('Guardar revisión'));
      expect(find.textContaining('Escribe una nota para'), findsOneWidget);
      await escribir(t, 'Nota *', 'Colelitiasis asintomática');
      await pulsar(t, find.text('Guardar revisión'));
      expect(find.textContaining('1 precaución con nota'), findsOneWidget);

      await pulsar(t, find.text('Iniciar GLP-1'));
      expect(find.text('Invima 2019M-0019473'), findsOneWidget);
      expect(find.text('Esquema sin aprobar'), findsOneWidget);
      await escribir(t, 'Dosis', '0,25');
      await pulsar(t, find.widgetWithText(FilledButton, 'Iniciar'));
      expect(find.textContaining('Dosis  21/11 0,25 mg'), findsOneWidget);
      final evolucion = c.read(historiaProvider).evolucionesNuevas.single;
      expect(
        evolucion.texto,
        startsWith(
          'Programa de peso: inicia Semaglutida (Ozempic®) 0,25 mg '
          'subcutánea semanal.',
        ),
      );
      expect(evolucion.texto, contains('Enfermedad biliar'));

      // La meta aparece en la gráfica del seguimiento.
      await pulsar(t, find.text('Seguimiento'));
      expect(find.byType(CustomPaint), findsWidgets);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('Ajustes: esquema del catálogo y plantillas de plan', (
      t,
    ) async {
      final (b, _) = await _paciente();
      await montar(t, b, '/ajustes');
      expect(find.text('Programa de peso'), findsOneWidget);
      expect(find.text('Registro Invima sin confirmar'), findsNWidgets(3));
      const tirzepatida =
          'Tirzepatida (GIP/GLP-1) (Mounjaro®) · Subcutánea semanal';
      await t.scrollUntilVisible(
        find.text(tirzepatida),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final fila = find
          .ancestor(of: find.text(tirzepatida), matching: find.byType(Column))
          .first;
      await pulsar(t, find.descendant(of: fila, matching: find.text('Editar')));
      await escribir(t, 'Registro Invima', 'INVIMA-PRUEBA');
      await pulsar(t, find.text('Agregar paso'));
      await escribir(t, 'Dosis', '2,5');
      await pulsar(t, find.widgetWithText(FilledButton, 'Guardar'));
      final m = b.servicio.peso.medicamento('tirzepatida')!;
      expect(m.registroInvima, 'INVIMA-PRUEBA');
      expect(m.esquema.single.dosis, 2.5);
      await pulsar(t, find.text('Aprobar esquema'));
      await pulsar(t, find.widgetWithText(FilledButton, 'Aprobar'));
      expect(
        b.servicio.peso.medicamento('tirzepatida')!.esquemaAprobado,
        isTrue,
      );
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('320 px: el programa de peso no se desborda', (t) async {
      final (b, id) = await _paciente();
      final p = await _programa(b, id);
      await b.servicio.peso.revisarContraindicaciones(
        p.id,
        _todasNo(),
        sexo: 'F',
      );
      await b.servicio.peso.iniciarGlp1(
        p.id,
        medicamentoId: 'semaglutida_sc',
        dosis: DosisGlp1(fecha: DateTime(2026, 10, 2), dosis: 0.25),
        sexo: 'F',
      );
      await montar(t, b, '/pacientes/$id', tamano: const Size(320, 640));
      await t.scrollUntilVisible(
        find.text('Peso'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await pulsar(t, find.text('Peso'));
      expect(t.takeException(), isNull);
      await t.drag(find.byType(Scrollable).last, const Offset(0, -1500));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.pump(const Duration(seconds: 5));
    });
  });
}
