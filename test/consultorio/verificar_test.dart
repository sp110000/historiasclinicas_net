import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/app/tema.dart';
import 'package:historiasclinicas_net/core/consultorio/repositorio/bitacora.dart';
import 'package:historiasclinicas_net/core/consultorio/verificar/verificar.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/consultorio_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/estado/presentacion_provider.dart';
import 'package:historiasclinicas_net/features/consultorio/widgets/texto_normativo.dart';

import 'ayudas_consultorio.dart';

const _firma =
    'La firma y el sello son imágenes: no equivalen a una firma digital '
    'certificada. VERIFICAR su validez legal en tu país. Cualquiera con '
    'acceso a este navegador podría usarlas: bórralas si el equipo es '
    'compartido.';

void main() {
  group('Separar la nota «VERIFICAR» (por tabla)', () {
    final casos = <(String, String, String, List<String>)>[
      (
        'paréntesis con norma: queda la norma',
        'Los festivos de Colombia se calculan solos (Ley 51 de 1983, '
            'VERIFICAR). Una cita fuera del horario avisa.',
        'Los festivos de Colombia se calculan solos (Ley 51 de 1983). Una '
            'cita fuera del horario avisa.',
        ['Ley 51 de 1983, VERIFICAR'],
      ),
      (
        'paréntesis solo con la marca',
        'Festivo: Inmaculada Concepción (VERIFICAR)',
        'Festivo: Inmaculada Concepción',
        ['VERIFICAR'],
      ),
      (
        'oración que empieza con la marca (firma y sello)',
        _firma,
        'La firma y el sello son imágenes: no equivalen a una firma digital '
            'certificada. Cualquiera con acceso a este navegador podría '
            'usarlas: bórralas si el equipo es compartido.',
        ['VERIFICAR su validez legal en tu país.'],
      ),
      (
        'paréntesis con la nota completa (datos complementarios)',
        'Estado civil, ocupación, aseguradora y acompañante (VERIFICAR '
            'cuáles exige la norma)',
        'Estado civil, ocupación, aseguradora y acompañante',
        ['VERIFICAR cuáles exige la norma'],
      ),
      (
        'norma y nota en el mismo paréntesis',
        'Menores de 18 años prohibidos (Ley 1799 de 2016, VERIFICAR las '
            'excepciones).',
        'Menores de 18 años prohibidos (Ley 1799 de 2016).',
        ['Ley 1799 de 2016, VERIFICAR las excepciones'],
      ),
      (
        'entidad y nota',
        'Hazlo en tu sistema de facturación (DIAN, VERIFICAR con tu '
            'contador).',
        'Hazlo en tu sistema de facturación (DIAN).',
        ['DIAN, VERIFICAR con tu contador'],
      ),
      (
        'oración con la marca en medio (control especial)',
        'Los medicamentos de control especial pueden requerir recetario '
            'oficial (VERIFICAR la norma de tu país). Esta hoja podría no '
            'servir.',
        'Los medicamentos de control especial pueden requerir recetario '
            'oficial. Esta hoja podría no servir.',
        ['VERIFICAR la norma de tu país'],
      ),
      (
        'la marca fuera de paréntesis en medio de una oración',
        'En España, VERIFICAR si debe ser "Hoja de tratamiento". Lo demás '
            'sigue.',
        'Lo demás sigue.',
        ['En España, VERIFICAR si debe ser "Hoja de tratamiento".'],
      ),
      (
        'punto y coma dentro del paréntesis',
        'Suspender (una semana antes; VERIFICAR el plazo en la ficha '
            'técnica).',
        'Suspender (una semana antes).',
        ['una semana antes; VERIFICAR el plazo en la ficha técnica'],
      ),
      (
        'sin la marca, igual',
        'Sin nada que verificar.',
        'Sin nada que verificar.',
        [],
      ),
    ];
    for (final (caso, texto, limpio, notas) in casos) {
      test(caso, () {
        final s = separarVerificar(texto);
        expect(s.limpio, limpio);
        expect(s.notas, notas);
        expect(s.limpio, isNot(contains('VERIFICAR')));
      });
    }
  });

  test('la clave no cambia con mayúsculas, tildes ni espacios', () {
    expect(
      claveVerificacion('Ley 51  de 1983, VERIFICAR'),
      claveVerificacion('ley 51 de 1983, verificár'),
    );
    expect(
      claveVerificacion('Ley 51 de 1983, VERIFICAR'),
      isNot(claveVerificacion('Ley 52 de 1983, VERIFICAR')),
    );
  });

  test('registro: marcar, validar, quitar; cifrado y al reabrir', () async {
    final b = BancoConsultorio();
    await b.servicio.crear(fraseDePrueba);
    final v = b.servicio.verificaciones;
    await expectLater(
      v.marcar(_firma, fecha: DateTime(2026, 11, 21), fuente: ' '),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      v.marcar(_firma, fecha: DateTime(2026, 11, 22), fuente: 'x'),
      throwsA(
        isA<StateError>().having((e) => e.message, 'm', contains('futura')),
      ),
    );
    await expectLater(
      v.marcar('Sin marca', fecha: DateTime(2026, 11, 21), fuente: 'x'),
      throwsA(isA<StateError>()),
    );
    await v.marcar(
      _firma,
      fecha: DateTime(2026, 11, 20),
      fuente: 'Concepto del abogado',
    );
    expect(v.de(_firma)!.fuente, 'Concepto del abogado');
    expect(contieneTexto(b.todosLosBytes, 'Concepto del abogado'), isFalse);
    await b.servicio.bloquear();
    expect(v.de(_firma), isNull);
    await b.servicio.desbloquear(fraseDePrueba);
    expect(v.de(_firma)!.fecha, DateTime(2026, 11, 20));
    await v.quitar(_firma);
    expect(v.todas, isEmpty);
    await b.servicio.bloquear();
    await b.servicio.desbloquear(fraseDePrueba);
    expect(v.todas, isEmpty);
    final acciones = (await leerBitacora(
      b.servicio.repositorio,
    )).map((e) => e.accion).toSet();
    expect(
      acciones,
      containsAll([
        AccionBitacora.verificarNota,
        AccionBitacora.quitarVerificacion,
      ]),
    );
  });

  testWidgets('chip «Por verificar», registrar la verificación y modo '
      'presentación (se apaga al bloquear)', (t) async {
    final b = BancoConsultorio();
    await b.servicio.crear(fraseDePrueba);
    final c = ProviderContainer(
      overrides: [servicioConsultorioProvider.overrideWithValue(b.servicio)],
    );
    addTearDown(c.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: temaClaro(),
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const Scaffold(body: TextoNormativo(_firma)),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('VERIFICAR', findRichText: true), findsNothing);
    expect(
      find.textContaining(
        'no equivalen a una firma digital',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('Por verificar'), findsOneWidget);

    await t.tap(find.text('Por verificar'));
    await t.pumpAndSettle();
    expect(find.text('Nota por verificar'), findsOneWidget);
    expect(find.text('VERIFICAR su validez legal en tu país.'), findsOneWidget);
    await t.enterText(
      find.ancestor(
        of: find.text('Fuente *'),
        matching: find.byType(TextField),
      ),
      'Res. 1995/1999',
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Marcar como verificada'));
    await t.pumpAndSettle();
    expect(
      find.text('Verificado el 21/11/2026 · Res. 1995/1999'),
      findsOneWidget,
    );

    // Modo presentación: ni el chip ni la marca.
    c.read(modoPresentacionProvider.notifier).cambiar(true);
    await t.pumpAndSettle();
    expect(find.textContaining('Verificado'), findsNothing);
    expect(find.byType(ChipVerificar), findsNothing);
    expect(find.textContaining('VERIFICAR', findRichText: true), findsNothing);

    // Al bloquear se apaga; con el consultorio bloqueado, el chip vuelve a
    // «Por verificar» (el registro está cifrado).
    await c.read(consultorioProvider.notifier).bloquear();
    await t.pumpAndSettle();
    expect(c.read(modoPresentacionProvider), isFalse);
    expect(find.text('Por verificar'), findsOneWidget);
    await t.tap(find.text('Por verificar'));
    await t.pumpAndSettle();
    expect(
      find.text('Desbloquea el consultorio para registrar la verificación.'),
      findsOneWidget,
    );
    await t.pump(const Duration(seconds: 5));
  });
}
