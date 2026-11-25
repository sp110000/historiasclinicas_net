import 'package:go_router/go_router.dart';

import '../core/consultorio/config.dart';
import '../features/consultorio/rutas_consultorio.dart';
import '../features/historia/historia_page.dart';
import '../features/medico/medico_page.dart';
import '../features/receta/receta_page.dart';

/// Rutas: "/" historia clínica, "/receta" receta y "/medico" datos del
/// médico.
///
/// Flutter Web usa por defecto URLs con "#" (`/#/receta`), que funcionan en
/// cualquier hosting estático sin reglas de reescritura.
///
/// Con `CONSULTORIO_ENABLED` (constante, apagada por defecto) se usan las
/// rutas del consultorio; apagada, el compilador descarta esa rama y el
/// router es el de siempre.
GoRouter crearRouter() {
  if (consultorioHabilitado) return crearRouterConsultorio();
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HistoriaPage()),
      GoRoute(path: '/receta', builder: (context, state) => const RecetaPage()),
      GoRoute(path: '/medico', builder: (context, state) => const MedicoPage()),
    ],
  );
}
