import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/integridad/cadena_hash.dart';
import 'package:historiasclinicas_net/core/models/historia.dart';
import 'package:historiasclinicas_net/core/models/medico.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/storage/medico_store.dart';
import 'package:historiasclinicas_net/core/storage/preferencias.dart';
import 'package:historiasclinicas_net/features/historia/estado/historia_controller.dart';
import 'package:historiasclinicas_net/features/medico/medico_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ejemplos.dart';

Future<ProviderContainer> abrirApp() async {
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [preferenciasProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  c.listen(medicoProvider, (_, _) {}, fireImmediately: true);
  return c;
}

/// Historia inicial sellada con la copia de [medico].
Map<String, Object?> selladaCon(Medico medico) {
  final copia = instantaneaMedico(medico, pais: Pais.colombia);
  return sellarBase({
    ...historiaCompleta().aMapa(),
    'medico': copia.autor,
    'recursos': copia.recursos,
  });
}

Map<String, Object?> recursosDe(Map<String, Object?> datos) =>
    (datos['recursos']! as Map).cast();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({Claves.pais: 'CO'}));

  group('Datos del médico en el navegador', () {
    test('ida y vuelta con imágenes', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = MedicoStore(prefs);
      await store.guardar(medicoEjemplo());

      final leido = MedicoStore(prefs).leer();
      expect(leido.nombre, 'Dra. Ana Pérez Gómez');
      expect(leido.registro, 'RM 54321');
      expect(leido.firma, pngFirma);
      expect(leido.sello, pngSello);
      expect(leido.logo, pngLogo);
      expect(leido.configurado, isTrue);
    });

    test('sin nombre o registro no está configurado', () {
      expect(const Medico(nombre: 'Ana').configurado, isFalse);
      expect(const Medico(registro: '123').configurado, isFalse);
      expect(const Medico(nombre: ' ', registro: '1').configurado, isFalse);
    });

    test('vaciar todo borra la clave; un JSON dañado no rompe', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = MedicoStore(prefs);
      await store.guardar(medicoEjemplo());
      await store.guardar(const Medico());
      expect(prefs.getString(Claves.medico), isNull);

      await prefs.setString(Claves.medico, '{no es json');
      expect(store.leer().vacio, isTrue);
    });

    test('se guarda solo tras los cambios y se borra todo', () async {
      final c = await abrirApp();
      c
          .read(medicoProvider.notifier)
          .actualizar((m) => m.copyWith(nombre: 'Dr. Luis Mora'));
      await Future<void>.delayed(
        MedicoController.espera + const Duration(milliseconds: 100),
      );
      final otra = await abrirApp();
      expect(otra.read(medicoProvider).nombre, 'Dr. Luis Mora');

      await otra.read(medicoProvider.notifier).borrarTodo();
      expect(otra.read(medicoProvider).vacio, isTrue);
      expect((await abrirApp()).read(medicoProvider).vacio, isTrue);
    });
  });

  group('Copia del médico en los documentos', () {
    test('las imágenes se guardan por su SHA-256', () {
      final copia = instantaneaMedico(medicoEjemplo(), pais: Pais.colombia);
      final autor = Autor.desdeMapa(copia.autor);
      expect(autor.firma, hashImagen(pngFirma));
      expect(autor.sello, hashImagen(pngSello));
      expect(autor.logo, hashImagen(pngLogo));
      expect(copia.recursos[autor.firma], base64Encode(pngFirma));
      expect(copia.recursos, hasLength(3));
      expect(autor.lineaRegistro, 'Registro profesional RM 54321');
    });

    test('sin firma ni sello si se desactivan; etiqueta de España', () {
      final copia = instantaneaMedico(
        medicoEjemplo(),
        pais: Pais.espana,
        firma: false,
        sello: false,
      );
      final autor = Autor.desdeMapa(copia.autor);
      expect(autor.firma, isNull);
      expect(autor.sello, isNull);
      expect(copia.recursos.keys, [hashImagen(pngLogo)]);
      expect(autor.lineaRegistro, 'N.º de colegiado RM 54321');
    });
  });

  group('Imágenes y cadena de hashes', () {
    test('las imágenes no forman parte del hash de la historia', () {
      final datos = selladaCon(medicoEjemplo());
      final sinRecursos = {...datos}..remove('recursos');
      expect(calcularHashBase(sinRecursos), datos['hashBase']);
      expect(verificarIntegridad(datos).correcta, isTrue);
    });

    test('pero cambiar una imagen se detecta', () {
      final datos = selladaCon(medicoEjemplo());
      final hFirma = hashImagen(pngFirma);
      final alterados = {
        ...datos,
        'recursos': {...recursosDe(datos), hFirma: base64Encode(pngSello)},
      };
      final r = verificarIntegridad(alterados);
      expect(r.correcta, isFalse);
      expect(r.recursosAlterados, isTrue);
      expect(r.primeraAlterada, isNull, reason: 'el texto sigue intacto');
      expect(r.descripcion, contains('imágenes de firma, sello o logo'));
    });

    test('y también reemplazar la imagen con su propio hash', () {
      final datos = selladaCon(medicoEjemplo());
      final hFirma = hashImagen(pngFirma);
      final hOtra = hashImagen(pngLogo);
      final medico = {...(datos['medico']! as Map).cast<String, Object?>()};
      medico['firma'] = hOtra;
      final r = verificarIntegridad({...datos, 'medico': medico});
      expect(r.primeraAlterada, 0, reason: 'la referencia está sellada');
      final sinImagen = {...recursosDe(datos)}..remove(hFirma);
      expect(
        verificarIntegridad({...datos, 'recursos': sinImagen}).correcta,
        isFalse,
        reason: 'falta una imagen referenciada',
      );
    });

    test('evoluciones de otro médico conservan la cadena', () {
      final v1 = selladaCon(medicoEjemplo());
      final otro = Medico(
        nombre: 'Dr. Luis Mora',
        registro: 'RM 999',
        firma: pngLogo,
      );
      final copia = instantaneaMedico(otro, pais: Pais.colombia, logo: false);
      final v2 = sellarEvoluciones(v1, [
        {
          ...Evolucion(
            id: 'e1',
            fechaHora: DateTime(2026, 10, 9, 10, 30),
            texto: 'Afebril.',
          ).aMapa(),
          'autor': copia.autor,
        },
      ], recursos: copia.recursos);
      final r = verificarIntegridad(v2);
      expect(r.correcta, isTrue);
      expect(r.sellos, 2);
      expect(recursosDe(v2), hasLength(3), reason: 'el logo no se duplica');
      final e = Evolucion.desdeMapa(
        (v2['evoluciones']! as List).cast<Map<String, Object?>>().single,
      );
      expect(e.autor!.nombre, 'Dr. Luis Mora');
      expect(e.autor!.firma, hashImagen(pngLogo));
    });
  });

  group('Guardar con los datos del médico', () {
    test('la historia inicial lleva al médico y sus imágenes', () async {
      final c = await abrirApp();
      final ctrl = c.read(historiaProvider.notifier)
        ..actualizar((_) => historiaCompleta());
      final g = ctrl.prepararGuardado(
        medico: medicoEjemplo(),
        ahora: DateTime(2026, 10, 2, 9, 40),
      );
      final medico = Autor.desdeMapa((g.datos['medico']! as Map).cast());
      expect(medico.nombre, 'Dra. Ana Pérez Gómez');
      expect(medico.firma, hashImagen(pngFirma));
      expect(recursosDe(g.datos), hasLength(3));
      expect(verificarIntegridad(g.datos).correcta, isTrue);
    });

    test('respeta "Incluir firma" y sin médico no guarda nada', () async {
      final c = await abrirApp();
      final ctrl = c.read(historiaProvider.notifier)
        ..actualizar(
          (_) => historiaCompleta().copyWith(
            firma: const OpcionesFirma(incluirFirma: false),
          ),
        );
      final g = ctrl.prepararGuardado(medico: medicoEjemplo());
      final medico = Autor.desdeMapa((g.datos['medico']! as Map).cast());
      expect(medico.firma, isNull);
      expect(medico.sello, isNotNull);

      final sin = ctrl.prepararGuardado();
      expect(sin.datos.containsKey('medico'), isFalse);
      expect(sin.datos.containsKey('recursos'), isFalse);
      expect(verificarIntegridad(sin.datos).correcta, isTrue);
    });

    test('cada evolución nueva lleva su autor, sin logo', () async {
      final c = await abrirApp();
      final ctrl = c.read(historiaProvider.notifier)
        ..abrir(selladaCon(medicoEjemplo()), revision: 1)
        ..agregarEvolucion(ahora: DateTime(2026, 10, 9, 10, 30));
      final e = c.read(historiaProvider).evolucionesNuevas.single;
      ctrl.actualizarEvolucion(
        0,
        e.copyWith(texto: 'Mejoría.', incluirSello: false),
      );
      final g = ctrl.prepararGuardado(medico: medicoEjemplo());
      expect(g.revision, 2);
      final ev = Evolucion.desdeMapa(
        (g.datos['evoluciones']! as List).cast<Map<String, Object?>>().single,
      );
      expect(ev.autor!.nombre, 'Dra. Ana Pérez Gómez');
      expect(ev.autor!.firma, hashImagen(pngFirma));
      expect(ev.autor!.sello, isNull);
      expect(ev.autor!.logo, isNull);
      expect(verificarIntegridad(g.datos).correcta, isTrue);

      // Al abrirla de nuevo se ve quién firmó.
      ctrl.guardado(g, nombreArchivo: 'x.pdf');
      final estado = c.read(historiaProvider);
      expect(estado.medicoDeLaHistoria!.registro, 'RM 54321');
      expect(estado.evolucionesSelladas.single.autor!.nombre, contains('Ana'));
    });
  });
}
