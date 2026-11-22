import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/documentos/documento.dart';
import '../../../core/consultorio/documentos/documento_clinico.dart';
import '../../../core/consultorio/documentos/plantillas.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/consultorio/reglas/documentos.dart';
import '../../../core/pais/pais_provider.dart';
import '../../../core/pais/perfil_pais.dart' show Opcion;
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/campos.dart';
import '../../historia/widgets/dialogos.dart';
import '../../medico/medico_provider.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/campo_diagnostico.dart';
import '../widgets/comunes.dart';
import '../widgets/vista_previa_pdf.dart';

/// Certificado, incapacidad, orden o remisión (5.4): el mismo formulario
/// corto para todos, con la vista previa del PDF real. Al emitir se
/// descarga el PDF (con `documento.json`) y queda en la ficha.
class DocumentoClinicoPage extends ConsumerStatefulWidget {
  const DocumentoClinicoPage({
    super.key,
    required this.pacienteId,
    required this.tipo,
  });

  final String pacienteId;
  final TipoPlantilla tipo;

  @override
  ConsumerState<DocumentoClinicoPage> createState() =>
      _DocumentoClinicoPageState();
}

class _DocumentoClinicoPageState extends ConsumerState<DocumentoClinicoPage> {
  FichaPaciente? _ficha;
  BorradorDocumento? _b;

  /// El texto como salió de la plantilla: si cambió, cambiar de plantilla
  /// pide confirmación.
  var _textoDePlantilla = '';

  /// Sube cada vez que el texto se reemplaza desde fuera del campo.
  var _generacionTexto = 0;
  var _cambios = 0;
  var _incluirFirma = true;
  var _incluirSello = true;
  var _emitiendo = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = ref.read(servicioConsultorioProvider);
    final ficha = s.indice.fichaActiva(widget.pacienteId);
    if (ficha == null) return;
    _ficha = ficha;
    var b = s.documentos.nuevoBorrador(
      widget.tipo,
      ficha: ficha,
      medico: ref.read(medicoProvider),
    );
    // El diagnóstico principal de la última historia, para empezar.
    final dx = s.indice.ultimaHistoria(ficha.id)?.diagnosticos.firstOrNull;
    if (dx != null && dx.trim().isNotEmpty) {
      b = b.copyWith(diagnostico: DiagnosticoDocumento.desdeTexto(dx));
    }
    _b = b;
    _textoDePlantilla = b.texto;
  }

  void _cambiar(BorradorDocumento b) => setState(() {
    _b = b;
    _cambios++;
    _error = null;
  });

  Future<void> _elegirPlantilla(String id) async {
    final b = _b!;
    if (id == b.plantillaId) return;
    if (b.texto.trim() != _textoDePlantilla.trim()) {
      final si = await confirmar(
        context,
        titulo: '¿Cambiar de plantilla?',
        texto:
            'El texto que escribiste se reemplaza por el de la otra '
            'plantilla. Los demás datos se conservan.',
        aceptar: 'Cambiar',
        icono: Icons.swap_horiz,
      );
      if (!si || !mounted) return;
    }
    final nuevo = ref
        .read(servicioConsultorioProvider)
        .documentos
        .conPlantilla(b, id, ficha: _ficha!, medico: ref.read(medicoProvider));
    _textoDePlantilla = nuevo.texto;
    _generacionTexto++;
    _cambiar(nuevo);
  }

  EvaluacionDocumento _evaluar() {
    final s = ref.read(servicioConsultorioProvider);
    return s.documentos.evaluar(
      _b!,
      medico: ref.read(medicoProvider),
      configuracion: s.configuracion,
    );
  }

  Future<void> _emitir() async {
    setState(() {
      _emitiendo = true;
      _error = null;
    });
    try {
      final s = ref.read(servicioConsultorioProvider);
      final r = await s.documentos.emitirDocumento(
        _b!,
        ficha: _ficha!,
        medico: ref.read(medicoProvider),
        pais: ref.read(paisProvider),
        configuracion: s.configuracion,
        incluirFirma: _incluirFirma,
        incluirSello: _incluirSello,
      );
      final numero = r.documento.numero;
      ref.read(descargarPdfProvider)(
        r.pdf,
        nombreArchivoDocumento(
          widget.tipo.baseArchivo,
          apellido: _ficha!.primerApellido,
          numero: numero,
        ),
      );
      ref.read(versionIndiceProvider.notifier).cambio();
      if (!mounted) return;
      mostrarMensaje(
        context,
        '${r.documento.titulo} $numero emitido: el PDF se descargó y quedó en '
        'la ficha.',
      );
      context.go('/pacientes/${widget.pacienteId}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _emitiendo = false;
          _error = mensajeDeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ficha = _ficha;
    final b = _b;
    final ancho = MediaQuery.sizeOf(context).width;
    final volver = IconButton(
      tooltip: 'Volver a la ficha',
      onPressed: () => context.go('/pacientes/${widget.pacienteId}'),
      icon: const Icon(Icons.arrow_back),
    );
    if (ficha == null || b == null) {
      return Scaffold(
        appBar: AppBar(leading: volver, title: Text(widget.tipo.etiqueta)),
        body: const CuerpoConsultorio(
          children: [Text('No se encontró la ficha del paciente.')],
        ),
      );
    }
    ref.watch(medicoProvider);
    final e = _evaluar();
    final s = ref.read(servicioConsultorioProvider);
    final formulario = _Formulario(
      tipo: widget.tipo,
      ficha: ficha,
      borrador: b,
      evaluacion: e,
      plantillas: s.documentos.plantillasDe(widget.tipo),
      generacionTexto: _generacionTexto,
      incluirFirma: _incluirFirma,
      incluirSello: _incluirSello,
      alElegirPlantilla: _elegirPlantilla,
      alCambiar: _cambiar,
      alCambiarFirma: (v) => setState(() {
        _incluirFirma = v;
        _cambios++;
      }),
      alCambiarSello: (v) => setState(() {
        _incluirSello = v;
        _cambios++;
      }),
    );
    final vistaPrevia = ColoredBox(
      color: const Color(0xFFE6EBEF),
      child: VistaPreviaPdf(
        clave: _cambios,
        descripcion: widget.tipo.etiqueta.toLowerCase(),
        generar: () => s.documentos.vistaPrevia(
          _b!,
          ficha: ficha,
          medico: ref.read(medicoProvider),
          pais: ref.read(paisProvider),
          configuracion: s.configuracion,
          incluirFirma: _incluirFirma,
          incluirSello: _incluirSello,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        leading: volver,
        titleSpacing: 0,
        title: Text(
          '${widget.tipo.etiqueta} · ${ficha.nombreCompleto}',
          style: const TextStyle(fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      bottomNavigationBar: _BarraEmitir(
        evaluacion: e,
        error: _error,
        emitiendo: _emitiendo,
        alEmitir: _emitir,
      ),
      body: ancho >= 1100
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: formulario),
                SizedBox(width: ancho >= 1400 ? 620 : 520, child: vistaPrevia),
              ],
            )
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const Material(
                    color: Colors.white,
                    child: TabBar(
                      tabs: [
                        Tab(text: 'Editar'),
                        Tab(text: 'Vista previa'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [formulario, vistaPrevia],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Formulario extends StatelessWidget {
  const _Formulario({
    required this.tipo,
    required this.ficha,
    required this.borrador,
    required this.evaluacion,
    required this.plantillas,
    required this.generacionTexto,
    required this.incluirFirma,
    required this.incluirSello,
    required this.alElegirPlantilla,
    required this.alCambiar,
    required this.alCambiarFirma,
    required this.alCambiarSello,
  });

  final TipoPlantilla tipo;
  final FichaPaciente ficha;
  final BorradorDocumento borrador;
  final EvaluacionDocumento evaluacion;
  final List<Plantilla> plantillas;
  final int generacionTexto;
  final bool incluirFirma;
  final bool incluirSello;
  final ValueChanged<String> alElegirPlantilla;
  final ValueChanged<BorradorDocumento> alCambiar;
  final ValueChanged<bool> alCambiarFirma;
  final ValueChanged<bool> alCambiarSello;

  @override
  Widget build(BuildContext context) {
    final b = borrador;
    final plantilla = plantillas.firstWhere((p) => p.id == b.plantillaId);
    return CuerpoConsultorio(
      children: [
        Text(
          [
            ficha.nombreCompleto,
            if (ficha.documentoTexto.isNotEmpty) ficha.documentoTexto,
          ].join(' · '),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _Bloque(
          titulo: 'Plantilla',
          children: [
            if (plantillas.length > 1)
              CampoDesplegable(
                etiqueta: 'Plantilla',
                opciones: [
                  for (final p in plantillas)
                    Opcion(
                      p.id,
                      p.usable ? p.nombre : '${p.nombre} (borrador)',
                    ),
                ],
                valor: b.plantillaId,
                alCambiar: alElegirPlantilla,
              )
            else
              Text(plantilla.nombre),
            const SizedBox(height: 6),
            if (plantilla.usable)
              Text(
                'Versión ${b.versionPlantilla} · aprobada el '
                '${formatoFecha(plantilla.vigente!.aprobadaEn!)}',
                style: const TextStyle(color: ColoresMarca.textoSuave),
              )
            else
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'En borrador: revísala y apruébala antes de emitir.',
                    style: TextStyle(color: ColoresMarca.aviso),
                  ),
                  TextButton(
                    onPressed: () => context.go('/ajustes'),
                    child: const Text('Ir a Ajustes'),
                  ),
                ],
              ),
            if (b.plantillaId == 'certificado_laboral') ...[
              const SizedBox(height: 6),
              const Text(
                'Las evaluaciones médicas ocupacionales (de ingreso, '
                'periódicas y de retiro) tienen su propia norma y pueden '
                'exigir licencia en seguridad y salud en el trabajo '
                '(VERIFICAR).',
                style: TextStyle(color: ColoresMarca.textoSuave),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _Bloque(titulo: 'Datos', children: _datos(context)),
        const SizedBox(height: 12),
        _Bloque(
          titulo: 'Texto',
          children: [
            CampoTexto(
              key: ValueKey('texto-${b.plantillaId}-$generacionTexto'),
              etiqueta: 'Texto del documento',
              valorInicial: b.texto,
              lineas: 12,
              ayuda: 'Completa los «______» antes de emitir.',
              alCambiar: (v) => alCambiar(b.copyWith(texto: v)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _Interruptor(
                  texto: 'Incluir mi firma',
                  valor: incluirFirma,
                  alCambiar: alCambiarFirma,
                ),
                _Interruptor(
                  texto: 'Incluir mi sello',
                  valor: incluirSello,
                  alCambiar: alCambiarSello,
                ),
              ],
            ),
          ],
        ),
        if (evaluacion.avisos.isNotEmpty || evaluacion.bloqueos.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final m in evaluacion.bloqueos)
            _Linea(texto: m, icono: Icons.block, color: ColoresMarca.error),
          for (final m in evaluacion.avisos)
            _Linea(
              texto: m,
              icono: Icons.warning_amber_rounded,
              color: ColoresMarca.aviso,
            ),
        ],
      ],
    );
  }

  List<Widget> _datos(BuildContext context) {
    final b = borrador;
    switch (tipo) {
      case TipoPlantilla.certificado:
        return [
          CampoTexto(
            etiqueta: 'Se expide con destino a',
            requerido: true,
            valorInicial: b.finalidad,
            pista: 'Empresa, colegio, liga deportiva…',
            alCambiar: (v) => alCambiar(b.copyWith(finalidad: v)),
          ),
          const SizedBox(height: 8),
          _Interruptor(
            texto: 'Incluir el diagnóstico (solo si el paciente lo autoriza)',
            valor: b.incluirDiagnostico,
            alCambiar: (v) => alCambiar(b.copyWith(incluirDiagnostico: v)),
          ),
          if (b.incluirDiagnostico) ...[
            const SizedBox(height: 8),
            CampoDiagnostico(
              valor: b.diagnostico,
              requerido: true,
              alCambiar: (d) => alCambiar(b.copyWith(diagnostico: d)),
            ),
          ],
        ];
      case TipoPlantilla.incapacidad:
        final hasta = b.hasta;
        return [
          CampoDiagnostico(
            valor: b.diagnostico,
            requerido: true,
            alCambiar: (d) => alCambiar(b.copyWith(diagnostico: d)),
          ),
          const SizedBox(height: 12),
          RejillaCampos(
            anchoMinimo: 180,
            children: [
              CampoDesplegable(
                etiqueta: 'Origen',
                opciones: [
                  for (final o in OrigenIncapacidad.values)
                    Opcion(o.name, o.etiqueta),
                ],
                valor: b.origen.name,
                alCambiar: (v) => alCambiar(
                  b.copyWith(origen: OrigenIncapacidad.values.byName(v)),
                ),
              ),
              CampoEntero(
                etiqueta: 'Días',
                requerido: true,
                valor: b.dias,
                alCambiar: (v) => alCambiar(b.copyWith(dias: v)),
              ),
              CampoFecha(
                etiqueta: 'Desde',
                requerido: true,
                valor: b.desde,
                alCambiar: (f) {
                  if (f != null) alCambiar(b.copyWith(desde: f));
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasta == null
                ? 'Escribe los días para ver hasta cuándo va.'
                : 'Hasta el ${formatoFecha(hasta)} (el día de inicio cuenta).',
            style: const TextStyle(color: ColoresMarca.textoSuave),
          ),
          const SizedBox(height: 8),
          _Interruptor(
            texto: 'Es una prórroga',
            valor: b.prorroga,
            alCambiar: (v) => alCambiar(b.copyWith(prorroga: v)),
          ),
          if (b.prorroga) ...[
            const SizedBox(height: 8),
            CampoTexto(
              etiqueta: 'Número de la incapacidad que se prorroga',
              valorInicial: b.prorrogaDe,
              pista: 'IN-000012',
              alCambiar: (v) => alCambiar(b.copyWith(prorrogaDe: v)),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Si no perteneces a la red de la EPS del paciente, la EPS puede '
            'pedir validarla (Decreto 1427 de 2022, VERIFICAR).',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
        ];
      case TipoPlantilla.orden:
        return [
          CampoDiagnostico(
            etiqueta: 'Impresión diagnóstica',
            valor: b.diagnostico,
            alCambiar: (d) => alCambiar(b.copyWith(diagnostico: d)),
          ),
        ];
      case TipoPlantilla.remision:
        return [
          CampoTexto(
            etiqueta: 'Remitido a (especialidad o servicio)',
            requerido: true,
            valorInicial: b.destino,
            alCambiar: (v) => alCambiar(b.copyWith(destino: v)),
          ),
          const SizedBox(height: 12),
          CampoDiagnostico(
            valor: b.diagnostico,
            alCambiar: (d) => alCambiar(b.copyWith(diagnostico: d)),
          ),
        ];
      default:
        return const [];
    }
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({required this.titulo, required this.children});

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: RadiosMarca.tarjeta,
      border: Border.all(color: ColoresMarca.borde),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          titulo.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: ColoresMarca.textoSuave,
          ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );
}

class _Linea extends StatelessWidget {
  const _Linea({required this.texto, required this.icono, required this.color});

  final String texto;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(texto, style: TextStyle(color: color)),
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => MergeSemantics(
    child: InkWell(
      borderRadius: RadiosMarca.control,
      onTap: () => alCambiar(!valor),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(value: valor, onChanged: alCambiar),
          const SizedBox(width: 4),
          Flexible(child: Text(texto)),
        ],
      ),
    ),
  );
}

class _BarraEmitir extends StatelessWidget {
  const _BarraEmitir({
    required this.evaluacion,
    required this.error,
    required this.emitiendo,
    required this.alEmitir,
  });

  final EvaluacionDocumento evaluacion;
  final String? error;
  final bool emitiendo;
  final VoidCallback alEmitir;

  @override
  Widget build(BuildContext context) {
    final motivo = error ?? evaluacion.bloqueos.firstOrNull;
    final n = evaluacion.avisos.length;
    final estado = Text(
      motivo ??
          (n == 0
              ? 'Listo para emitir.'
              : 'Listo para emitir, con $n ${n == 1 ? 'aviso' : 'avisos'}.'),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: motivo == null ? ColoresMarca.estadoOk : ColoresMarca.error,
      ),
    );
    final boton = FilledButton.icon(
      onPressed: emitiendo || !evaluacion.permiteEmitir ? null : alEmitir,
      icon: const Icon(Icons.download_outlined),
      label: const Text('Emitir y descargar'),
    );
    return Material(
      color: Colors.white,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          // En pantallas angostas, el motivo arriba y el botón abajo.
          child: MediaQuery.sizeOf(context).width < 480
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [estado, const SizedBox(height: 8), boton],
                )
              : Row(
                  children: [
                    Expanded(child: estado),
                    const SizedBox(width: 12),
                    boton,
                  ],
                ),
        ),
      ),
    );
  }
}
