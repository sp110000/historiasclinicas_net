import 'dart:convert';
import 'dart:typed_data';

import '../almacen/almacen.dart';
import '../seguridad/boveda.dart';
import 'repositorio.dart';

/// Un paso del esquema del consultorio. [preparar] lee lo que necesite
/// (descifrado) y devuelve los cambios ya cifrados; se aplican junto con la
/// versión nueva en una sola transacción.
class MigracionConsultorio {
  const MigracionConsultorio(this.version, this.descripcion, this.preparar);

  final int version;
  final String descripcion;
  final Future<List<Cambio>> Function(RepositorioConsultorio repositorio)
  preparar;
}

/// Versión 1: el esquema inicial (Fase 5.0). No transforma nada.
final migracionesConsultorio = <MigracionConsultorio>[
  MigracionConsultorio(1, 'Esquema inicial', (_) async => const []),
];

int get versionEsquemaActual => migracionesConsultorio.last.version;

Uint8List _bytesVersion(int v) => Uint8List.fromList(utf8.encode('$v'));

Future<int> leerVersionEsquema(AlmacenConsultorio almacen) async {
  final b = await almacen.leer(Deposito.meta, ClavesMeta.esquema);
  return b == null ? 0 : int.tryParse(utf8.decode(b)) ?? 0;
}

/// Aplica las migraciones pendientes, una transacción por versión. Lanza
/// [StateError] si el almacén es de una versión más nueva que la app.
Future<int> migrar(
  RepositorioConsultorio repositorio, {
  List<MigracionConsultorio>? migraciones,
}) async {
  final lista = migraciones ?? migracionesConsultorio;
  final almacen = repositorio.boveda.almacen;
  var actual = await leerVersionEsquema(almacen);
  if (actual > lista.last.version) {
    throw StateError(
      'Los datos del consultorio son de una versión más nueva de la app. '
      'Actualiza la app antes de abrirlos.',
    );
  }
  for (final m in lista.where((m) => m.version > actual)) {
    await repositorio.esperarEscrituras();
    final cambios = await m.preparar(repositorio);
    await almacen.aplicar([
      ...cambios,
      Cambio(Deposito.meta, ClavesMeta.esquema, _bytesVersion(m.version)),
    ]);
    actual = m.version;
  }
  return actual;
}
