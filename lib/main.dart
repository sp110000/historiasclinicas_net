import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/pdf/fuentes_pdf.dart';
import 'core/storage/preferencias.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Las fuentes del PDF se cargan al inicio: así generar un PDF funciona
  // aunque después se pierda la conexión.
  unawaited(FuentesPdf.cargar().then((_) {}, onError: (_) {}));
  final preferencias = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [preferenciasProvider.overrideWithValue(preferencias)],
      child: const HistoriasClinicasApp(),
    ),
  );
}
