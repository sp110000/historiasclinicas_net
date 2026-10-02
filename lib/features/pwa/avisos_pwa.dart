import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pwa/pwa.dart' as pwa;
import '../historia/estado/borrador_provider.dart';
import '../medico/medico_provider.dart';
import '../receta/estado/receta_controller.dart';

export '../../core/pwa/pwa.dart' show AvisoPwa;

final avisosPwaProvider = Provider<Stream<pwa.AvisoPwa>>(
  (ref) => pwa.escucharAvisosPwa(),
);

/// Recarga la app (para usar la versión nueva) sin perder lo que esperaba
/// guardarse.
final recargarAppProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    await ref.read(borradorProvider.notifier).guardarPendiente();
    if (ref.exists(recetaProvider)) {
      await ref.read(recetaProvider.notifier).guardarPendiente();
    }
    if (ref.exists(medicoProvider)) {
      await ref.read(medicoProvider.notifier).guardarPendiente();
    }
    pwa.recargarApp();
  },
);

/// Muestra los avisos del service worker con [mensajero].
StreamSubscription<pwa.AvisoPwa> mostrarAvisosPwa(
  WidgetRef ref,
  GlobalKey<ScaffoldMessengerState> mensajero,
) => ref.read(avisosPwaProvider).listen((aviso) {
  final m = mensajero.currentState;
  if (m == null) return;
  switch (aviso) {
    case pwa.AvisoPwa.listaSinConexion:
      m.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 6),
          content: Text(
            'Listo: la app quedó guardada en este navegador y ya funciona '
            'sin conexión.',
          ),
        ),
      );
    case pwa.AvisoPwa.versionNueva:
      m
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(days: 1),
            content: const Text(
              'Hay una versión nueva de la app. Lo que estás escribiendo se '
              'conserva al actualizar.',
            ),
            action: SnackBarAction(
              label: 'Actualizar',
              onPressed: () => ref.read(recargarAppProvider)(),
            ),
          ),
        );
  }
});
