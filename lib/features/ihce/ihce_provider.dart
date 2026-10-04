import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ihce/almacen/almacen_kv.dart';
import '../../core/ihce/almacen/repositorio_ihce.dart';
import '../../core/ihce/cifrado/cifrador.dart';
import '../../core/ihce/cliente/transporte.dart';
import '../../core/ihce/conectividad.dart';
import '../../core/ihce/config/config_ihce.dart';
import '../../core/ihce/ensamblado/pdf_soporte.dart';
import '../../core/ihce/modelo/prestador_ihce.dart';
import '../../core/ihce/outbox/servicio_ihce.dart';
import '../../core/ihce/secretos/almacen_secretos.dart';
import '../../core/ihce/terminologia/catalogo_terminologia.dart';
import '../../core/ihce/validacion/esquema_fhir.dart';
import '../../core/storage/preferencias.dart';
import '../cie10/cie10_provider.dart';

/// Configuración no secreta del módulo (compilada). Con `IHCE_ENABLED`
/// apagado (por defecto) nada del módulo se crea ni se muestra.
final configIhceProvider = Provider<ConfigIhce>(
  (ref) => ConfigIhce.desdeEntorno(),
);

/// `flutter_secure_storage` en la app; las pruebas lo sustituyen.
final almacenSecretosProvider = Provider<AlmacenSecretos>(
  (ref) => AlmacenSecretosSeguro(),
);

final credencialesIhceProvider = Provider<ServicioCredenciales>(
  (ref) => ServicioCredenciales(
    ref.watch(almacenSecretosProvider),
    ref.watch(configIhceProvider).ambiente,
  ),
);

final prestadorIhceStoreProvider = Provider<PrestadorIhceStore>(
  (ref) => PrestadorIhceStore(ref.watch(preferenciasProvider)),
);

/// Configuración del prestador para el RDA (se guarda sola tras cada cambio).
final prestadorIhceProvider =
    NotifierProvider<PrestadorIhceController, PrestadorIhce>(
      PrestadorIhceController.new,
    );

class PrestadorIhceController extends Notifier<PrestadorIhce> {
  @override
  PrestadorIhce build() => ref.read(prestadorIhceStoreProvider).leer();

  Future<void> actualizar(PrestadorIhce Function(PrestadorIhce p) cambio) {
    state = cambio(state);
    return ref.read(prestadorIhceStoreProvider).guardar(state);
  }
}

/// Cambia cada vez que el worker cambia el estado de un documento: la
/// interfaz relee el estado de la atención.
final cambiosIhceProvider = NotifierProvider<CambiosIhce, int>(CambiosIhce.new);

class CambiosIhce extends Notifier<int> {
  @override
  int build() => 0;

  void avisar() => state++;
}

/// El servicio del RDA, o `null` con el módulo deshabilitado.
final servicioIhceProvider = Provider<ServicioIhce?>((ref) {
  final config = ref.watch(configIhceProvider);
  if (!config.habilitado) return null;
  final secretos = ref.watch(almacenSecretosProvider);
  final repositorio = RepositorioIhce(almacenKvDePlataforma());
  TransporteIhce transporte;
  try {
    transporte = crearTransporteDirecto(config);
  } on Object {
    // Sin TLS 1.3 falla el cliente, nunca la app clínica.
    transporte = const TransporteNoDisponible();
  }
  CatalogoTerminologia? catalogo;
  ValidadorEsquemaFhir? esquema;
  final servicio = ServicioIhce(
    config: config,
    repositorio: repositorio,
    cifrador: CifradorDatos(secretos),
    credenciales: ref.watch(credencialesIhceProvider),
    transporte: transporte,
    pdf: const GeneradorPdfHistoria(),
    cargarCatalogo: () async {
      if (catalogo != null) return catalogo!;
      final c = CatalogoTerminologia.desdeGuia(
        await _leerAsset('assets/ihce/catalogos_guia.json'),
      );
      c.usarCie10(
        await ref.read(catalogoCie10Provider.future),
        config.fuenteDisplayCie10,
      );
      return catalogo = c;
    },
    cargarEsquema: () async => esquema ??= ValidadorEsquemaFhir.desdeTexto(
      await _leerAsset('assets/ihce/fhir.schema.json'),
    ),
    alCambiar: () => ref.read(cambiosIhceProvider.notifier).avisar(),
  );
  final reconexion = conexionRecuperada().listen(
    (_) => unawaited(servicio.procesarPendientes()),
  );
  ref.onDispose(reconexion.cancel);
  return servicio;
});

/// `load` y no `loadString` (ver `cargarCatalogoIncluido`).
Future<String> _leerAsset(String ruta) async {
  final datos = await rootBundle.load(ruta);
  return utf8.decode(
    datos.buffer.asUint8List(datos.offsetInBytes, datos.lengthInBytes),
  );
}

/// Estado del RDA de una atención (solo lectura).
final estadoRdaProvider = Provider.family<EstadoRdaAtencion?, String>((
  ref,
  atencionId,
) {
  ref.watch(cambiosIhceProvider);
  return ref.watch(servicioIhceProvider)?.estadoDe(atencionId);
});
