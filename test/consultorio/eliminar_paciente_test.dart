import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/consultorio/agenda/cita.dart';
import 'package:historiasclinicas_net/core/consultorio/indice/eliminar_paciente.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/ficha_paciente.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/repositorio/bitacora.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';

import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';

void main() {
  late BancoConsultorio b;
  late ServicioConsultorio s;

  setUp(() async {
    b = BancoConsultorio();
    s = b.servicio;
    await s.crear(fraseDePrueba);
  });

  FichaPaciente borrador({String documento = '444'}) => FichaPaciente(
    id: '',
    clave: '',
    creado: b.reloj.ahora(),
    actualizado: b.reloj.ahora(),
    tipoDocumento: 'CC',
    numeroDocumento: documento,
    primerApellido: 'Ruiz',
    nombres: 'Carla',
  );

  Future<String> conHistoria({String id = 'h-1'}) async {
    final r = await s.registrarHistoria(
      HistoriaPendiente(
        datos: historiaSintetica(id: id),
        revision: 1,
        origen: OrigenArchivo.importado,
      ),
    );
    return r!.pacienteId;
  }

  Future<void> reabrir() async {
    await s.bloquear();
    await s.desbloquear(fraseDePrueba);
  }

  Future<List<AccionBitacora>> acciones() async => [
    for (final e in await leerBitacora(s.repositorio)) e.accion,
  ];

  test(
    'sin registros: la ficha se borra del todo y «Deshacer» la repone',
    () async {
      final f = await s.indice.crearFicha(borrador());
      expect(s.registrosDe(f.id).vacio, isTrue);

      expect(await s.eliminarPaciente(f.id), ResultadoEliminacion.borrada);
      expect(s.indice.ficha(f.id), isNull);
      expect(s.indice.fichasEliminadas, isEmpty);
      await reabrir();
      expect(s.indice.ficha(f.id), isNull);
      // El documento queda libre.
      expect(s.indice.porClave('CC:444'), isNull);

      await s.restaurarPaciente(f.id, original: f);
      expect(s.indice.ficha(f.id)?.visible, isTrue);
      await reabrir();
      expect(s.indice.fichasActivas.map((x) => x.id), contains(f.id));
      expect(
        await acciones(),
        containsAll([
          AccionBitacora.eliminarPaciente,
          AccionBitacora.restaurarPaciente,
        ]),
      );
    },
  );

  test(
    'con historia: se oculta, todo se conserva y se puede restaurar',
    () async {
      final id = await conHistoria();
      final r = s.registrosDe(id);
      expect(r.vacio, isFalse);
      expect(r.partes, contains('1 historia'));

      expect(await s.eliminarPaciente(id), ResultadoEliminacion.oculta);
      await reabrir();
      final f = s.indice.ficha(id)!;
      expect(f.eliminada, b.reloj.ahora());
      expect(f.visible, isFalse);
      // Fuera de la lista, la búsqueda y los controles; la historia sigue.
      expect(s.indice.fichasActivas, isEmpty);
      expect(s.indice.buscar(texto: 'pena'), isEmpty);
      expect(s.indice.fichasEliminadas.single.id, id);
      expect(s.indice.historiasDe(id), hasLength(1));
      // Un paciente nuevo con su documento no la duplica.
      await expectLater(
        () => s.indice.crearFicha(borrador(documento: '1032456789')),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'mensaje',
            contains('Pacientes eliminados'),
          ),
        ),
      );

      await s.restaurarPaciente(id);
      await reabrir();
      expect(s.indice.ficha(id)!.visible, isTrue);
      expect(s.indice.fichasEliminadas, isEmpty);
      expect(s.indice.buscar(texto: 'pena').single.ficha.id, id);
    },
  );

  test(
    'una historia nueva del paciente eliminado lo devuelve a la lista',
    () async {
      final id = await conHistoria();
      await s.eliminarPaciente(id);
      expect(await conHistoria(id: 'h-2'), id);
      expect(s.indice.ficha(id)!.visible, isTrue);
      expect(s.indice.historiasDe(id), hasLength(2));
    },
  );

  test('con citas por venir no se elimina hasta cancelarlas', () async {
    final id = await conHistoria();
    final cita = await s.agenda.guardar(
      s.agenda.nueva(
        tipo: TipoCita.control,
        inicio: DateTime(2026, 11, 24, 10),
        pacienteId: id,
      ),
    );
    expect(s.registrosDe(id).citasPorVenir.single.id, cita.id);
    await expectLater(() => s.eliminarPaciente(id), throwsStateError);
    expect(s.indice.ficha(id)!.visible, isTrue);

    await s.agenda.cambiarEstado(
      cita.id,
      EstadoCita.cancelada,
      motivo: 'Viaje',
    );
    expect(s.registrosDe(id).citasPorVenir, isEmpty);
    expect(s.registrosDe(id).partes, containsAll(['1 historia', '1 cita']));
    expect(await s.eliminarPaciente(id), ResultadoEliminacion.oculta);
  });
}
