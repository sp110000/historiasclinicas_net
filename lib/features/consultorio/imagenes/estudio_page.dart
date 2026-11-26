import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/fotos/procesar_foto.dart';
import '../../../core/consultorio/imagenes/estudio_imagen.dart';
import '../../../core/pais/pais_provider.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/campos.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../../historia/widgets/avisos.dart';
import '../../historia/widgets/dialogos.dart';
import '../../medico/medico_provider.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/campo_diagnostico.dart';
import '../widgets/comunes.dart';

/// El informe ecográfico: en borrador se edita (se guarda solo); cerrado
/// se ve, se descarga, se imprime o se anula.
class EstudioPage extends ConsumerStatefulWidget {
  const EstudioPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<EstudioPage> createState() => _EstudioPageState();
}

class _EstudioPageState extends ConsumerState<EstudioPage> {
  EstudioImagen? _e;
  Timer? _espera;
  var _ocupado = false;

  @override
  void initState() {
    super.initState();
    _e = ref.read(servicioConsultorioProvider).imagenes.estudio(widget.id);
  }

  @override
  void dispose() {
    if (_espera?.isActive ?? false) {
      _espera!.cancel();
      unawaited(_guardar());
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    final e = _e;
    if (e == null || !e.borrador) return;
    try {
      _e = await ref.read(servicioConsultorioProvider).imagenes.guardar(e);
    } catch (_) {
      // Bloqueado o cerrado mientras tanto: no hay nada que guardar.
    }
  }

  /// Cambia el borrador en pantalla y lo guarda al dejar de escribir.
  void _cambiar(
    EstudioImagen Function(EstudioImagen) f, {
    bool redibujar = true,
  }) {
    final e = _e;
    if (e == null || !e.borrador) return;
    if (redibujar) {
      setState(() => _e = f(e));
    } else {
      _e = f(e);
    }
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 500), _guardar);
  }

  Future<void> _guardarYa() async {
    _espera?.cancel();
    await _guardar();
  }

  Future<void> _agregarImagen() async {
    final archivo = await ref.read(elegirImagenProvider)();
    if (archivo == null || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await _guardarYa();
      final p = await procesarFoto(archivo.bytes);
      final e = await ref
          .read(servicioConsultorioProvider)
          .imagenes
          .agregarImagen(widget.id, p);
      if (mounted) setState(() => _e = e);
    } catch (e) {
      if (mounted) mostrarMensaje(context, mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _quitarImagen(ImagenEstudio i) async {
    await _guardarYa();
    try {
      final e = await ref
          .read(servicioConsultorioProvider)
          .imagenes
          .quitarImagen(widget.id, i.id);
      if (mounted) setState(() => _e = e);
    } catch (e) {
      if (mounted) mostrarMensaje(context, mensajeDeError(e));
    }
  }

  Future<void> _vistaPrevia() async {
    final e = _e!;
    setState(() => _ocupado = true);
    try {
      final s = ref.read(servicioConsultorioProvider);
      final pdf = await s.imagenes.vistaPrevia(
        e,
        medico: ref.read(medicoProvider),
        pais: ref.read(paisProvider),
      );
      await ref.read(verPdfProvider)(pdf, s.imagenes.nombreArchivo(e));
    } catch (e) {
      if (mounted) mostrarMensaje(context, mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _cerrar() async {
    final ok = await confirmar(
      context,
      titulo: '¿Cerrar el informe?',
      texto:
          'Recibe su número y su PDF firmado, y ya no se puede cambiar. Si '
          'hay un error, se anula con su motivo y se hace otro.',
      aceptar: 'Cerrar y descargar',
      icono: Icons.verified_outlined,
    );
    if (!ok || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await _guardarYa();
      final s = ref.read(servicioConsultorioProvider);
      final (e, pdf) = await s.imagenes.cerrar(
        widget.id,
        medico: ref.read(medicoProvider),
        pais: ref.read(paisProvider),
      );
      ref.read(descargarPdfProvider)(pdf, s.imagenes.nombreArchivo(e));
      ref.read(versionIndiceProvider.notifier).cambio();
      if (!mounted) return;
      setState(() => _e = e);
      mostrarMensaje(context, 'Informe ${e.numero} cerrado y descargado.');
    } catch (e) {
      if (mounted) mostrarMensaje(context, mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<Uint8List?> _pdf() async {
    final pdf = await ref
        .read(servicioConsultorioProvider)
        .imagenes
        .pdfDe(widget.id);
    if (pdf == null && mounted) {
      mostrarMensaje(context, 'No se encontró el PDF del informe.');
    }
    return pdf;
  }

  Future<void> _descargar() async {
    final pdf = await _pdf();
    if (pdf == null) return;
    final s = ref.read(servicioConsultorioProvider);
    ref.read(descargarPdfProvider)(pdf, s.imagenes.nombreArchivo(_e!));
  }

  Future<void> _imprimir() async {
    final pdf = await _pdf();
    if (pdf == null) return;
    final s = ref.read(servicioConsultorioProvider);
    await ref.read(verPdfProvider)(pdf, s.imagenes.nombreArchivo(_e!));
  }

  Future<void> _anular() async {
    final motivo = await pedirTexto(
      context,
      titulo: 'Anular el informe ${_e!.numero}',
      etiqueta: 'Motivo de la anulación',
      aceptar: 'Anular',
    );
    if (motivo == null || !mounted) return;
    try {
      final e = await ref
          .read(servicioConsultorioProvider)
          .imagenes
          .anular(widget.id, motivo: motivo);
      ref.read(versionIndiceProvider.notifier).cambio();
      if (mounted) setState(() => _e = e);
    } catch (e) {
      if (mounted) mostrarMensaje(context, mensajeDeError(e));
    }
  }

  Future<void> _borrar() async {
    final ok = await confirmar(
      context,
      titulo: '¿Borrar el borrador?',
      texto: 'Se borran el informe y sus imágenes. No tiene número todavía.',
      aceptar: 'Borrar',
      icono: Icons.delete_outline,
      peligro: true,
    );
    if (!ok || !mounted) return;
    _espera?.cancel();
    await ref
        .read(servicioConsultorioProvider)
        .imagenes
        .borrarBorrador(widget.id);
    ref.read(versionIndiceProvider.notifier).cambio();
    if (mounted) context.go('/imagenes');
  }

  Future<void> _agregarSeccion() async {
    final t = await pedirTexto(
      context,
      titulo: 'Sección nueva',
      etiqueta: 'Órgano o región',
      aceptar: 'Agregar',
    );
    if (t == null || t.trim().isEmpty) return;
    _cambiar(
      (e) => e.copyWith(
        secciones: [
          ...e.secciones,
          SeccionEstudio(titulo: t.trim()),
        ],
      ),
    );
  }

  Future<void> _agregarMedida() async {
    final m = await showDialog<MedidaEstudio>(
      context: context,
      builder: (_) => const _DialogoMedida(),
    );
    if (m == null) return;
    _cambiar((e) => e.copyWith(medidas: [...e.medidas, m]));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(versionIndiceProvider);
    final e = _e;
    final s = ref.read(servicioConsultorioProvider);
    if (e == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Informe ecográfico')),
        body: CuerpoConsultorio(
          children: [
            const Text('No se encontró el estudio.'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: () => context.go('/imagenes'),
                child: const Text('Ver Imágenes'),
              ),
            ),
          ],
        ),
      );
    }
    final ficha = s.indice.fichaActiva(e.pacienteId);
    final movil = MediaQuery.sizeOf(context).width < 700;
    final enInforme = e.imagenesInforme.length;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/imagenes'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Imágenes',
        ),
        title: Text(
          e.titulo,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: CuerpoConsultorio(
        children: [
          _Franja(
            estudio: e,
            paciente: ficha?.nombreCompleto,
            detalle: [
              if (ficha != null && ficha.documentoTexto.isNotEmpty)
                ficha.documentoTexto,
              if (ficha?.edadAnios(e.fecha) case final edad?) '$edad años',
              formatoFechaHora(e.fecha),
            ].join(' · '),
            alFicha: ficha == null
                ? null
                : () => context.go('/pacientes/${ficha.id}'),
          ),
          const SizedBox(height: 16),
          if (e.estado == EstadoEstudio.anulado) ...[
            Aviso(
              icono: Icons.block,
              color: ColoresMarca.error,
              titulo: 'Informe ${e.numero} anulado',
              texto: Text('Motivo: ${e.motivoAnulacion}'),
            ),
            const SizedBox(height: 16),
          ],
          if (e.borrador) ..._editor(e, enInforme, movil) else ..._lectura(e),
        ],
      ),
    );
  }

  List<Widget> _editor(EstudioImagen e, int enInforme, bool movil) => [
    TarjetaConsultorio(
      icono: Icons.monitor_heart_outlined,
      titulo: 'Estudio',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RejillaCampos(
            anchoMinimo: 220,
            maxColumnas: 3,
            children: [
              CampoTexto(
                etiqueta: 'Tipo de estudio',
                requerido: true,
                valorInicial: e.titulo,
                alCambiar: (v) =>
                    _cambiar((x) => x.copyWith(titulo: v), redibujar: false),
              ),
              CampoTexto(
                etiqueta: 'Técnica',
                valorInicial: e.tecnica,
                alCambiar: (v) =>
                    _cambiar((x) => x.copyWith(tecnica: v), redibujar: false),
              ),
              CampoTexto(
                etiqueta: 'Equipo',
                requerido: true,
                pista: 'Marca y modelo de tu ecógrafo',
                valorInicial: e.equipo,
                alCambiar: (v) => _cambiar((x) => x.copyWith(equipo: v)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CampoTexto(
            etiqueta: 'Indicación',
            lineas: 2,
            valorInicial: e.indicacion,
            alCambiar: (v) =>
                _cambiar((x) => x.copyWith(indicacion: v), redibujar: false),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    TarjetaConsultorio(
      icono: Icons.notes,
      titulo: 'Hallazgos',
      subtitulo: 'El texto normal de la plantilla: edítalo con lo que ves.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, sec) in e.secciones.indexed) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CampoTexto(
                    key: ValueKey('seccion-$i-${sec.titulo}'),
                    etiqueta: sec.titulo,
                    lineas: 2,
                    valorInicial: sec.texto,
                    alCambiar: (v) => _cambiar(
                      (x) => x.copyWith(
                        secciones: [
                          for (final (k, y) in x.secciones.indexed)
                            k == i ? y.copyWith(texto: v) : y,
                        ],
                      ),
                      redibujar: false,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar «${sec.titulo}»',
                  onPressed: () => _cambiar(
                    (x) => x.copyWith(
                      secciones: [
                        for (final (k, y) in x.secciones.indexed)
                          if (k != i) y,
                      ],
                    ),
                  ),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _agregarSeccion,
              icon: const Icon(Icons.add),
              label: const Text('Agregar sección'),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    TarjetaConsultorio(
      icono: Icons.straighten,
      titulo: 'Medidas',
      subtitulo: 'Con tres diámetros en cm calcula el volumen (× 0,523).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, m) in e.medidas.indexed) ...[
            _FilaMedida(
              key: ValueKey('medida-$i-${m.nombre}'),
              medida: m,
              alCambiar: (n) => _cambiar(
                (x) => x.copyWith(
                  medidas: [
                    for (final (k, y) in x.medidas.indexed) k == i ? n : y,
                  ],
                ),
              ),
              alQuitar: () => _cambiar(
                (x) => x.copyWith(
                  medidas: [
                    for (final (k, y) in x.medidas.indexed)
                      if (k != i) y,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _agregarMedida,
              icon: const Icon(Icons.add),
              label: const Text('Agregar medida'),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    TarjetaConsultorio(
      icono: Icons.photo_library_outlined,
      titulo: 'Imágenes',
      subtitulo:
          'Las capturas de tu ecógrafo (desde la galería del celular o el '
          'computador). Van al informe hasta $maxImagenesInforme, en el orden '
          'en que las subes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (e.imagenes.isNotEmpty) ...[
            Text(
              '$enInforme de $maxImagenesInforme en el informe',
              style: TextStyle(
                color: enInforme > maxImagenesInforme
                    ? ColoresMarca.error
                    : ColoresMarca.textoSuave,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (n, i) in e.imagenes.indexed)
                  _TarjetaImagen(
                    key: ValueKey('imagen-${i.id}'),
                    numero: n + 1,
                    imagen: i,
                    ancho: movil ? double.infinity : 250,
                    alCambiar: (nueva) => _cambiar(
                      (x) => x.copyWith(
                        imagenes: [
                          for (final y in x.imagenes) y.id == i.id ? nueva : y,
                        ],
                      ),
                      redibujar: nueva.enInforme != i.enInforme,
                    ),
                    alQuitar: () => _quitarImagen(i),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _ocupado ? null : _agregarImagen,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Agregar imagen'),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    TarjetaConsultorio(
      icono: Icons.fact_check_outlined,
      titulo: 'Impresión diagnóstica',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CampoDiagnostico(
            etiqueta: 'Diagnóstico (CIE-10, opcional)',
            valor: e.diagnostico,
            alCambiar: (d) =>
                _cambiar((x) => x.copyWith(diagnostico: d), redibujar: false),
          ),
          const SizedBox(height: 12),
          CampoTexto(
            etiqueta: 'Impresión diagnóstica',
            lineas: 3,
            valorInicial: e.impresion,
            alCambiar: (v) => _cambiar((x) => x.copyWith(impresion: v)),
          ),
          const SizedBox(height: 12),
          CampoTexto(
            etiqueta: 'Recomendaciones',
            lineas: 2,
            valorInicial: e.recomendaciones,
            alCambiar: (v) => _cambiar(
              (x) => x.copyWith(recomendaciones: v),
              redibujar: false,
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    if (e.faltantes.isNotEmpty) ...[
      Text(
        'Para cerrar falta ${e.faltantes.join(', ')}.',
        style: const TextStyle(
          color: ColoresMarca.aviso,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 10),
    ],
    Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      children: [
        TextButton.icon(
          onPressed: _ocupado ? null : _borrar,
          style: TextButton.styleFrom(foregroundColor: ColoresMarca.error),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Borrar borrador'),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _ocupado ? null : _vistaPrevia,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Vista previa'),
            ),
            FilledButton.icon(
              onPressed: _ocupado || e.faltantes.isNotEmpty ? null : _cerrar,
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Cerrar informe'),
            ),
          ],
        ),
      ],
    ),
  ];

  List<Widget> _lectura(EstudioImagen e) => [
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: _descargar,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Descargar PDF'),
        ),
        OutlinedButton.icon(
          onPressed: _imprimir,
          icon: const Icon(Icons.print_outlined),
          label: const Text('Imprimir'),
        ),
        if (e.estado == EstadoEstudio.cerrado)
          TextButton.icon(
            onPressed: _anular,
            style: TextButton.styleFrom(foregroundColor: ColoresMarca.error),
            icon: const Icon(Icons.block),
            label: const Text('Anular'),
          ),
      ],
    ),
    const SizedBox(height: 16),
    TarjetaConsultorio(
      icono: Icons.monitor_heart_outlined,
      titulo: e.numero == null ? 'Informe' : 'Informe ${e.numero}',
      subtitulo: [
        if (e.tecnica.trim().isNotEmpty) e.tecnica.trim(),
        if (e.equipo.trim().isNotEmpty) e.equipo.trim(),
      ].join(' · '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (e.indicacion.trim().isNotEmpty)
            _Parrafo('Indicación', e.indicacion.trim()),
          for (final sec in e.secciones)
            if (sec.texto.trim().isNotEmpty)
              _Parrafo(sec.titulo, sec.texto.trim()),
          if (e.medidasConValor.isNotEmpty)
            _Parrafo(
              'Medidas',
              [
                for (final m in e.medidasConValor) '${m.nombre}: ${m.texto}',
              ].join('\n'),
            ),
          if (!e.diagnostico.vacio)
            _Parrafo('Diagnóstico', e.diagnostico.texto),
          if (e.impresion.trim().isNotEmpty)
            _Parrafo('Impresión diagnóstica', e.impresion.trim()),
          if (e.recomendaciones.trim().isNotEmpty)
            _Parrafo('Recomendaciones', e.recomendaciones.trim()),
          if (e.imagenes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (n, i) in e.imagenes.indexed)
                  _TarjetaImagen(numero: n + 1, imagen: i, ancho: 200),
              ],
            ),
          ],
        ],
      ),
    ),
  ];
}

class _Franja extends StatelessWidget {
  const _Franja({
    required this.estudio,
    required this.paciente,
    required this.detalle,
    this.alFicha,
  });

  final EstudioImagen estudio;
  final String? paciente;
  final String detalle;
  final VoidCallback? alFicha;

  @override
  Widget build(BuildContext context) {
    final e = estudio;
    final (color, texto, icono) = switch (e.estado) {
      EstadoEstudio.borrador => (
        ColoresMarca.aviso,
        'Borrador',
        Icons.edit_outlined,
      ),
      EstadoEstudio.cerrado => (
        ColoresMarca.estadoOk,
        e.numero ?? 'Cerrado',
        Icons.verified_outlined,
      ),
      EstadoEstudio.anulado => (ColoresMarca.error, 'Anulado', Icons.block),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RadiosMarca.tarjeta,
        border: Border.all(color: ColoresMarca.borde),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                paciente ?? 'Paciente',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                detalle,
                style: const TextStyle(color: ColoresMarca.textoSuave),
              ),
            ],
          ),
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              EtiquetaEstado(icono: icono, texto: texto, color: color),
              if (alFicha != null)
                TextButton(onPressed: alFicha, child: const Text('Ver ficha')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Parrafo extends StatelessWidget {
  const _Parrafo(this.titulo, this.texto);

  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: ColoresMarca.tintaSuave,
          ),
        ),
        Text(texto),
      ],
    ),
  );
}

/// Una medida: uno o tres valores, con el resultado.
class _FilaMedida extends StatelessWidget {
  const _FilaMedida({
    super.key,
    required this.medida,
    required this.alCambiar,
    required this.alQuitar,
  });

  final MedidaEstudio medida;
  final ValueChanged<MedidaEstudio> alCambiar;
  final VoidCallback alQuitar;

  @override
  Widget build(BuildContext context) {
    final m = medida;
    const ejes = ['Largo', 'Ancho', 'Alto'];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        borderRadius: RadiosMarca.control,
        border: Border.all(color: ColoresMarca.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  m.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (m.volumen && m.resultado != null)
                Text(
                  'Volumen ${numeroEco(m.resultado!)} ${m.unidad}',
                  style: const TextStyle(
                    color: ColoresMarca.estadoOk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              IconButton(
                tooltip: 'Quitar «${m.nombre}»',
                onPressed: alQuitar,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: RejillaCampos(
              anchoMinimo: 110,
              maxColumnas: 3,
              children: [
                for (var i = 0; i < (m.volumen ? 3 : 1); i++)
                  CampoNumero(
                    etiqueta: m.volumen ? ejes[i] : 'Valor',
                    unidad: m.volumen ? 'cm' : m.unidad,
                    valor: m.valor(i),
                    alCambiar: (v) => alCambiar(m.conValor(i, v)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pide una medida nueva: nombre, unidad o volumen.
class _DialogoMedida extends StatefulWidget {
  const _DialogoMedida();

  @override
  State<_DialogoMedida> createState() => _DialogoMedidaState();
}

class _DialogoMedidaState extends State<_DialogoMedida> {
  var _nombre = '';
  var _unidad = 'mm';
  var _volumen = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const TituloDialogo('Medida nueva', icono: Icons.straighten),
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CampoTexto(
            etiqueta: 'Nombre',
            requerido: true,
            pista: 'p. ej. Nódulo del lóbulo derecho',
            alCambiar: (v) => setState(() => _nombre = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _volumen,
            onChanged: (v) => setState(() => _volumen = v),
            title: const Text('Volumen con tres diámetros'),
          ),
          if (!_volumen)
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'mm', label: Text('mm')),
                ButtonSegment(value: 'cm', label: Text('cm')),
                ButtonSegment(value: 'mL', label: Text('mL')),
                ButtonSegment(value: 'cm/s', label: Text('cm/s')),
              ],
              selected: {_unidad},
              onSelectionChanged: (v) => setState(() => _unidad = v.first),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _nombre.trim().isEmpty
            ? null
            : () => Navigator.pop(
                context,
                MedidaEstudio(
                  nombre: _nombre.trim(),
                  unidad: _volumen ? 'mL' : _unidad,
                  volumen: _volumen,
                ),
              ),
        child: const Text('Agregar'),
      ),
    ],
  );
}

/// Una imagen con su miniatura, el rótulo y si va al informe.
class _TarjetaImagen extends ConsumerStatefulWidget {
  const _TarjetaImagen({
    super.key,
    required this.numero,
    required this.imagen,
    required this.ancho,
    this.alCambiar,
    this.alQuitar,
  });

  final int numero;
  final ImagenEstudio imagen;
  final double ancho;
  final ValueChanged<ImagenEstudio>? alCambiar;
  final VoidCallback? alQuitar;

  @override
  ConsumerState<_TarjetaImagen> createState() => _TarjetaImagenState();
}

class _TarjetaImagenState extends ConsumerState<_TarjetaImagen> {
  late final Future<Uint8List?> _mini = ref
      .read(servicioConsultorioProvider)
      .imagenes
      .miniatura(widget.imagen.id);

  @override
  Widget build(BuildContext context) {
    final i = widget.imagen;
    final editable = widget.alCambiar != null;
    return SizedBox(
      width: widget.ancho,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: RadiosMarca.control,
          border: Border.all(color: ColoresMarca.borde),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 150,
              color: Colors.black,
              alignment: Alignment.center,
              child: FutureBuilder(
                future: _mini,
                builder: (context, s) => s.data == null
                    ? const Icon(Icons.image_outlined, color: Colors.white54)
                    : Image.memory(
                        s.data!,
                        fit: BoxFit.contain,
                        semanticLabel: 'Imagen ${widget.numero}',
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              child: editable
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${widget.numero}.',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: i.enInforme,
                                onChanged: (v) => widget.alCambiar!(
                                  i.copyWith(enInforme: v ?? false),
                                ),
                                title: const Text('En el informe'),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Quitar la imagen ${widget.numero}',
                              onPressed: widget.alQuitar,
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: CampoTexto(
                            etiqueta: 'Rótulo',
                            pista: 'p. ej. Lóbulo derecho, transversal',
                            valorInicial: i.rotulo,
                            alCambiar: (v) =>
                                widget.alCambiar!(i.copyWith(rotulo: v)),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      [
                        '${widget.numero}.',
                        if (i.rotulo.trim().isNotEmpty) i.rotulo.trim(),
                        if (!i.enInforme) '(fuera del informe)',
                      ].join(' '),
                      style: const TextStyle(fontSize: 13),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
