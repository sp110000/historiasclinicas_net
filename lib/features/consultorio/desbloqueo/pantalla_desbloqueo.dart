import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/seguridad/fortaleza.dart';
import '../../../core/consultorio/seguridad/llavero.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/campos.dart';
import '../../../core/widgets/ilustraciones.dart';
import '../../../core/widgets/marca.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../respaldo/flujos_respaldo.dart';
import '../widgets/comunes.dart';
import 'panel_codigo.dart';

/// Lo que se ve en una pantalla del consultorio mientras no está abierto:
/// crear la frase (primera vez), el código de recuperación recién creado o
/// el desbloqueo.
class PantallaDesbloqueo extends ConsumerWidget {
  const PantallaDesbloqueo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(consultorioProvider);
    final codigo = e.codigoPendiente;
    final Widget contenido = switch (e.fase) {
      FaseConsultorio.cargando => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ),
      FaseConsultorio.sinConfigurar => const _CrearFrase(),
      FaseConsultorio.bloqueado => const _Desbloquear(),
      FaseConsultorio.desbloqueado when codigo != null =>
        PanelCodigoRecuperacion(
          codigo: codigo,
          alConfirmar: ref
              .read(consultorioProvider.notifier)
              .confirmarCodigoGuardado,
        ),
      FaseConsultorio.desbloqueado => const SizedBox.shrink(),
    };
    // Un Scaffold propio: los avisos (SnackBar) también se ven aquí.
    return Scaffold(
      backgroundColor: ColoresMarca.fondo,
      body: CuerpoConsultorio(
        anchoMaximo: 560,
        children: [
          const Center(child: NombreMarca(sufijo: ' · Consultorio')),
          if (e.fase != FaseConsultorio.cargando && codigo == null) ...[
            const SizedBox(height: 16),
            const Center(
              child: IlustracionMarca(Ilustracion.candado, alto: 104),
            ),
          ],
          const SizedBox(height: 20),
          contenido,
          if (e.fase != FaseConsultorio.cargando && codigo == null) ...[
            const SizedBox(height: 20),
            const _PieDesbloqueo(),
          ],
        ],
      ),
    );
  }
}

/// Último respaldo y acceso a la historia, que no necesita desbloquear.
class _PieDesbloqueo extends ConsumerWidget {
  const _PieDesbloqueo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(consultorioProvider).respaldo;
    ref.watch(versionIndiceProvider);
    final s = ref.read(servicioConsultorioProvider);
    final ahora = s.reloj.ahora();
    final pendientes = s.historiasPendientes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pendientes > 0) ...[
          Text(
            pendientes == 1
                ? 'Hay 1 historia guardada mientras el consultorio estaba '
                      'bloqueado: se registrará al desbloquearlo.'
                : 'Hay $pendientes historias guardadas mientras el '
                      'consultorio estaba bloqueado: se registrarán al '
                      'desbloquearlo.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: ColoresMarca.aviso),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          r == null
              ? 'Todavía no hay respaldos de este consultorio.'
              : 'Último respaldo: ${haceDias(r.fecha, ahora)} '
                    '(${formatoFecha(r.fecha)}).',
          textAlign: TextAlign.center,
          style: const TextStyle(color: ColoresMarca.textoSuave),
        ),
        const SizedBox(height: 4),
        const Text(
          'La historia clínica y la receta funcionan sin desbloquear.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ColoresMarca.textoSuave),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Ir a la historia'),
          ),
        ),
      ],
    );
  }
}

class _CrearFrase extends ConsumerStatefulWidget {
  const _CrearFrase();

  @override
  ConsumerState<_CrearFrase> createState() => _CrearFraseState();
}

class _CrearFraseState extends ConsumerState<_CrearFrase> {
  var _frase = '';
  var _repetida = '';
  var _trabajando = false;
  String? _error;

  NivelFrase get _nivel => evaluarFrase(_frase);

  bool get _valida => _nivel.admitida && _frase == _repetida;

  Future<void> _crear() async {
    setState(() {
      _trabajando = true;
      _error = null;
    });
    try {
      await ref.read(consultorioProvider.notifier).crear(_frase);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nivel = _nivel;
    final colorNivel = switch (nivel) {
      NivelFrase.corta || NivelFrase.debil => ColoresMarca.aviso,
      NivelFrase.aceptable => ColoresMarca.primario,
      NivelFrase.fuerte => ColoresMarca.estadoOk,
    };
    return TarjetaConsultorio(
      icono: Icons.lock_outline,
      titulo: 'Crea tu frase de acceso',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Los datos del consultorio (pacientes, fotos, agenda y caja) se '
            'guardan cifrados en este navegador. Esta frase los abre: elige '
            'varias palabras que solo tú conozcas.',
          ),
          const SizedBox(height: 6),
          const Text(
            'Sin la frase ni el código de recuperación, nadie puede abrir '
            'estos datos, tampoco el desarrollador de la app.',
            style: TextStyle(color: ColoresMarca.textoSuave, fontSize: 13.5),
          ),
          const SizedBox(height: 18),
          CampoTexto(
            etiqueta: 'Frase de acceso',
            oculto: true,
            mayusculas: TextCapitalization.none,
            alCambiar: (v) => setState(() => _frase = v),
          ),
          if (_frase.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  nivel.admitida ? Icons.shield_outlined : Icons.error_outline,
                  size: 18,
                  color: colorNivel,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    nivel.texto,
                    style: TextStyle(fontSize: 13, color: colorNivel),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          CampoTexto(
            etiqueta: 'Repite la frase',
            oculto: true,
            mayusculas: TextCapitalization.none,
            alCambiar: (v) => setState(() => _repetida = v),
          ),
          if (_repetida.isNotEmpty && _repetida != _frase) ...[
            const SizedBox(height: 6),
            const Text(
              'Las dos frases no coinciden.',
              style: TextStyle(fontSize: 13, color: ColoresMarca.aviso),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: ColoresMarca.error)),
          ],
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: _trabajando
                    ? null
                    : () => restaurarDesdeArchivo(context, ref),
                icon: const Icon(Icons.restore_outlined),
                label: const Text('Tengo un respaldo: restaurarlo'),
              ),
              FilledButton(
                onPressed: _valida && !_trabajando ? _crear : null,
                child: Text(_trabajando ? 'Creando…' : 'Crear frase'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Desbloquear extends ConsumerStatefulWidget {
  const _Desbloquear();

  @override
  ConsumerState<_Desbloquear> createState() => _DesbloquearState();
}

class _DesbloquearState extends ConsumerState<_Desbloquear> {
  var _frase = '';
  var _codigo = '';
  var _nueva = '';
  var _repetida = '';
  var _recuperando = false;
  var _trabajando = false;
  String? _error;

  Future<void> _ejecutar(Future<void> Function() accion) async {
    setState(() {
      _trabajando = true;
      _error = null;
    });
    try {
      await accion();
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  void _desbloquear() => _ejecutar(
    () => ref.read(consultorioProvider.notifier).desbloquear(_frase),
  );

  void _recuperar() => _ejecutar(
    () => ref.read(consultorioProvider.notifier).recuperar(_codigo, _nueva),
  );

  @override
  Widget build(BuildContext context) {
    final error = _error == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _error!,
              style: const TextStyle(color: ColoresMarca.error),
            ),
          );
    if (_recuperando) {
      final valida =
          codigoBienFormado(_codigo) &&
          evaluarFrase(_nueva).admitida &&
          _nueva == _repetida;
      return TarjetaConsultorio(
        icono: Icons.key_outlined,
        titulo: 'Recuperar con el código',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Escribe el código de recuperación de tu hoja impresa y elige '
              'una frase nueva.',
            ),
            const SizedBox(height: 16),
            CampoTexto(
              etiqueta: 'Código de recuperación',
              pista: 'XXXX-XXXX-XXXX-XXXX-XXXX-XXXX',
              mayusculas: TextCapitalization.characters,
              alCambiar: (v) => setState(() => _codigo = v),
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
            ?error,
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: _trabajando
                      ? null
                      : () => setState(() {
                          _recuperando = false;
                          _error = null;
                        }),
                  child: const Text('Volver a la frase'),
                ),
                FilledButton(
                  onPressed: valida && !_trabajando ? _recuperar : null,
                  child: Text(_trabajando ? 'Recuperando…' : 'Recuperar'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return TarjetaConsultorio(
      icono: Icons.lock_outline,
      titulo: 'El consultorio está bloqueado',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Frase de acceso'),
            onChanged: (v) => _frase = v,
            onSubmitted: (_) => _trabajando ? null : _desbloquear(),
          ),
          ?error,
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            spacing: 8,
            children: [
              TextButton(
                onPressed: _trabajando
                    ? null
                    : () => setState(() {
                        _recuperando = true;
                        _error = null;
                      }),
                child: const Text('¿Olvidaste la frase? Usar el código'),
              ),
              FilledButton(
                onPressed: _trabajando ? null : _desbloquear,
                child: Text(_trabajando ? 'Abriendo…' : 'Desbloquear'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
