import 'package:go_router/go_router.dart';

import '../features/historia/historia_page.dart';
import '../features/receta/receta_page.dart';

/// Rutas: "/" historia clínica y "/receta" receta.
///
/// Flutter Web usa por defecto URLs con "#" (`/#/receta`), que funcionan en
/// cualquier hosting estático sin reglas de reescritura.
GoRouter crearRouter() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HistoriaPage()),
    GoRoute(path: '/receta', builder: (context, state) => const RecetaPage()),
  ],
);
