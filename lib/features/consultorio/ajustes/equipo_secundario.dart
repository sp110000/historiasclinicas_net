import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/consultorio/modelos/foto.dart';
import '../../../core/consultorio/modelos/medicion.dart';
import '../../../core/consultorio/documentos/documento.dart';
import '../../../core/utils/fechas.dart';
import '../../historia/widgets/dialogos.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';

/// Ajustes → Equipo secundario (pregunta 3): el celular o la tableta con
/// que se toman fotos o se firman documentos, configurado restaurando un
/// respaldo del principal. Lo hecho ahí viaja al principal en un paquete
/// cifrado que se combina sin duplicar.
class TarjetaEquipoSecundario extends ConsumerStatefulWidget {
  const TarjetaEquipoSecundario({super.key});

  @override
  ConsumerState<TarjetaEquipoSecundario> createState() =>
      _TarjetaEquipoSecundarioState();
}

class _TarjetaEquipoSecundarioState
    extends ConsumerState<TarjetaEquipoSecundario> {
  bool? _secundario;
  DateTime? _restaurado;
  var _ocupado = false;

  @override
  void initState() {
    super.initState();
    _leer();
  }

  Future<void> _leer() async {
    final s = ref.read(servicioConsultorioProvider);
    final sec = await s.esEquipoSecundario();
    final r = await s.restauradoEn();
    if (mounted) {
      setState(() {
        _secundario = sec;
        _restaurado = r;
      });
    }
  }

  Future<void> _cambiar(bool v) async {
    await ref.read(servicioConsultorioProvider).cambiarEquipoSecundario(v);
    await _leer();
  }

  Future<void> _exportar() async {
    setState(() => _ocupado = true);
    try {
      final p = await ref
          .read(servicioConsultorioProvider)
          .exportarPaqueteSecundario();
      ref.read(descargarArchivoProvider)(p.bytes, p.nombre);
      if (mounted) {
        mostrarMensaje(
          context,
          'Paquete descargado: ${p.nombre}. Llévalo al equipo principal y '
          'combínalo allí.',
        );
      }
    } catch (e) {
      if (mounted) mostrarMensaje(context, mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _combinar() async {
    final archivo = await ref.read(elegirPaqueteProvider)();
    if (archivo == null || !mounted) return;
    setState(() => _ocupado = true);
    final s = ref.read(servicioConsultorioProvider);
    try {
      final p = await s.verificarPaqueteSecundario(archivo.bytes);
      if (!mounted) return;
      final n = p.porColeccion;
      final si = await confirmar(
        context,
        titulo: '¿Combinar el paquete?',
        texto:
            'Paquete del ${formatoFechaHora(p.creado)}: ${_resumen(n)}. Se '
            'agrega lo que falta; lo que ya está no se duplica ni se '
            'reemplaza.',
        aceptar: 'Combinar',
        icono: Icons.merge_outlined,
      );
      if (!si) return;
      final r = await s.combinarPaqueteSecundario(p);
      ref.read(versionIndiceProvider.notifier).cambio();
      if (mounted) {
        mostrarMensaje(
          context,
          r.totalAgregados == 0
              ? 'Todo lo del paquete ya estaba en este equipo.'
              : 'Paquete combinado: ${_resumen(r.agregados)}'
                    '${r.fichasUnidas == 0 ? '' : ' (${r.fichasUnidas} unidas a una ficha de aquí)'}'
                    '${r.yaEstaban == 0 ? '' : '; ${r.yaEstaban} ya estaban'}.',
        );
      }
    } on FormatException catch (e) {
      if (mounted) mostrarMensaje(context, e.message);
    } catch (e) {
      if (mounted) mostrarMensaje(context, mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  static String _resumen(Map<String, int> n) {
    String c(String coleccion, String uno, String varios) {
      final k = n[coleccion] ?? 0;
      return k == 0 ? '' : (k == 1 ? '1 $uno' : '$k $varios');
    }

    final partes = [
      c(FichaPaciente.coleccion, 'ficha', 'fichas'),
      c(Medicion.coleccion, 'medición', 'mediciones'),
      c(Foto.coleccion, 'foto', 'fotos'),
      c(DocumentoConsultorio.coleccion, 'documento', 'documentos'),
    ].where((p) => p.isNotEmpty).toList();
    return partes.isEmpty ? 'nada nuevo' : partes.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final sec = _secundario;
    return TarjetaConsultorio(
      icono: Icons.devices_other_outlined,
      titulo: 'Equipo secundario',
      subtitulo: 'Fotos y firmas en el celular, combinadas en el portátil',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Para usar un celular o una tableta como equipo secundario, '
            'restaura en él un respaldo de este consultorio (así comparte la '
            'llave) y márcalo como secundario. Lo que hagas allí (fichas '
            'nuevas, mediciones, fotos y documentos firmados) vuelve al '
            'principal en un paquete cifrado que se combina sin duplicar. Sus '
            'documentos llevan una serie propia («CIM-S000001»).',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
          const SizedBox(height: 8),
          if (sec == null)
            const LinearProgressIndicator()
          else ...[
            SwitchListTile(
              value: sec,
              onChanged: _ocupado ? null : _cambiar,
              contentPadding: EdgeInsets.zero,
              title: const Text('Este equipo es el secundario'),
              subtitle: Text(
                _restaurado == null
                    ? 'Este equipo no se configuró desde un respaldo.'
                    : 'Configurado con el respaldo restaurado el '
                          '${formatoFechaHora(_restaurado!)}.',
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (sec)
                  FilledButton.icon(
                    onPressed: _ocupado || _restaurado == null
                        ? null
                        : _exportar,
                    icon: const Icon(Icons.outbox_outlined),
                    label: const Text('Exportar paquete de este equipo'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _ocupado ? null : _combinar,
                    icon: const Icon(Icons.merge_outlined),
                    label: const Text('Combinar un paquete'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
