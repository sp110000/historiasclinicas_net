import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cie10/almacen_cie10.dart' as almacen;
import '../../core/cie10/catalogo_cie10.dart';
import '../../core/models/mapa.dart';
import '../../core/storage/preferencias.dart';

/// Datos del catálogo importado (sin cargarlo).
class InfoCie10 {
  const InfoCie10({
    required this.archivo,
    required this.cantidad,
    required this.importado,
  });

  factory InfoCie10.desdeMapa(Map<String, Object?> m) => InfoCie10(
    archivo: m.texto('archivo'),
    cantidad: m.entero('cantidad') ?? 0,
    importado: m.fecha('importado')!,
  );

  final String archivo;
  final int cantidad;
  final DateTime importado;

  Map<String, Object?> aMapa() => {
    'archivo': archivo,
    'cantidad': cantidad,
    'importado': fechaHoraIso(importado),
  };
}

final infoCie10Provider = NotifierProvider<Cie10Controller, InfoCie10?>(
  Cie10Controller.new,
);

class Cie10Controller extends Notifier<InfoCie10?> {
  @override
  InfoCie10? build() {
    final texto = ref.read(preferenciasProvider).getString(Claves.cie10);
    if (texto == null) return null;
    try {
      return InfoCie10.desdeMapa((jsonDecode(texto) as Map).cast());
    } on Object {
      return null;
    }
  }

  /// Lee y guarda el catálogo de [nombre]. Lanza [FormatException] si el
  /// archivo no sirve.
  Future<LecturaCie10> importar(String nombre, Uint8List bytes) async {
    final lectura = leerCatalogoCie10(bytes);
    await almacen.guardarCatalogo(lectura.catalogo.aJson());
    final info = InfoCie10(
      archivo: nombre,
      cantidad: lectura.catalogo.length,
      importado: DateTime.now(),
    );
    await ref
        .read(preferenciasProvider)
        .setString(Claves.cie10, jsonEncode(info.aMapa()));
    state = info;
    return lectura;
  }

  Future<void> borrar() async {
    await almacen.borrarCatalogo();
    await ref.read(preferenciasProvider).remove(Claves.cie10);
    state = null;
  }
}

/// El catálogo se lee de IndexedDB la primera vez que se usa.
final catalogoCie10Provider = FutureProvider<CatalogoCie10?>((ref) async {
  final info = ref.watch(infoCie10Provider);
  if (info == null) return null;
  final json = await almacen.leerCatalogoGuardado();
  return json == null ? null : CatalogoCie10.desdeJson(json);
});
