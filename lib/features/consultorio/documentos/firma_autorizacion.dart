import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/documentos/documento.dart';
import '../../../core/consultorio/documentos/plantillas.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/pais/pais_provider.dart';
import '../../../core/widgets/lienzo_firma.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../../medico/medico_provider.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';

/// Exporta la firma dibujada a PNG. Las pruebas lo sustituyen (en la VM no
/// hay motor para rasterizar).
final exportarFirmaProvider =
    Provider<Future<Uint8List?> Function(ControladorFirma)>(
      (ref) =>
          (c) => c.exportarPng(),
    );

/// Pide la autorización de tratamiento de datos de [ficha]: el paciente lee
/// el texto de la plantilla vigente, lo confirma y firma en pantalla. Al
/// firmar se descarga el PDF y queda en la ficha.
Future<void> pedirAutorizacionDatos(
  BuildContext context, {
  required FichaPaciente ficha,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _DialogoAutorizacion(ficha: ficha),
);

class _DialogoAutorizacion extends ConsumerStatefulWidget {
  const _DialogoAutorizacion({required this.ficha});

  final FichaPaciente ficha;

  @override
  ConsumerState<_DialogoAutorizacion> createState() =>
      _DialogoAutorizacionState();
}

class _DialogoAutorizacionState extends ConsumerState<_DialogoAutorizacion> {
  final _firma = ControladorFirma();
  var _leido = false;
  var _incluirFirma = true;
  var _incluirSello = true;
  var _firmando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _firma.addListener(_alCambiarFirma);
  }

  void _alCambiarFirma() => setState(() {});

  @override
  void dispose() {
    _firma
      ..removeListener(_alCambiarFirma)
      ..dispose();
    super.dispose();
  }

  Future<void> _firmar() async {
    setState(() {
      _firmando = true;
      _error = null;
    });
    try {
      final png = await ref.read(exportarFirmaProvider)(_firma);
      if (png == null) throw StateError('Falta la firma del paciente.');
      final r = await ref
          .read(servicioConsultorioProvider)
          .documentos
          .firmarAutorizacion(
            ficha: widget.ficha,
            firmaPng: png,
            medico: ref.read(medicoProvider),
            pais: ref.read(paisProvider),
            incluirFirma: _incluirFirma,
            incluirSello: _incluirSello,
          );
      final numero = r.documento.numero;
      ref.read(descargarPdfProvider)(
        r.pdf,
        nombreArchivoDocumento(
          'Autorizacion_datos',
          apellido: widget.ficha.primerApellido,
          numero: numero,
        ),
      );
      ref.read(versionIndiceProvider.notifier).cambio();
      if (!mounted) return;
      final mensajero = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            'Autorización firmada ($numero). El PDF se descargó y quedó en '
            'la ficha.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _firmando = false;
          _error = mensajeDeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.read(servicioConsultorioProvider);
    final plantilla = s.documentos.plantilla(TipoPlantilla.autorizacionDatos);
    final version = plantilla.vigente;
    final medico = ref.watch(medicoProvider);
    final movil = MediaQuery.sizeOf(context).width < 600;

    final List<Widget> contenido;
    if (version == null) {
      contenido = [
        const Text(
          'La plantilla de autorización de tratamiento de datos está en '
          'borrador. Revísala con tu abogado (VERIFICAR) y apruébala en '
          'Ajustes → Plantillas antes de usarla.',
        ),
      ];
    } else if (!medico.configurado) {
      contenido = [
        const Text(
          'Completa tus datos de médico (nombre, documento, dirección y '
          'contacto): la autorización los lleva como responsable del '
          'tratamiento.',
        ),
      ];
    } else {
      final texto = rellenarPlantilla(
        version.cuerpo,
        s.documentos.valores(
          medico,
          ficha: widget.ficha,
          fecha: s.reloj.ahora(),
        ),
      );
      contenido = [
        Text(
          '${widget.ficha.nombreCompleto} · ${widget.ficha.documentoTexto}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          'Plantilla versión ${version.version}',
          style: const TextStyle(fontSize: 13, color: ColoresMarca.textoSuave),
        ),
        const SizedBox(height: 10),
        Container(
          constraints: BoxConstraints(maxHeight: movil ? 260 : 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ColoresMarca.fondo,
            borderRadius: RadiosMarca.control,
            border: Border.all(color: ColoresMarca.borde),
          ),
          child: SingleChildScrollView(
            child: Text(texto, style: const TextStyle(height: 1.45)),
          ),
        ),
        CheckboxListTile(
          value: _leido,
          onChanged: (v) => setState(() => _leido = v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            'El paciente leyó el documento y resolvió sus dudas',
          ),
        ),
        const SizedBox(height: 4),
        const Text('FIRMA DEL PACIENTE', style: EstilosMarca.rotulo),
        const SizedBox(height: 6),
        LienzoFirma(controlador: _firma, alto: movil ? 160 : 200),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _firma.vacio ? null : _firma.limpiar,
            icon: const Icon(Icons.refresh),
            label: const Text('Borrar firma'),
          ),
        ),
        Wrap(
          spacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Médico: ${medico.nombre.trim()}',
              style: const TextStyle(color: ColoresMarca.textoSuave),
            ),
            _Interruptor(
              texto: 'Incluir mi firma',
              valor: _incluirFirma,
              alCambiar: (v) => setState(() => _incluirFirma = v),
            ),
            _Interruptor(
              texto: 'Incluir mi sello',
              valor: _incluirSello,
              alCambiar: (v) => setState(() => _incluirSello = v),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: ColoresMarca.error)),
        ],
      ];
    }

    final puedeFirmar =
        version != null &&
        medico.configurado &&
        _leido &&
        !_firma.vacio &&
        !_firmando;
    return AlertDialog(
      title: TituloDialogo(
        version?.titulo ?? TipoPlantilla.autorizacionDatos.etiqueta,
        icono: Icons.privacy_tip_outlined,
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: movil ? 8 : 40,
        vertical: 16,
      ),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: contenido,
          ),
        ),
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: _firmando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        if (version == null)
          FilledButton(
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.pop(context);
              router.go('/ajustes');
            },
            child: const Text('Ir a Ajustes'),
          )
        else if (!medico.configurado)
          FilledButton(
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.pop(context);
              router.push('/medico');
            },
            child: const Text('Datos del médico'),
          )
        else
          FilledButton.icon(
            onPressed: puedeFirmar ? _firmar : null,
            icon: const Icon(Icons.draw_outlined),
            label: const Text('Firmar y descargar PDF'),
          ),
      ],
    );
  }
}

class _Interruptor extends StatelessWidget {
  const _Interruptor({
    required this.texto,
    required this.valor,
    required this.alCambiar,
  });

  final String texto;
  final bool valor;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(value: valor, onChanged: alCambiar),
        const SizedBox(width: 4),
        Flexible(child: Text(texto)),
      ],
    );
  }
}
