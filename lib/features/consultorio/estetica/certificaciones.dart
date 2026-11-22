import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/procedimientos/certificacion.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/campos.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../../historia/widgets/dialogos.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';

/// Ajustes → Certificaciones por técnica (pregunta 36): técnica o familia,
/// entidad, fecha, vigencia y soporte cifrado. Sin certificación vigente la
/// sesión avisa y lo registra, pero no bloquea.
class TarjetaCertificaciones extends ConsumerWidget {
  const TarjetaCertificaciones({super.key});

  Future<void> _retirar(
    BuildContext context,
    WidgetRef ref,
    Certificacion c,
  ) async {
    final si = await confirmar(
      context,
      titulo: '¿Retirar la certificación?',
      texto:
          '«${c.familia}» de ${c.entidad} deja de contar como vigente. No se '
          'borra: queda en la lista y en la bitácora.',
      aceptar: 'Retirar',
      icono: Icons.remove_circle_outline,
    );
    if (!si) return;
    await ref
        .read(servicioConsultorioProvider)
        .procedimientos
        .retirarCertificacion(c.id);
    ref.read(versionIndiceProvider.notifier).cambio();
  }

  Future<void> _soporte(WidgetRef ref, Certificacion c) async {
    final b = await ref
        .read(servicioConsultorioProvider)
        .procedimientos
        .soporteCertificacion(c.id);
    if (b == null) return;
    ref.read(descargarArchivoProvider)(
      b,
      'Certificacion_${c.fecha.year}.${c.soporte ?? 'pdf'}',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(versionIndiceProvider);
    final servicio = ref.read(servicioConsultorioProvider);
    final hoy = servicio.reloj.ahora();
    final lista = servicio.procedimientos.certificaciones;
    return TarjetaConsultorio(
      icono: Icons.workspace_premium_outlined,
      titulo: 'Certificaciones por técnica',
      subtitulo: 'Con su vigencia y su soporte',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'El Proyecto de Ley 187 de 2026 (no es ley, VERIFICAR) pide '
            'certificación por familia de técnicas. Mientras no sea ley, usar '
            'una técnica sin certificación vigente avisa y queda en la '
            'bitácora, sin bloquear.',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
          const SizedBox(height: 8),
          if (lista.isEmpty)
            const Text(
              'Ninguna registrada.',
              style: TextStyle(color: ColoresMarca.textoSuave),
            ),
          for (final c in lista)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${c.familia} · ${c.entidad}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  EtiquetaEstado(
                    icono: c.vigenteEn(hoy)
                        ? Icons.verified_outlined
                        : Icons.event_busy_outlined,
                    texto: c.retiradaEn != null
                        ? 'Retirada el ${formatoFecha(c.retiradaEn!)}'
                        : c.vigenteEn(hoy)
                        ? 'Vigente desde el ${formatoFecha(c.fecha)}'
                              '${c.vigenteHasta == null ? '' : ' hasta el ${formatoFecha(c.vigenteHasta!)}'}'
                        : 'No vigente (${formatoFecha(c.fecha)}'
                              '${c.vigenteHasta == null ? '' : ' a ${formatoFecha(c.vigenteHasta!)}'})',
                    color: c.vigenteEn(hoy)
                        ? ColoresMarca.estadoOk
                        : ColoresMarca.textoSuave,
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (c.soporte != null)
                        TextButton.icon(
                          onPressed: () => _soporte(ref, c),
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Descargar soporte'),
                        ),
                      if (c.retiradaEn == null)
                        TextButton(
                          onPressed: () => _retirar(context, ref, c),
                          child: const Text('Retirar'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const _DialogoCertificacion(),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Agregar certificación'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogoCertificacion extends ConsumerStatefulWidget {
  const _DialogoCertificacion();

  @override
  ConsumerState<_DialogoCertificacion> createState() =>
      _DialogoCertificacionState();
}

class _DialogoCertificacionState extends ConsumerState<_DialogoCertificacion> {
  late var _familia = claveFamilia(
    ref
            .read(servicioConsultorioProvider)
            .procedimientos
            .plantillas
            .firstOrNull
            ?.ultima
            .definicion
            .familia ??
        '',
  ).let((s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1));
  var _entidad = '';
  DateTime? _fecha;
  DateTime? _hasta;
  Uint8List? _soporte;
  String? _tipoSoporte;
  String? _nombreSoporte;
  String? _error;
  var _guardando = false;

  Future<void> _adjuntarPdf() async {
    final a = await ref.read(elegirPdfsProvider)();
    if (a.isEmpty) return;
    setState(() {
      _soporte = a.first.bytes;
      _tipoSoporte = 'pdf';
      _nombreSoporte = a.first.nombre;
    });
  }

  Future<void> _adjuntarFoto() async {
    final a = await ref.read(elegirFotoProvider)();
    if (a == null) return;
    setState(() {
      _soporte = a.bytes;
      _tipoSoporte = 'jpg';
      _nombreSoporte = a.nombre;
    });
  }

  Future<void> _guardar() async {
    if (_fecha == null) {
      setState(() => _error = 'Escribe la fecha de la certificación.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    final s = ref.read(servicioConsultorioProvider);
    try {
      await s.procedimientos.guardarCertificacion(
        Certificacion(
          id: '',
          familia: _familia.trim(),
          entidad: _entidad.trim(),
          fecha: _fecha!,
          vigenteHasta: _hasta,
          creado: s.reloj.ahora(),
        ),
        soporte: _soporte,
        tipoSoporte: _tipoSoporte,
      );
      ref.read(versionIndiceProvider.notifier).cambio();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _guardando = false;
        _error = mensajeDeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const TituloDialogo(
      'Certificación',
      icono: Icons.workspace_premium_outlined,
    ),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CampoTexto(
              etiqueta: 'Técnica o familia de técnicas',
              valorInicial: _familia,
              alCambiar: (v) => _familia = v,
            ),
            const SizedBox(height: 12),
            CampoTexto(
              etiqueta: 'Entidad que certifica',
              alCambiar: (v) => _entidad = v,
            ),
            const SizedBox(height: 12),
            RejillaCampos(
              anchoMinimo: 180,
              children: [
                CampoFecha(
                  etiqueta: 'Fecha de la certificación',
                  valor: _fecha,
                  primera: DateTime(1980),
                  ultima: DateTime(2100),
                  alCambiar: (f) => _fecha = f,
                ),
                CampoFecha(
                  etiqueta: 'Vigente hasta (opcional)',
                  valor: _hasta,
                  primera: DateTime(1980),
                  ultima: DateTime(2100),
                  alCambiar: (f) => _hasta = f,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _adjuntarPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Adjuntar PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: _adjuntarFoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Adjuntar foto'),
                ),
                if (_nombreSoporte != null)
                  Text(
                    _nombreSoporte!,
                    style: const TextStyle(color: ColoresMarca.textoSuave),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: ColoresMarca.error)),
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
        onPressed: _guardando ? null : _guardar,
        child: const Text('Guardar'),
      ),
    ],
  );
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
