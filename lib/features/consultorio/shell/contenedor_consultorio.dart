import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/widgets/marca.dart';
import '../buscador/buscador.dart';
import '../../historia/widgets/avisos.dart';
import '../desbloqueo/pantalla_desbloqueo.dart';
import '../../medico/medico_provider.dart';
import '../estado/consultorio_provider.dart';
import '../estado/presentacion_provider.dart';
import '../pacientes/franja_ficha.dart';
import '../respaldo/flujos_respaldo.dart';
import '../widgets/comunes.dart';
import '../widgets/texto_normativo.dart';

/// Un destino de la navegación del consultorio.
class DestinoConsultorio {
  const DestinoConsultorio({
    required this.ruta,
    required this.etiqueta,
    required this.icono,
    required this.iconoActivo,
    this.requiereDesbloqueo = true,
    this.etiquetaRiel,
  });

  final String ruta;
  final String etiqueta;
  final IconData icono;
  final IconData iconoActivo;

  /// La historia y la receta funcionan con el consultorio bloqueado.
  final bool requiereDesbloqueo;

  /// En el riel, si [etiqueta] no cabe (partida con guion).
  final String? etiquetaRiel;
}

/// Destinos del consultorio (pregunta 51); Procedimientos va debajo de la
/// historia y encima de la caja. El Inicio (rediseño R2) va primero.
const destinosConsultorio = [
  DestinoConsultorio(
    ruta: '/inicio',
    etiqueta: 'Inicio',
    icono: Icons.home_outlined,
    iconoActivo: Icons.home,
  ),
  DestinoConsultorio(
    ruta: '/agenda',
    etiqueta: 'Agenda',
    icono: Icons.calendar_month_outlined,
    iconoActivo: Icons.calendar_month,
  ),
  DestinoConsultorio(
    ruta: '/pacientes',
    etiqueta: 'Pacientes',
    icono: Icons.people_outline,
    iconoActivo: Icons.people,
  ),
  DestinoConsultorio(
    ruta: '/',
    etiqueta: 'Historia',
    icono: Icons.description_outlined,
    iconoActivo: Icons.description,
    requiereDesbloqueo: false,
  ),
  DestinoConsultorio(
    ruta: '/procedimientos',
    etiqueta: 'Procedimientos',
    etiquetaRiel: 'Procedi-\nmientos',
    icono: Icons.spa_outlined,
    iconoActivo: Icons.spa,
  ),
  DestinoConsultorio(
    ruta: '/caja',
    etiqueta: 'Caja',
    icono: Icons.point_of_sale_outlined,
    iconoActivo: Icons.point_of_sale,
  ),
  DestinoConsultorio(
    ruta: '/inventario',
    etiqueta: 'Inventario',
    icono: Icons.inventory_2_outlined,
    iconoActivo: Icons.inventory_2,
  ),
  DestinoConsultorio(
    ruta: '/ajustes',
    etiqueta: 'Ajustes',
    icono: Icons.settings_outlined,
    iconoActivo: Icons.settings,
  ),
];

/// Rótulos de grupo del menú lateral, antes del destino de ese índice.
final _grupos = <int, String>{
  for (final (i, d) in destinosConsultorio.indexed)
    if (d.ruta == '/agenda')
      i: 'CONSULTA'
    else if (d.ruta == '/caja')
      i: 'CONSULTORIO'
    else if (d.ruta == '/ajustes')
      i: 'AJUSTES',
};

/// Rutas que se muestran tal cual aunque el consultorio esté bloqueado.
const _rutasLibres = {'/', '/receta', '/medico'};

/// Ancho desde el que la navegación es un riel lateral.
const anchoRielConsultorio = 1100.0;

const _anchoRiel = 80.0;

/// Contenedor de todas las pantallas con la bandera encendida: navegación
/// del consultorio (riel en escritorio, menú lateral en pantallas
/// angostas), aviso de respaldo, bloqueo por inactividad y, en las
/// pantallas del consultorio, el desbloqueo mientras esté cerrado.
class ContenedorConsultorio extends ConsumerStatefulWidget {
  const ContenedorConsultorio({
    super.key,
    required this.ubicacion,
    required this.child,
  });

  final String ubicacion;
  final Widget child;

  @override
  ConsumerState<ContenedorConsultorio> createState() =>
      _ContenedorConsultorioState();
}

class _ContenedorConsultorioState extends ConsumerState<ContenedorConsultorio> {
  /// El cuerpo (aviso, franja y pantalla) se conserva al cruzar el corte
  /// del riel: con una llave global Flutter lo mueve en lugar de recrearlo.
  /// Así la pantalla no pierde su estado al girar o cambiar el tamaño de la
  /// ventana, y el árbol de accesibilidad no se rompe (sin la llave, el
  /// motor web lanzaba «Null check operator…» al quitar un área
  /// desplazable con la semántica activa).
  final _cuerpo = GlobalKey(debugLabel: 'cuerpo del consultorio');

  String get ubicacion => widget.ubicacion;
  Widget get child => widget.child;

  int get _indice {
    for (var i = destinosConsultorio.length - 1; i >= 0; i--) {
      final r = destinosConsultorio[i].ruta;
      if (r != '/' && ubicacion.startsWith(r)) return i;
    }
    // La historia (y la receta y los datos del médico, que salen de ella).
    return destinosConsultorio.indexWhere((d) => d.ruta == '/');
  }

  var _buscadorAbierto = false;

  Future<void> _buscar() async {
    if (_buscadorAbierto) return;
    _buscadorAbierto = true;
    try {
      await abrirBuscador(context, ref);
    } finally {
      _buscadorAbierto = false;
    }
  }

  /// «Nueva consulta»: la historia en blanco (si la que está en curso tiene
  /// cambios, la historia pregunta antes de limpiarla).
  void _nuevaConsulta() => context.go('/?nueva=1');

  @override
  Widget build(BuildContext context) {
    final e = ref.watch(consultorioProvider);
    final libre = _rutasLibres.contains(ubicacion);
    final cerrado = !e.desbloqueado || e.codigoPendiente != null;
    final contenido = !libre && cerrado ? const PantallaDesbloqueo() : child;
    // Cada pantalla vive en un Navigator anidado cuya barrera modal usa
    // BlockSemantics, que oculta a los lectores de pantalla todo lo pintado
    // antes (el riel, la barra y el aviso de respaldo) hasta el primer
    // contenedor semántico. Por eso la pantalla va en un contenedor propio.
    final cuerpo = Column(
      key: _cuerpo,
      children: [
        const _FranjaPresentacion(),
        const _AvisoRespaldo(),
        if (ubicacion == '/') const FranjaFicha(),
        Expanded(
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            child: contenido,
          ),
        ),
      ],
    );
    final ancho = MediaQuery.sizeOf(context).width;

    void ir(int i) => context.go(destinosConsultorio[i].ruta);

    final Widget pantalla;
    if (ancho >= anchoRielConsultorio) {
      // Las pantallas calculan sus cortes con el ancho de la ventana: se les
      // da el ancho que les queda a la derecha del riel.
      final mq = MediaQuery.of(context);
      // Material: da a los textos de fuera de las pantallas (el aviso de
      // respaldo) el estilo y la fuente del tema.
      pantalla = Material(
        color: ColoresMarca.fondo,
        child: Row(
          children: [
            _Riel(
              indice: _indice,
              alElegir: ir,
              alBuscar: _buscar,
              alNuevaConsulta: _nuevaConsulta,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: MediaQuery(
                data: mq.copyWith(
                  size: Size(ancho - _anchoRiel - 1, mq.size.height),
                ),
                child: cuerpo,
              ),
            ),
          ],
        ),
      );
    } else {
      pantalla = Scaffold(
        drawer: _MenuLateral(
          indice: _indice,
          alElegir: ir,
          alBuscar: _buscar,
          alNuevaConsulta: _nuevaConsulta,
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _BarraCompacta(alBuscar: _buscar),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: cuerpo,
                ),
              ),
            ],
          ),
        ),
      );
    }
    // Ctrl + K (⌘ + K en Mac) abre el buscador desde cualquier pantalla.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _buscar,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _buscar,
      },
      child: Focus(
        autofocus: true,
        child: _VigilanteInactividad(child: pantalla),
      ),
    );
  }
}

class _BotonCandado extends ConsumerWidget {
  const _BotonCandado();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(consultorioProvider);
    if (!e.desbloqueado) {
      return Tooltip(
        message: 'Consultorio bloqueado',
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            Icons.lock_outline,
            color: ColoresMarca.textoSuave,
            semanticLabel: 'Consultorio bloqueado',
          ),
        ),
      );
    }
    return IconButton(
      onPressed: () => ref.read(consultorioProvider.notifier).bloquear(),
      icon: const Icon(Icons.lock_open_outlined),
      tooltip: 'Bloquear el consultorio',
    );
  }
}

/// Enciende y apaga el modo presentación (pregunta 50). Solo con el
/// consultorio abierto: al bloquear se apaga.
class _BotonPresentacion extends ConsumerWidget {
  const _BotonPresentacion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(consultorioProvider).desbloqueado) {
      return const SizedBox.shrink();
    }
    final on = ref.watch(modoPresentacionProvider);
    return IconButton(
      isSelected: on,
      onPressed: () => ref.read(modoPresentacionProvider.notifier).cambiar(!on),
      icon: const Icon(Icons.co_present_outlined),
      selectedIcon: const Icon(Icons.co_present, color: ColoresMarca.primario),
      tooltip: on ? 'Salir del modo presentación' : 'Modo presentación',
    );
  }
}

/// Mientras el modo presentación está encendido, lo dice arriba (con
/// «Salir»), para que no quede encendido sin querer.
class _FranjaPresentacion extends ConsumerWidget {
  const _FranjaPresentacion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(modoPresentacionProvider)) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: ColoresMarca.tinte,
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          const Icon(Icons.co_present, size: 18, color: ColoresMarca.primario),
          const Text(
            'Modo presentación: sin notas por verificar, notas internas ni '
            'montos de la caja.',
            style: TextStyle(
              color: ColoresMarca.primario,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(modoPresentacionProvider.notifier).apagar(),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }
}

/// El logotipo del médico arriba del riel, con el nombre del consultorio
/// al pasar el puntero (pregunta 51); sin logotipo, el de la marca.
class _Logotipo extends ConsumerWidget {
  const _Logotipo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(medicoProvider);
    final logo = m.logo;
    if (logo == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 12, bottom: 8),
        child: Tooltip(
          message: 'historiasclinicas.net',
          child: LogoMarca(lado: 40),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Tooltip(
        message: m.consultorio.trim().isEmpty ? m.nombre : m.consultorio,
        child: Image.memory(
          logo,
          width: 44,
          height: 44,
          fit: BoxFit.contain,
          semanticLabel: m.consultorio.trim().isEmpty
              ? 'Logotipo'
              : 'Logotipo de ${m.consultorio.trim()}',
        ),
      ),
    );
  }
}

/// En la barra del móvil: el logotipo y el nombre del consultorio.
class _NombreConsultorio extends ConsumerWidget {
  const _NombreConsultorio();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(medicoProvider);
    final nombre = m.consultorio.trim().isEmpty
        ? 'Consultorio'
        : m.consultorio.trim();
    return Row(
      children: [
        if (m.logo != null) ...[
          Image.memory(
            m.logo!,
            width: 28,
            height: 28,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            nombre,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _Riel extends StatelessWidget {
  const _Riel({
    required this.indice,
    required this.alElegir,
    required this.alBuscar,
    required this.alNuevaConsulta,
  });

  final int indice;
  final ValueChanged<int> alElegir;
  final VoidCallback alBuscar;
  final VoidCallback alNuevaConsulta;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _anchoRiel,
      child: NavigationRail(
        selectedIndex: indice,
        onDestinationSelected: alElegir,
        labelType: NavigationRailLabelType.all,
        backgroundColor: Colors.white,
        minWidth: _anchoRiel,
        indicatorColor: ColoresMarca.tinte,
        selectedIconTheme: const IconThemeData(color: ColoresMarca.primario),
        unselectedIconTheme: const IconThemeData(
          color: ColoresMarca.textoSuave,
        ),
        selectedLabelTextStyle: const TextStyle(
          color: ColoresMarca.primario,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: ColoresMarca.textoSuave,
          fontSize: 12,
        ),
        leading: Column(
          children: [
            const _Logotipo(),
            IconButton.outlined(
              onPressed: alBuscar,
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Buscar (Ctrl + K)',
            ),
            const SizedBox(height: 8),
            Tooltip(
              message: 'Nueva consulta',
              child: IconButton.filled(
                onPressed: alNuevaConsulta,
                style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: const Icon(
                  Icons.add_rounded,
                  semanticLabel: 'Nueva consulta',
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
        trailing: const Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [_BotonPresentacion(), _BotonCandado()],
              ),
            ),
          ),
        ),
        destinations: [
          for (final d in destinosConsultorio)
            NavigationRailDestination(
              icon: Icon(d.icono),
              selectedIcon: Icon(d.iconoActivo),
              // «Procedimientos» no cabe en el riel: va partido con guion,
              // del mismo tamaño que las demás; el lector dice la palabra.
              label: Semantics(
                label: d.etiqueta,
                excludeSemantics: true,
                child: Text(
                  d.etiquetaRiel ?? d.etiqueta,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BarraCompacta extends StatelessWidget {
  const _BarraCompacta({required this.alBuscar});

  final VoidCallback alBuscar;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: ColoresMarca.borde)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu),
            tooltip: 'Menú del consultorio',
          ),
          const Expanded(child: _NombreConsultorio()),
          IconButton(
            onPressed: alBuscar,
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Buscar',
          ),
          const _BotonPresentacion(),
          const _BotonCandado(),
        ],
      ),
    );
  }
}

class _MenuLateral extends StatelessWidget {
  const _MenuLateral({
    required this.indice,
    required this.alElegir,
    required this.alBuscar,
    required this.alNuevaConsulta,
  });

  final int indice;
  final ValueChanged<int> alElegir;
  final VoidCallback alBuscar;
  final VoidCallback alNuevaConsulta;

  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
      selectedIndex: indice,
      backgroundColor: Colors.white,
      indicatorColor: ColoresMarca.tinte,
      onDestinationSelected: (i) {
        Navigator.pop(context);
        alElegir(i);
      },
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 22, 16, 14),
          child: NombreMarca(tamano: 16),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              alNuevaConsulta();
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nueva consulta'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              alBuscar();
            },
            icon: const Icon(Icons.search_rounded),
            label: const Text('Buscar'),
          ),
        ),
        for (final (i, d) in destinosConsultorio.indexed) ...[
          if (_grupos[i] case final g?)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 14, 16, 6),
              child: Text(g, style: EstilosMarca.rotulo),
            ),
          NavigationDrawerDestination(
            icon: Icon(d.icono),
            selectedIcon: Icon(d.iconoActivo, color: ColoresMarca.primario),
            label: Text(d.etiqueta),
          ),
        ],
      ],
    );
  }
}

/// «Último respaldo hace N días» cuando se pasa del plazo configurado.
class _AvisoRespaldo extends ConsumerWidget {
  const _AvisoRespaldo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(consultorioProvider);
    if (!e.desbloqueado || e.codigoPendiente != null) {
      return const SizedBox.shrink();
    }
    final ahora = ref.read(servicioConsultorioProvider).reloj.ahora();
    final r = e.respaldo;
    if (r != null && !r.vencido(ahora, e.configuracion.diasRespaldo)) {
      return const SizedBox.shrink();
    }
    final movil = MediaQuery.sizeOf(context).width < 700;
    return Padding(
      padding: EdgeInsets.fromLTRB(movil ? 12 : 24, 12, movil ? 12 : 24, 0),
      child: Aviso(
        icono: Icons.backup_outlined,
        color: ColoresMarca.aviso,
        titulo: r == null
            ? 'Todavía no has respaldado el consultorio'
            : 'Último respaldo ${haceDias(r.fecha, ahora)}',
        // En el teléfono, corto: el aviso entero se comía media pantalla y
        // dejaba sin lugar a pantallas como la del documento.
        texto: movil
            ? null
            : const TextoNormativo(
                'La custodia de las historias es tuya (Resolución 1995 de '
                '1999, VERIFICAR): si este equipo se daña o se pierde, o se '
                'borran los datos del navegador, solo el respaldo recupera '
                'el consultorio.',
              ),
        acciones: [
          FilledButton.icon(
            onPressed: () => respaldarYDescargar(context, ref),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Respaldar ahora'),
          ),
        ],
      ),
    );
  }
}

/// Bloquea el consultorio tras los minutos configurados sin tocar la
/// pantalla ni el teclado.
class _VigilanteInactividad extends ConsumerStatefulWidget {
  const _VigilanteInactividad({required this.child});

  final Widget child;

  @override
  ConsumerState<_VigilanteInactividad> createState() =>
      _VigilanteInactividadState();
}

class _VigilanteInactividadState extends ConsumerState<_VigilanteInactividad> {
  Timer? _temporizador;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_alTeclado);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_alTeclado);
    _temporizador?.cancel();
    super.dispose();
  }

  bool _alTeclado(KeyEvent _) {
    _reiniciar();
    return false;
  }

  void _reiniciar() {
    _temporizador?.cancel();
    final e = ref.read(consultorioProvider);
    if (!e.desbloqueado) return;
    _temporizador = Timer(
      Duration(minutes: e.configuracion.minutosBloqueo),
      _bloquear,
    );
  }

  Future<void> _bloquear() async {
    if (!mounted || !ref.read(consultorioProvider).desbloqueado) return;
    await ref.read(consultorioProvider.notifier).bloquear(automatico: true);
    if (mounted) {
      mostrarMensaje(context, 'El consultorio se bloqueó por inactividad.');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(consultorioProvider, (antes, ahora) {
      if (antes?.desbloqueado != ahora.desbloqueado ||
          antes?.configuracion.minutosBloqueo !=
              ahora.configuracion.minutosBloqueo) {
        _reiniciar();
      }
    });
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _reiniciar(),
      onPointerSignal: (PointerSignalEvent _) => _reiniciar(),
      child: widget.child,
    );
  }
}
