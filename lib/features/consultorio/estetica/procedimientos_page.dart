import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/pais/perfil_pais.dart' show Opcion;
import '../../../core/widgets/campos.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';
import 'ajustes_procedimientos.dart';

/// Procedimientos (en el menú, debajo de la historia): las plantillas de
/// cada procedimiento con sus versiones, y agregar uno nuevo.
class ProcedimientosPage extends ConsumerWidget {
  const ProcedimientosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movil = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Procedimientos',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (movil)
            IconButton(
              tooltip: 'Agregar un procedimiento',
              onPressed: () => agregarProcedimiento(context, ref),
              icon: const Icon(Icons.add),
            )
          else
            FilledButton.icon(
              onPressed: () => agregarProcedimiento(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Agregar un procedimiento'),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: const CuerpoConsultorio(children: [TarjetaProcedimientos()]),
    );
  }
}

/// Pide el nombre y lo que usa el procedimiento, lo crea en borrador y
/// abre su editor.
Future<void> agregarProcedimiento(BuildContext context, WidgetRef ref) async {
  final id = await showDialog<String>(
    context: context,
    builder: (_) => const _DialogoNuevoProcedimiento(),
  );
  if (id == null || !context.mounted) return;
  ref.read(versionIndiceProvider.notifier).cambio();
  context.go('/procedimientos/$id');
}

class _DialogoNuevoProcedimiento extends ConsumerStatefulWidget {
  const _DialogoNuevoProcedimiento();

  @override
  ConsumerState<_DialogoNuevoProcedimiento> createState() =>
      _DialogoNuevoProcedimientoState();
}

class _DialogoNuevoProcedimientoState
    extends ConsumerState<_DialogoNuevoProcedimiento> {
  static const _enBlanco = '';

  var _nombre = '';
  var _familia = '';
  var _copiarDe = _enBlanco;
  var _anestesico = false;
  var _solucion = false;
  var _guardando = false;
  String? _error;

  void _partirDe(String id) {
    final p = ref
        .read(servicioConsultorioProvider)
        .procedimientos
        .plantilla(id);
    setState(() {
      _copiarDe = id;
      _error = null;
      if (p != null) {
        final d = p.ultima.definicion;
        _anestesico = d.usaAnestesico;
        _solucion = d.usaSolucion;
        if (_familia.trim().isEmpty) _familia = d.familia;
      }
    });
  }

  Future<void> _crear() async {
    setState(() => _guardando = true);
    try {
      final p = await ref
          .read(servicioConsultorioProvider)
          .procedimientos
          .crearPlantilla(
            nombre: _nombre,
            familia: _familia,
            usaAnestesico: _anestesico,
            usaSolucion: _solucion,
            copiarDe: _copiarDe == _enBlanco ? null : _copiarDe,
          );
      if (mounted) Navigator.pop(context, p.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = mensajeDeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plantillas = ref
        .read(servicioConsultorioProvider)
        .procedimientos
        .plantillas;
    return AlertDialog(
      title: const TituloDialogo(
        'Procedimiento nuevo',
        icono: Icons.spa_outlined,
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampoTexto(
                etiqueta: 'Nombre',
                requerido: true,
                pista: 'Por ejemplo, Mesoterapia',
                alCambiar: (v) => setState(() {
                  _nombre = v;
                  _error = null;
                }),
              ),
              const SizedBox(height: 10),
              CampoTexto(
                key: ValueKey('familia$_copiarDe'),
                etiqueta: 'Familia de técnicas (para las certificaciones)',
                valorInicial: _familia,
                alCambiar: (v) => _familia = v,
              ),
              const SizedBox(height: 10),
              CampoDesplegable(
                etiqueta: 'Partir de',
                opciones: [
                  const Opcion(_enBlanco, 'En blanco'),
                  for (final p in plantillas)
                    Opcion(p.id, 'Copia de «${p.nombre}»'),
                ],
                valor: _copiarDe,
                alCambiar: _partirDe,
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _anestesico,
                onChanged: (v) => setState(() => _anestesico = v),
                title: const Text('Usa anestésico local'),
                subtitle: const Text(
                  'La sesión pide el peso y calcula la dosis en mg/kg.',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _solucion,
                onChanged: (v) => setState(() => _solucion = v),
                title: const Text('Se infiltra una solución por zona'),
                subtitle: const Text(
                  'Componentes, volumen por zona y sus máximos.',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Queda en borrador: escribe la valoración, el protocolo y el '
                'consentimiento, y apruébalo para usarlo.',
                style: TextStyle(color: ColoresMarca.textoSuave),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: ColoresMarca.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando || _nombre.trim().isEmpty ? null : _crear,
          child: const Text('Crear y editar'),
        ),
      ],
    );
  }
}
