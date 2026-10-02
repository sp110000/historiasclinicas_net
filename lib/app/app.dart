import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'tema.dart';

class HistoriasClinicasApp extends StatefulWidget {
  const HistoriasClinicasApp({super.key});

  @override
  State<HistoriasClinicasApp> createState() => _HistoriasClinicasAppState();
}

class _HistoriasClinicasAppState extends State<HistoriasClinicasApp> {
  final GoRouter _router = crearRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'historiasclinicas.net',
      debugShowCheckedModeBanner: false,
      theme: temaClaro(),
      routerConfig: _router,
      locale: const Locale('es'),
      supportedLocales: const [
        Locale('es'),
        Locale('es', 'CO'),
        Locale('es', 'ES'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
