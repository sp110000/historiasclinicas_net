import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/almacen/navegador.dart';
import '../../../core/consultorio/repositorio/bitacora.dart';
import '../../../core/consultorio/seguridad/derivacion.dart';
import '../../../core/consultorio/seguridad/fortaleza.dart';
import '../../../core/consultorio/seguridad/medicion.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/campos.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../desbloqueo/panel_codigo.dart';
import '../estado/consultorio_provider.dart';
import '../respaldo/flujos_respaldo.dart';
import '../widgets/comunes.dart';

/// Ajustes del consultorio: seguridad, respaldo y bitácora.
class AjustesConsultorioPage extends ConsumerWidget {
  const AjustesConsultorioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ajustes del consultorio',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: const CuerpoConsultorio(
        children: [
          _Seguridad(),
          SizedBox(height: 16),
          _Respaldo(),
          SizedBox(height: 16),
          _Bitacora(),
        ],
      ),
    );
  }
}

/// Las opciones fijas más el valor guardado, si es otro.
List<int> _opciones(List<int> fijas, int actual) =>
    ({...fijas, actual}.toList()..sort());

class _Seguridad extends ConsumerStatefulWidget {
  const _Seguridad();

  @override
  ConsumerState<_Seguridad> createState() => _SeguridadState();
}

class _SeguridadState extends ConsumerState<_Seguridad> {
  String? _medicion;
  var _midiendo = false;

  Future<void> _medir() async {
    setState(() {
      _midiendo = true;
      _medicion = null;
    });
    String ms(Duration d) => '${d.inMilliseconds} ms';
    try {
      final pbkdf2 = await medirDerivacion(
        ParametrosDerivacion.frasePorDefecto,
      );
      final argon = await medirDerivacion(ParametrosDerivacion.argon2idOwasp);
      _medicion =
          '${ParametrosDerivacion.frasePorDefecto.descripcion}: ${ms(pbkdf2)}\n'
          '${ParametrosDerivacion.argon2idOwasp.descripcion}: ${ms(argon)}';
    } catch (e) {
      _medicion = mensajeDeError(e);
    } finally {
      if (mounted) setState(() => _midiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = ref.watch(consultorioProvider);
    final ctrl = ref.read(consultorioProvider.notifier);
    return TarjetaConsultorio(
      icono: Icons.lock_outline,
      titulo: 'Seguridad',
      subtitulo: 'Frase de acceso, código de recuperación y bloqueo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: DropdownButtonFormField<int>(
                  initialValue: e.configuracion.minutosBloqueo,
                  decoration: const InputDecoration(
                    labelText: 'Bloquear tras minutos sin actividad',
                  ),
                  items: [
                    for (final m in _opciones(const [
                      2,
                      5,
                      10,
                      15,
                      30,
                      60,
                    ], e.configuracion.minutosBloqueo))
                      DropdownMenuItem(value: m, child: Text('$m minutos')),
                  ],
                  onChanged: (m) => m == null
                      ? null
                      : ctrl.guardarConfiguracion(
                          e.configuracion.copyWith(minutosBloqueo: m),
                        ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => ctrl.bloquear(),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Bloquear ahora'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _DialogoCambiarFrase(),
                ),
                icon: const Icon(Icons.password_outlined),
                label: const Text('Cambiar la frase de acceso'),
              ),
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _DialogoCodigoNuevo(),
                ),
                icon: const Icon(Icons.key_outlined),
                label: const Text('Generar un código de recuperación nuevo'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('EN ESTE EQUIPO', style: EstilosMarca.rotulo),
          const SizedBox(height: 8),
          const Text(
            'Mide cuánto tarda este equipo en derivar la llave con cada '
            'método. Sirve para decidir si conviene usar Argon2id.',
            style: TextStyle(color: ColoresMarca.textoSuave, fontSize: 13.5),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _midiendo ? null : _medir,
              icon: const Icon(Icons.speed_outlined),
              label: Text(_midiendo ? 'Midiendo…' : 'Medir la derivación'),
            ),
          ),
          if (_medicion != null)
            SelectableText(
              _medicion!,
              style: const TextStyle(fontSize: 13.5, height: 1.5),
            ),
        ],
      ),
    );
  }
}

class _Respaldo extends ConsumerStatefulWidget {
  const _Respaldo();

  @override
  ConsumerState<_Respaldo> createState() => _RespaldoState();
}

class _RespaldoState extends ConsumerState<_Respaldo> {
  EspacioAlmacen? _espacio;
  bool? _persistido;

  @override
  void initState() {
    super.initState();
    _leerNavegador();
  }

  Future<void> _leerNavegador() async {
    final espacio = await estimarEspacio();
    final persistido = await estaPersistido();
    if (mounted) {
      setState(() {
        _espacio = espacio;
        _persistido = persistido;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = ref.watch(consultorioProvider);
    final ctrl = ref.read(consultorioProvider.notifier);
    final ahora = ref.read(servicioConsultorioProvider).reloj.ahora();
    final r = e.respaldo;
    final espacio = _espacio;
    return TarjetaConsultorio(
      icono: Icons.backup_outlined,
      titulo: 'Respaldo',
      subtitulo: 'La custodia de las historias es tuya',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            r == null
                ? 'Todavía no has descargado ningún respaldo.'
                : 'Último respaldo: ${formatoFechaHora(r.fecha)} '
                      '(${haceDias(r.fecha, ahora)})'
                      '${r.tamano > 0 ? ' · ${formatoTamano(r.tamano)}' : ''}.',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          const Text(
            'El respaldo es un archivo cifrado (.hcrespaldo) con todo el '
            'consultorio, fotos incluidas. Se abre con la frase o el código '
            'de recuperación del momento en que se descargó. Guárdalo en dos '
            'lugares distintos, por ejemplo una memoria USB y tu nube.',
            style: TextStyle(color: ColoresMarca.textoSuave, fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => respaldarYDescargar(context, ref),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Respaldar ahora'),
              ),
              OutlinedButton.icon(
                onPressed: () => restaurarDesdeArchivo(context, ref),
                icon: const Icon(Icons.restore_outlined),
                label: const Text('Restaurar…'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 300,
            child: DropdownButtonFormField<int>(
              initialValue: e.configuracion.diasRespaldo,
              decoration: const InputDecoration(
                labelText: 'Avisar si no hay respaldo en',
              ),
              items: [
                for (final d in _opciones(const [
                  1,
                  3,
                  7,
                  14,
                  30,
                ], e.configuracion.diasRespaldo))
                  DropdownMenuItem(
                    value: d,
                    child: Text(d == 1 ? '1 día' : '$d días'),
                  ),
              ],
              onChanged: (d) => d == null
                  ? null
                  : ctrl.guardarConfiguracion(
                      e.configuracion.copyWith(diasRespaldo: d),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('ESTE NAVEGADOR', style: EstilosMarca.rotulo),
          const SizedBox(height: 8),
          if (espacio != null)
            Text(
              'Espacio usado por este sitio: ${formatoTamano(espacio.usado)} '
              'de ${formatoTamano(espacio.cuota)}.',
            ),
          if (_persistido != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  _persistido!
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  size: 18,
                  color: _persistido!
                      ? ColoresMarca.estadoOk
                      : ColoresMarca.aviso,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _persistido!
                        ? 'Almacenamiento persistente concedido: el navegador '
                              'no borrará estos datos por falta de espacio.'
                        : 'El navegador podría borrar estos datos si le falta '
                              'espacio o si no usas el sitio en semanas '
                              '(Safari).',
                  ),
                ),
              ],
            ),
            if (!_persistido!)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () async {
                    await pedirPersistencia();
                    await _leerNavegador();
                  },
                  child: const Text('Pedir almacenamiento persistente'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Bitacora extends ConsumerWidget {
  const _Bitacora();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Se vuelve a leer cuando cambia el estado (respaldo, ajustes…).
    ref.watch(consultorioProvider);
    return TarjetaConsultorio(
      icono: Icons.history_outlined,
      titulo: 'Bitácora',
      subtitulo: 'Qué se hizo y cuándo, sin datos de pacientes',
      child: FutureBuilder<List<EntradaBitacora>>(
        future: ref.read(servicioConsultorioProvider).bitacora(),
        builder: (context, s) {
          final lista = s.data;
          if (lista == null) return const LinearProgressIndicator();
          if (lista.isEmpty) return const Text('Sin registros.');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entrada in lista.take(30))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          formatoFechaHora(entrada.fecha),
                          style: const TextStyle(
                            color: ColoresMarca.textoSuave,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(child: Text(entrada.accion.etiqueta)),
                    ],
                  ),
                ),
              if (lista.length > 30)
                Text(
                  '… y ${lista.length - 30} registros más.',
                  style: const TextStyle(color: ColoresMarca.textoSuave),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DialogoCambiarFrase extends ConsumerStatefulWidget {
  const _DialogoCambiarFrase();

  @override
  ConsumerState<_DialogoCambiarFrase> createState() =>
      _DialogoCambiarFraseState();
}

class _DialogoCambiarFraseState extends ConsumerState<_DialogoCambiarFrase> {
  var _actual = '';
  var _nueva = '';
  var _repetida = '';
  var _trabajando = false;
  String? _error;

  Future<void> _cambiar() async {
    setState(() {
      _trabajando = true;
      _error = null;
    });
    try {
      await ref
          .read(consultorioProvider.notifier)
          .cambiarFrase(_actual, _nueva);
      if (mounted) {
        mostrarMensaje(
          context,
          'Frase cambiada. Los respaldos anteriores se siguen abriendo con '
          'la frase que tenían.',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valida =
        _actual.isNotEmpty &&
        evaluarFrase(_nueva).admitida &&
        _nueva == _repetida;
    return AlertDialog(
      title: const TituloDialogo(
        'Cambiar la frase de acceso',
        icono: Icons.password_outlined,
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 8,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CampoTexto(
              etiqueta: 'Frase actual',
              oculto: true,
              mayusculas: TextCapitalization.none,
              alCambiar: (v) => setState(() => _actual = v),
            ),
            const SizedBox(height: 16),
            CampoTexto(
              etiqueta: 'Frase nueva',
              oculto: true,
              mayusculas: TextCapitalization.none,
              ayuda: evaluarFrase(_nueva).texto,
              alCambiar: (v) => setState(() => _nueva = v),
            ),
            const SizedBox(height: 16),
            CampoTexto(
              etiqueta: 'Repite la frase nueva',
              oculto: true,
              mayusculas: TextCapitalization.none,
              alCambiar: (v) => setState(() => _repetida = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: ColoresMarca.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _trabajando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: valida && !_trabajando ? _cambiar : null,
          child: Text(_trabajando ? 'Cambiando…' : 'Cambiar'),
        ),
      ],
    );
  }
}

class _DialogoCodigoNuevo extends ConsumerStatefulWidget {
  const _DialogoCodigoNuevo();

  @override
  ConsumerState<_DialogoCodigoNuevo> createState() =>
      _DialogoCodigoNuevoState();
}

class _DialogoCodigoNuevoState extends ConsumerState<_DialogoCodigoNuevo> {
  var _frase = '';
  var _trabajando = false;
  String? _codigo;
  String? _error;

  Future<void> _generar() async {
    setState(() {
      _trabajando = true;
      _error = null;
    });
    try {
      final c = await ref
          .read(consultorioProvider.notifier)
          .regenerarCodigo(_frase);
      if (mounted) setState(() => _codigo = c);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final codigo = _codigo;
    if (codigo != null) {
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: PanelCodigoRecuperacion(
              codigo: codigo,
              titulo: 'Tu código de recuperación nuevo',
              alConfirmar: () => Navigator.pop(context),
            ),
          ),
        ),
      );
    }
    return AlertDialog(
      title: const TituloDialogo(
        'Generar un código nuevo',
        icono: Icons.key_outlined,
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 8,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'El código anterior dejará de abrir este consultorio (los '
              'respaldos ya descargados se siguen abriendo con el código que '
              'tenían). Escribe tu frase para continuar.',
            ),
            const SizedBox(height: 16),
            CampoTexto(
              etiqueta: 'Frase de acceso',
              oculto: true,
              mayusculas: TextCapitalization.none,
              alCambiar: (v) => setState(() => _frase = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: ColoresMarca.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _trabajando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _frase.isEmpty || _trabajando ? null : _generar,
          child: Text(_trabajando ? 'Generando…' : 'Generar código nuevo'),
        ),
      ],
    );
  }
}
