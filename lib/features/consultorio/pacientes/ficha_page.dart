import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/indice/indice_pacientes.dart';
import '../../../core/consultorio/documentos/plantillas.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/consultorio/modelos/registro_historia.dart';
import '../../../core/pais/perfil_pais.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../../historia/estado/historia_controller.dart';
import '../../historia/widgets/dialogos.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../integracion/enganche_historia.dart';
import '../widgets/comunes.dart';
import '../documentos/firma_autorizacion.dart';
import '../documentos/linea_tiempo_documentos.dart';
import '../fotos/seccion_fotos.dart';
import '../estetica/seccion_estetica.dart';
import '../peso/seccion_peso.dart';
import '../seguimiento/seccion_seguimiento.dart';
import 'dialogo_ficha.dart';
import 'unir_fichas.dart';

/// Ficha longitudinal del paciente: datos, alergias y antecedentes (con su
/// fuente), acciones y línea de tiempo de sus historias.
class FichaPage extends ConsumerStatefulWidget {
  const FichaPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<FichaPage> createState() => _FichaPageState();
}

/// Secciones de la ficha. En la 5.3 se suman programa de peso y estética.
enum SeccionFicha {
  resumen('Resumen', Icons.timeline),
  seguimiento('Seguimiento', Icons.show_chart),
  peso('Peso', Icons.monitor_weight_outlined),
  estetica('Estética', Icons.spa_outlined),
  fotos('Fotos', Icons.photo_library_outlined);

  const SeccionFicha(this.etiqueta, this.icono);

  final String etiqueta;
  final IconData icono;
}

class _FichaPageState extends ConsumerState<FichaPage> {
  var _seccion = SeccionFicha.resumen;

  String get id => widget.id;

  @override
  Widget build(BuildContext context) {
    ref.watch(versionIndiceProvider);
    final s = ref.read(servicioConsultorioProvider);
    final indice = s.indice;
    final f = indice.ficha(id);
    final ancho = MediaQuery.sizeOf(context).width;
    final movil = ancho < 700;
    final margen = math.max(movil ? 12.0 : 24.0, (ancho - 1100) / 2);

    if (f == null || !f.activa) {
      final destino = f?.unidaEn == null ? null : indice.ficha(f!.unidaEn!);
      return Scaffold(
        appBar: AppBar(title: const Text('Ficha del paciente')),
        body: CuerpoConsultorio(
          children: [
            Text(
              destino == null
                  ? 'No se encontró la ficha.'
                  : 'Esta ficha se unió a la de ${destino.nombreCompleto}.',
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: () => context.go(
                  destino == null ? '/pacientes' : '/pacientes/${destino.id}',
                ),
                child: Text(destino == null ? 'Ver pacientes' : 'Abrir ficha'),
              ),
            ),
          ],
        ),
      );
    }

    final ahora = s.reloj.ahora();
    final historias = indice.historiasDe(f.id);
    // Historias, documentos y recetas, de lo más reciente a lo más viejo.
    final entradas = <(DateTime, Widget)>[
      for (final h in historias)
        (h.ultimaAtencion, _TarjetaHistoria(historia: h)),
      for (final d in s.documentos.documentosDe(f.id))
        (d.fechaHora, TarjetaDocumento(documento: d)),
      for (final r in indice.recetasDe(f.id))
        (r.fecha, TarjetaReceta(receta: r)),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    final resumen = indice.resumen(f);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/pacientes'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Pacientes',
        ),
        title: const Text(
          'Ficha del paciente',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(margen, 16, margen, 48),
        children: [
          _Encabezado(ficha: f, resumen: resumen, ahora: ahora),
          const SizedBox(height: 12),
          _Acciones(ficha: f, tieneHistorias: historias.isNotEmpty),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final s in SeccionFicha.values)
                ChoiceChip(
                  avatar: Icon(s.icono, size: 18),
                  label: Text(s.etiqueta),
                  selected: _seccion == s,
                  onSelected: (_) => setState(() => _seccion = s),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_seccion == SeccionFicha.seguimiento)
            SeccionSeguimiento(ficha: f)
          else if (_seccion == SeccionFicha.peso)
            SeccionPeso(ficha: f)
          else if (_seccion == SeccionFicha.estetica)
            SeccionEstetica(ficha: f)
          else if (_seccion == SeccionFicha.fotos)
            SeccionFotos(ficha: f)
          else ...[
            _Clinico(ficha: f, ultima: historias.firstOrNull),
            const SizedBox(height: 16),
            const Text('LÍNEA DE TIEMPO', style: EstilosMarca.rotulo),
            const SizedBox(height: 8),
            if (entradas.isEmpty)
              const Text(
                'Sin historias todavía. «Historia nueva» empieza una con los '
                'datos de esta ficha.',
                style: TextStyle(color: ColoresMarca.textoSuave),
              )
            else
              for (final (_, tarjeta) in entradas) ...[
                tarjeta,
                const SizedBox(height: 12),
              ],
          ],
        ],
      ),
    );
  }
}

class _Encabezado extends ConsumerWidget {
  const _Encabezado({
    required this.ficha,
    required this.resumen,
    required this.ahora,
  });

  final FichaPaciente ficha;
  final ResumenPaciente resumen;
  final DateTime ahora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ficha;
    final indice = ref.read(servicioConsultorioProvider).indice;
    final edad = f.edadAnios(ahora);
    final sexo = opcionesSexo
        .where((o) => o.codigo == f.sexo)
        .map((o) => o.etiqueta)
        .firstOrNull;
    final alergias = indice.alergiasDe(f.id);
    final proximo = resumen.proximoControl;
    final datos = [
      if (f.documentoTexto.isNotEmpty) f.documentoTexto,
      if (edad != null) '$edad años',
      ?sexo,
    ];
    final contacto = [
      if (f.telefono.isNotEmpty) 'Tel. ${f.telefono}',
      if (f.correo.isNotEmpty) f.correo,
      [f.direccion, f.ciudad].where((s) => s.isNotEmpty).join(', '),
      if (f.aseguradora.isNotEmpty) f.aseguradora,
      if (f.contactoEmergencia.isNotEmpty)
        'Emergencias: ${f.contactoEmergencia}',
    ].where((s) => s.isNotEmpty).toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RadiosMarca.tarjeta,
        border: Border.all(color: ColoresMarca.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.nombreCompleto, style: EstilosMarca.titulo),
          if (datos.isNotEmpty)
            Text(
              datos.join(' · '),
              style: const TextStyle(color: ColoresMarca.textoSuave),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              switch (alergias) {
                (alergias: final a, niega: _, desde: _) when a.isNotEmpty =>
                  EtiquetaEstado(
                    icono: Icons.warning_amber_rounded,
                    texto: 'Alergias: ${a.join(', ')}',
                    color: ColoresMarca.error,
                  ),
                (alergias: _, niega: true, desde: _) => const EtiquetaEstado(
                  icono: Icons.check,
                  texto: 'Niega alergias',
                  color: ColoresMarca.estadoOk,
                ),
                _ => const EtiquetaEstado(
                  icono: Icons.help_outline,
                  texto: 'Alergias sin registrar',
                  color: ColoresMarca.aviso,
                ),
              },
              if (proximo != null)
                EtiquetaEstado(
                  icono: Icons.alarm,
                  texto: resumen.controlVencido(ahora)
                      ? 'Control vencido (${formatoFecha(proximo)})'
                      : 'Próximo control ${formatoFecha(proximo)}',
                  color: resumen.controlVencido(ahora)
                      ? ColoresMarca.aviso
                      : ColoresMarca.primario,
                ),
              for (final l in LineaAtencion.values)
                if (f.lineas.contains(l))
                  EtiquetaEstado(
                    icono: Icons.label_outline,
                    texto: l.etiqueta,
                    color: ColoresMarca.primario,
                  ),
              for (final e in f.etiquetas)
                EtiquetaEstado(
                  icono: Icons.sell_outlined,
                  texto: e,
                  color: ColoresMarca.textoSuave,
                ),
            ],
          ),
          if (contacto.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(contacto.join(' · ')),
          ],
          const SizedBox(height: 10),
          LineaAutorizacion(ficha: f),
          const SizedBox(height: 6),
          LineaConsentimientoImagen(ficha: f),
          if (f.notas.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Notas internas: ${f.notas.trim()}',
              style: const TextStyle(
                fontSize: 13,
                color: ColoresMarca.textoSuave,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Acciones extends ConsumerWidget {
  const _Acciones({required this.ficha, required this.tieneHistorias});

  final FichaPaciente ficha;
  final bool tieneHistorias;

  /// Antes de reemplazar la historia en curso: si tiene cambios sin
  /// guardar (y no es la que se va a continuar), pide confirmación.
  Future<bool> _puedeReemplazar(
    BuildContext context,
    WidgetRef ref, {
    required bool continuar,
  }) => confirmarReemplazoHistoria(
    context,
    ref,
    pacienteId: ficha.id,
    continuar: continuar,
  );

  Future<void> _historiaNueva(BuildContext context, WidgetRef ref) async {
    if (!await _puedeReemplazar(context, ref, continuar: false)) return;
    await nuevaHistoriaPara(ref, ficha);
    if (context.mounted) context.go('/');
  }

  Future<void> _evolucion(BuildContext context, WidgetRef ref) async {
    if (!await _puedeReemplazar(context, ref, continuar: true)) return;
    if (await nuevaEvolucionPara(ref, ficha.id) && context.mounted) {
      context.go('/');
    }
  }

  Future<void> _receta(BuildContext context, WidgetRef ref) async {
    if (!await _puedeReemplazar(context, ref, continuar: true)) return;
    await prepararRecetaPara(ref, ficha);
    if (context.mounted) context.go('/receta');
  }

  Future<void> _alergias(BuildContext context, WidgetRef ref) async {
    final vigentes = ref
        .read(servicioConsultorioProvider)
        .indice
        .alergiasDe(ficha.id);
    final r = await showDialog<({List<String> alergias, bool niega})>(
      context: context,
      builder: (_) => _DialogoAlergias(
        alergias: vigentes?.alergias ?? const [],
        niega: vigentes?.niega ?? false,
      ),
    );
    if (r == null || !context.mounted) return;
    if (!await _puedeReemplazar(context, ref, continuar: true)) return;
    final donde = await actualizarAlergias(
      ref,
      ficha,
      alergias: r.alergias,
      niega: r.niega,
    );
    if (!context.mounted) return;
    // El mensajero es el de la app: sigue vivo al salir de la ficha.
    final mensajero = ScaffoldMessenger.of(context);
    context.go('/');
    mensajero.showSnackBar(
      SnackBar(
        content: Text(
          'Se agregó «${lineaAlergias(r.alergias, niega: r.niega)}» en '
          '$donde. La ficha la mostrará al guardar la historia en PDF.',
        ),
      ),
    );
  }

  Future<void> _editar(BuildContext context) =>
      editarFicha(context, ficha: ficha);

  Future<void> _unir(BuildContext context, WidgetRef ref) async {
    final destino = await unirFichas(context, ref, ficha: ficha);
    if (destino != null && destino != ficha.id && context.mounted) {
      context.go('/pacientes/$destino');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acciones = <(IconData, String, VoidCallback?)>[
      (
        Icons.note_add_outlined,
        'Historia nueva',
        () => _historiaNueva(context, ref),
      ),
      (
        Icons.edit_note,
        'Evolución',
        tieneHistorias ? () => _evolucion(context, ref) : null,
      ),
      (Icons.medication_outlined, 'Receta', () => _receta(context, ref)),
      (
        Icons.warning_amber_rounded,
        'Actualizar alergias',
        () => _alergias(context, ref),
      ),
      (
        Icons.privacy_tip_outlined,
        'Autorización de datos',
        () => pedirAutorizacionDatos(context, ficha: ficha),
      ),
      (
        Icons.photo_camera_outlined,
        'Consentimiento de imagen',
        () => pedirConsentimientoImagen(context, ficha: ficha),
      ),
      (Icons.edit_outlined, 'Editar datos', () => _editar(context)),
      (Icons.merge_type, 'Unir con otra ficha', () => _unir(context, ref)),
    ];
    // Certificado, incapacidad, orden y remisión (5.4).
    final documentos = [
      for (final (tipo, icono, texto) in const [
        (
          TipoPlantilla.certificado,
          Icons.workspace_premium_outlined,
          'Certificado',
        ),
        (TipoPlantilla.incapacidad, Icons.event_busy_outlined, 'Incapacidad'),
        (
          TipoPlantilla.orden,
          Icons.biotech_outlined,
          'Orden de laboratorio o imágenes',
        ),
        (
          TipoPlantilla.remision,
          Icons.forward_to_inbox_outlined,
          'Remisión o interconsulta',
        ),
      ])
        (
          icono,
          texto,
          () => context.go('/pacientes/${ficha.id}/documento/${tipo.name}'),
        ),
    ];
    if (MediaQuery.sizeOf(context).width < 700) {
      return Align(
        alignment: Alignment.centerLeft,
        child: MenuAnchor(
          menuChildren: [
            for (final (icono, texto, accion) in [
              ...acciones.take(3),
              ...documentos,
              ...acciones.skip(3),
            ])
              MenuItemButton(
                leadingIcon: Icon(icono),
                onPressed: accion,
                child: Text(texto),
              ),
          ],
          builder: (context, menu, _) => FilledButton.icon(
            onPressed: () => menu.isOpen ? menu.close() : menu.open(),
            icon: const Icon(Icons.arrow_drop_down),
            label: const Text('Acciones'),
          ),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (i, (icono, texto, accion)) in acciones.indexed) ...[
          i < 2
              ? FilledButton.icon(
                  onPressed: accion,
                  icon: Icon(icono),
                  label: Text(texto),
                )
              : OutlinedButton.icon(
                  onPressed: accion,
                  icon: Icon(icono),
                  label: Text(texto),
                ),
          if (i == 2)
            MenuAnchor(
              menuChildren: [
                for (final (icono, texto, accion) in documentos)
                  MenuItemButton(
                    leadingIcon: Icon(icono),
                    onPressed: accion,
                    child: Text(texto),
                  ),
              ],
              builder: (context, menu, _) => OutlinedButton.icon(
                onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Documento'),
              ),
            ),
        ],
      ],
    );
  }
}

/// Antecedentes y alergias, con la historia de la que salen.
class _Clinico extends ConsumerWidget {
  const _Clinico({required this.ficha, required this.ultima});

  final FichaPaciente ficha;
  final RegistroHistoria? ultima;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ultima;
    if (h == null) return const SizedBox.shrink();
    final alergias = ref
        .read(servicioConsultorioProvider)
        .indice
        .alergiasDe(ficha.id);
    final desde = alergias?.desde;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RadiosMarca.tarjeta,
        border: Border.all(color: ColoresMarca.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ANTECEDENTES · DE LA HISTORIA DEL ${formatoFecha(h.fechaAtencion)}',
            style: EstilosMarca.rotulo,
          ),
          const SizedBox(height: 8),
          if (alergias != null)
            _Dato(
              'Alergias',
              [
                if (alergias.alergias.isNotEmpty)
                  alergias.alergias.join(', ')
                else if (alergias.niega)
                  'Niega'
                else
                  'Sin registrar',
                if (desde != null) '(actualizadas el ${formatoFecha(desde)})',
              ].join(' '),
            ),
          for (final e in h.antecedentes.entries) _Dato(e.key, e.value),
          if (h.antecedentes.isEmpty)
            const Text(
              'Sin antecedentes escritos.',
              style: TextStyle(color: ColoresMarca.textoSuave),
            ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$etiqueta: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: valor),
          ],
        ),
      ),
    );
  }
}

/// Una historia en la línea de tiempo, con sus evoluciones.
class _TarjetaHistoria extends ConsumerWidget {
  const _TarjetaHistoria({required this.historia});

  final RegistroHistoria historia;

  Future<void> _continuar(BuildContext context, WidgetRef ref) async {
    final enCurso = ref.read(historiaProvider);
    final misma = enCurso.abierta && enCurso.historia.id == historia.id;
    if (!misma &&
        historiaEnCursoConCambios(ref) &&
        !await confirmar(
          context,
          titulo: '¿Reemplazar la historia en curso?',
          texto:
              'La historia que tienes abierta tiene cambios sin guardar en '
              'PDF. Si continúas, se perderán.',
          aceptar: 'Reemplazar',
          icono: Icons.warning_amber_rounded,
          peligro: true,
        )) {
      return;
    }
    if (!misma) await abrirHistoriaDelIndice(ref, historia.id);
    if (context.mounted) context.go('/');
  }

  Future<void> _pdf(
    BuildContext context,
    WidgetRef ref, {
    required bool descargar,
  }) async {
    final bytes = await ref
        .read(servicioConsultorioProvider)
        .indice
        .pdfDe(historia.id);
    if (bytes == null) return;
    final nombre = historia.archivos.isEmpty
        ? 'historia.pdf'
        : historia.archivos.last.nombre;
    if (descargar) {
      ref.read(descargarPdfProvider)(bytes, nombre);
    } else {
      await ref.read(verPdfProvider)(bytes, nombre);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = historia;
    // Borde uniforme (Flutter no redondea bordes de distinto color) y una
    // franja a la izquierda: petróleo si está íntegra, rojo si no.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RadiosMarca.tarjeta,
        border: Border.all(color: ColoresMarca.borde),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: h.integridadCorrecta
                  ? ColoresMarca.primario
                  : ColoresMarca.error,
              child: const SizedBox(width: 3),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _contenido(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context, WidgetRef ref) {
    final h = historia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${formatoFecha(h.fechaAtencion)} · Historia clínica',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (h.motivo.isNotEmpty) Text(h.motivo),
        if (h.diagnosticos.isNotEmpty)
          Text(
            h.diagnosticos.take(3).join(' · '),
            style: const TextStyle(color: ColoresMarca.textoSuave),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            EtiquetaEstado(
              icono: h.integridadCorrecta
                  ? Icons.verified_outlined
                  : Icons.gpp_bad_outlined,
              texto: h.integridadCorrecta
                  ? 'Íntegra · revisión ${h.revision}'
                  : h.integridadDescripcion,
              color: h.integridadCorrecta
                  ? ColoresMarca.estadoOk
                  : ColoresMarca.error,
            ),
            if (h.divergente)
              EtiquetaEstado(
                icono: Icons.call_split,
                texto:
                    'Versiones divergentes: '
                    '${h.divergencias.map((a) => a.nombre).join(', ')}',
                color: ColoresMarca.aviso,
              ),
            if (h.medico.isNotEmpty)
              EtiquetaEstado(
                icono: Icons.person_outline,
                texto: h.medico,
                color: ColoresMarca.textoSuave,
              ),
          ],
        ),
        if (h.evoluciones.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final e in h.evoluciones.reversed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text:
                          '${formatoFecha(e.fechaHora)} · Evolución '
                          '${e.numero}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (e.resumen.isNotEmpty) TextSpan(text: ' · ${e.resumen}'),
                    if (e.proximoControl != null)
                      TextSpan(
                        text:
                            ' · Próximo control '
                            '${formatoFecha(e.proximoControl!)}',
                      ),
                    if (e.huella.isNotEmpty)
                      TextSpan(
                        text: ' · ${e.huella}',
                        style: const TextStyle(color: ColoresMarca.textoSuave),
                      ),
                  ],
                ),
              ),
            ),
        ],
        if (h.recetasEnTexto.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final r in h.recetasEnTexto)
            Text(
              r,
              style: const TextStyle(
                fontSize: 13,
                color: ColoresMarca.textoSuave,
              ),
            ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _continuar(context, ref),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir en la historia'),
            ),
            if (h.tienePdf) ...[
              OutlinedButton.icon(
                onPressed: () => _pdf(context, ref, descargar: false),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Ver PDF'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pdf(context, ref, descargar: true),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Descargar PDF'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _DialogoAlergias extends StatefulWidget {
  const _DialogoAlergias({required this.alergias, required this.niega});

  final List<String> alergias;
  final bool niega;

  @override
  State<_DialogoAlergias> createState() => _DialogoAlergiasState();
}

class _DialogoAlergiasState extends State<_DialogoAlergias> {
  late final _texto = TextEditingController(text: widget.alergias.join(', '));
  late var _niega = widget.niega && widget.alergias.isEmpty;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  List<String> get _lista => [
    for (final a in _texto.text.split(','))
      if (a.trim().isNotEmpty) a.trim(),
  ];

  @override
  Widget build(BuildContext context) {
    final valido = _niega || _lista.isNotEmpty;
    return AlertDialog(
      title: const TituloDialogo(
        'Actualizar alergias',
        icono: Icons.warning_amber_rounded,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Lo sellado no se edita: se agrega una línea «Alergias '
              'actualizadas: …» a la evolución en curso de la historia más '
              'reciente, y queda sellada al descargarla.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _texto,
              enabled: !_niega,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Alergias',
                hintText: 'Separadas por comas',
              ),
            ),
            CheckboxListTile(
              value: _niega,
              onChanged: (v) => setState(() => _niega = v ?? false),
              title: const Text('Niega alergias'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
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
          onPressed: valido
              ? () => Navigator.pop(context, (
                  alergias: _niega ? const <String>[] : _lista,
                  niega: _niega,
                ))
              : null,
          child: const Text('Agregar a la evolución'),
        ),
      ],
    );
  }
}
