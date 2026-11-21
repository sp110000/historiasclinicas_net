import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/documentos/documento.dart';
import '../../../core/consultorio/documentos/plantillas.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/models/mapa.dart';
import '../../../core/consultorio/modelos/registro_receta.dart';
import '../../../core/integridad/cadena_hash.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';
import 'firma_autorizacion.dart';

/// «Autorización de datos firmada el …» o el aviso de que falta. Sin
/// autorización no se bloquea la atención clínica (pregunta 12; VERIFICAR).
class LineaAutorizacion extends ConsumerWidget {
  const LineaAutorizacion({super.key, required this.ficha});

  final FichaPaciente ficha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ficha.autorizacionDatosId;
    final d = id == null
        ? null
        : ref.read(servicioConsultorioProvider).documentos.documento(id);
    if (d != null && d.vigente) {
      return EtiquetaEstado(
        icono: Icons.verified_user_outlined,
        texto:
            'Autorización de datos firmada el ${formatoFecha(d.fechaHora)} · '
            '${d.numero}',
        color: ColoresMarca.estadoOk,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const EtiquetaEstado(
          icono: Icons.privacy_tip_outlined,
          texto: 'Sin autorización de tratamiento de datos',
          color: ColoresMarca.aviso,
        ),
        TextButton(
          onPressed: () => pedirAutorizacionDatos(context, ficha: ficha),
          child: const Text('Pedir autorización'),
        ),
      ],
    );
  }
}

BoxDecoration get _decoracion => BoxDecoration(
  color: Colors.white,
  borderRadius: RadiosMarca.tarjeta,
  border: Border.all(color: ColoresMarca.borde),
);

List<Widget> _botonesPdf(
  WidgetRef ref, {
  required Future<Uint8List?> Function() leer,
  required String nombre,
}) => [
  OutlinedButton.icon(
    onPressed: () async {
      final b = await leer();
      if (b != null) await ref.read(verPdfProvider)(b, nombre);
    },
    icon: const Icon(Icons.picture_as_pdf_outlined),
    label: const Text('Ver PDF'),
  ),
  OutlinedButton.icon(
    onPressed: () async {
      final b = await leer();
      if (b != null) ref.read(descargarPdfProvider)(b, nombre);
    },
    icon: const Icon(Icons.download_outlined),
    label: const Text('Descargar PDF'),
  ),
];

/// Un documento firmado en la línea de tiempo.
class TarjetaDocumento extends ConsumerWidget {
  const TarjetaDocumento({super.key, required this.documento});

  final DocumentoConsultorio documento;

  Future<void> _cambiar(
    BuildContext context,
    WidgetRef ref,
    EstadoDocumento estado,
  ) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoMotivo(documento: documento, estado: estado),
    );
    if (motivo == null) return;
    try {
      await ref
          .read(servicioConsultorioProvider)
          .documentos
          .cambiarEstado(documento.id, estado, motivo: motivo);
      ref.read(versionIndiceProvider.notifier).cambio();
    } catch (e) {
      if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = documento;
    final nombre = nombreArchivoDocumento(
      switch (d.tipo) {
        TipoPlantilla.autorizacionDatos => 'Autorizacion_datos',
        TipoPlantilla.politicaPrivacidad => 'Politica_datos',
      },
      apellido: d.datos.mapa('paciente').texto('nombre').split(',').first,
      numero: d.numero,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _decoracion,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatoFecha(d.fechaHora)} · ${d.titulo}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            '${d.numero} · versión ${d.versionPlantilla} de la plantilla · '
            'huella ${huella(d.hash)}',
            style: const TextStyle(color: ColoresMarca.textoSuave),
          ),
          const SizedBox(height: 8),
          EtiquetaEstado(
            icono: d.vigente ? Icons.verified_outlined : Icons.block,
            texto: d.vigente
                ? d.estado.etiqueta
                : '${d.estado.etiqueta} el '
                      '${formatoFecha(d.cambioEstado!)}: ${d.motivoEstado}',
            color: d.vigente ? ColoresMarca.estadoOk : ColoresMarca.error,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (d.tienePdf)
                ..._botonesPdf(
                  ref,
                  leer: () => ref
                      .read(servicioConsultorioProvider)
                      .documentos
                      .pdfDe(d.id),
                  nombre: nombre,
                ),
              if (d.vigente) ...[
                TextButton(
                  onPressed: () =>
                      _cambiar(context, ref, EstadoDocumento.revocado),
                  child: const Text('Registrar revocación'),
                ),
                TextButton(
                  onPressed: () =>
                      _cambiar(context, ref, EstadoDocumento.anulado),
                  child: const Text('Anular'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DialogoMotivo extends StatefulWidget {
  const _DialogoMotivo({required this.documento, required this.estado});

  final DocumentoConsultorio documento;
  final EstadoDocumento estado;

  @override
  State<_DialogoMotivo> createState() => _DialogoMotivoState();
}

class _DialogoMotivoState extends State<_DialogoMotivo> {
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final revocar = widget.estado == EstadoDocumento.revocado;
    return AlertDialog(
      title: TituloDialogo(
        revocar
            ? 'Revocación de ${widget.documento.numero}'
            : 'Anular ${widget.documento.numero}',
        icono: Icons.block,
        color: ColoresMarca.error,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              revocar
                  ? 'El paciente retira su autorización. El documento no se '
                        'borra: queda con la fecha y el motivo, y la ficha '
                        'queda sin autorización vigente.'
                  : 'Anula un documento hecho por error. No se borra ni se '
                        'reutiliza su número: queda con la fecha y el motivo.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _motivo,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Motivo'),
            ),
          ],
        ),
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: ColoresMarca.error),
          onPressed: _motivo.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _motivo.text.trim()),
          child: Text(revocar ? 'Registrar revocación' : 'Anular'),
        ),
      ],
    );
  }
}

/// Una receta emitida con el consultorio, con su PDF exacto.
class TarjetaReceta extends ConsumerWidget {
  const TarjetaReceta({super.key, required this.receta});

  final RegistroReceta receta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = receta;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _decoracion,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [formatoFecha(r.fecha), 'Receta', ?r.numero].join(' · '),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          for (final i in r.items)
            Text(i, style: const TextStyle(color: ColoresMarca.textoSuave)),
          if (r.items.isEmpty && r.indicaciones.isNotEmpty)
            Text(
              r.indicaciones,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ColoresMarca.textoSuave),
            ),
          if (r.tienePdf) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _botonesPdf(
                ref,
                leer: () => ref
                    .read(servicioConsultorioProvider)
                    .indice
                    .pdfReceta(r.id),
                nombre: r.nombreArchivo.isEmpty
                    ? 'receta.pdf'
                    : r.nombreArchivo,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
