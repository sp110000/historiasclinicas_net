import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/tema.dart';
import 'core/pdf/fuentes_pdf.dart';
import 'features/poc/poc_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Las fuentes del PDF se cargan al inicio: así generar un PDF funciona
  // aunque después se pierda la conexión.
  unawaited(FuentesPdf.cargar().then((_) {}, onError: (_) {}));
  runApp(const HistoriasClinicasApp());
}

class HistoriasClinicasApp extends StatelessWidget {
  const HistoriasClinicasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'historiasclinicas.net',
      debugShowCheckedModeBanner: false,
      theme: temaClaro(),
      locale: const Locale('es'),
      supportedLocales: const [
        Locale('es'),
        Locale('es', 'CO'),
        Locale('es', 'ES'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const PocPage(),
    );
  }
}
