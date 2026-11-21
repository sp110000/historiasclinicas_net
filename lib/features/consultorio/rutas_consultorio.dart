import 'package:go_router/go_router.dart';

import '../historia/historia_page.dart';
import '../medico/medico_page.dart';
import '../receta/receta_page.dart';
import 'ajustes/ajustes_page.dart';
import 'pacientes/ficha_page.dart';
import 'pacientes/pacientes_page.dart';
import 'shell/contenedor_consultorio.dart';

/// Router con la bandera encendida: las rutas de siempre más las del
/// consultorio, todas dentro del [ContenedorConsultorio]. Solo se llama
/// desde `crearRouter()` bajo `if (consultorioHabilitado)`, así que con la
/// bandera apagada no se compila en el sitio.
GoRouter crearRouterConsultorio({String ubicacionInicial = '/'}) => GoRouter(
  initialLocation: ubicacionInicial,
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          ContenedorConsultorio(ubicacion: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HistoriaPage()),
        GoRoute(
          path: '/receta',
          builder: (context, state) => const RecetaPage(),
        ),
        GoRoute(
          path: '/medico',
          builder: (context, state) => const MedicoPage(),
        ),
        GoRoute(
          path: '/pacientes',
          builder: (context, state) => const PacientesPage(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  FichaPage(id: state.pathParameters['id']!),
            ),
          ],
        ),
        GoRoute(
          path: '/ajustes',
          builder: (context, state) => const AjustesConsultorioPage(),
        ),
      ],
    ),
  ],
);
