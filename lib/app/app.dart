import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/pwa/avisos_pwa.dart';
import 'router.dart';
import 'tema.dart';

class HistoriasClinicasApp extends ConsumerStatefulWidget {
  const HistoriasClinicasApp({super.key});

  @override
  ConsumerState<HistoriasClinicasApp> createState() =>
      _HistoriasClinicasAppState();
}

class _HistoriasClinicasAppState extends ConsumerState<HistoriasClinicasApp> {
  final GoRouter _router = crearRouter();
  final _mensajero = GlobalKey<ScaffoldMessengerState>();
  late final StreamSubscription<AvisoPwa> _avisos;

  @override
  void initState() {
    super.initState();
    // "Ya funciona sin conexión" y "Hay una versión nueva".
    _avisos = mostrarAvisosPwa(ref, _mensajero);
  }

  @override
  void dispose() {
    unawaited(_avisos.cancel());
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
      scaffoldMessengerKey: _mensajero,
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
