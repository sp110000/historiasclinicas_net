import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/clinica/rangos.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/consultorio/peso/catalogo_glp1.dart';
import '../../../core/consultorio/peso/plantillas_plan.dart';
import '../../../core/consultorio/peso/programa_peso.dart';
import '../../../core/consultorio/peso/programas.dart';
import '../../../core/consultorio/reglas/glp1.dart';
import '../../../core/pais/perfil_pais.dart' show Opcion;
import '../../../core/utils/numeros.dart';
import '../../../core/widgets/campos.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../integracion/copiar_evolucion.dart';
import '../widgets/comunes.dart';

ProgramasPeso _peso(WidgetRef ref) =>
    ref.read(servicioConsultorioProvider).peso;

/// Esqueleto de los diálogos del programa: título, contenido desplazable,
/// error y botones.
class _Dialogo extends StatelessWidget {
  const _Dialogo({
    required this.titulo,
    required this.icono,
    required this.children,
    required this.aceptar,
    required this.alAceptar,
    this.error,
    this.ocupado = false,
    this.ancho = 560,
  });

  final String titulo;
  final IconData icono;
  final List<Widget> children;
  final String aceptar;
  final VoidCallback? alAceptar;
  final String? error;
  final bool ocupado;
  final double ancho;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: TituloDialogo(titulo, icono: icono),
    content: SizedBox(
      width: ancho,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...children,
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: ColoresMarca.error)),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: ocupado ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: ocupado ? null : alAceptar, child: Text(aceptar)),
    ],
  );
}

// ───────────────────────── Programa (meta y planes) ─────────────────────────

/// Crea o edita el programa de la ficha: inicio, meta, proteína y planes.
Future<void> editarPrograma(
  BuildContext context, {
  required FichaPaciente ficha,
  ProgramaPeso? programa,
}) => showDialog<void>(
  context: context,
  builder: (_) => _DialogoPrograma(ficha: ficha, programa: programa),
);

class _DialogoPrograma extends ConsumerStatefulWidget {
  const _DialogoPrograma({required this.ficha, this.programa});

  final FichaPaciente ficha;
  final ProgramaPeso? programa;

  @override
  ConsumerState<_DialogoPrograma> createState() => _DialogoProgramaState();
}

class _DialogoProgramaState extends ConsumerState<_DialogoPrograma> {
  late ProgramaPeso _p;
  late final _textoNutricional = TextEditingController(
    text: _p.planNutricional?.texto ?? '',
  );
  late final _textoEjercicio = TextEditingController(
    text: _p.planEjercicio?.texto ?? '',
  );
  String? _error;
  var _ocupado = false;

  @override
  void initState() {
    super.initState();
    final ahora = _peso(ref).reloj.ahora();
    _p =
        widget.programa ??
        ProgramaPeso(
          id: '',
          pacienteId: widget.ficha.id,
          inicio: DateTime(ahora.year, ahora.month, ahora.day),
          creado: ahora,
          actualizado: ahora,
        );
  }

  @override
  void dispose() {
    _textoNutricional.dispose();
    _textoEjercicio.dispose();
    super.dispose();
  }

  void _elegirPlan(TipoPlan tipo, String? plantillaId) {
    final control = tipo == TipoPlan.nutricional
        ? _textoNutricional
        : _textoEjercicio;
    if (plantillaId == null) {
      setState(() {
        _p = tipo == TipoPlan.nutricional
            ? _p.copyWith(planNutricional: null)
            : _p.copyWith(planEjercicio: null);
        control.text = '';
      });
      return;
    }
    final plan = _peso(ref).asignarPlan(
      plantillaId,
      paciente: widget.ficha.nombreCompleto,
      proteina: _p.proteina,
      metaPeso: _p.metaPeso,
    );
    setState(() {
      _p = tipo == TipoPlan.nutricional
          ? _p.copyWith(planNutricional: plan)
          : _p.copyWith(planEjercicio: plan);
      control.text = plan.texto;
    });
  }

  PlanAsignado? _conTexto(PlanAsignado? p, String texto) => p == null
      ? null
      : PlanAsignado(
          plantillaId: p.plantillaId,
          version: p.version,
          nombre: p.nombre,
          texto: texto.trim(),
        );

  Future<void> _guardar() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await _peso(ref).guardar(
        _p.copyWith(
          planNutricional: _conTexto(
            _p.planNutricional,
            _textoNutricional.text,
          ),
          planEjercicio: _conTexto(_p.planEjercicio, _textoEjercicio.text),
        ),
      );
      ref.read(versionIndiceProvider.notifier).cambio();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _ocupado = false;
        _error = mensajeDeError(e);
      });
    }
  }

  Widget _plan(TipoPlan tipo) {
    final usables = [
      for (final p in _peso(ref).plantillas)
        if (p.tipo == tipo && p.usable) p,
    ];
    final actual = tipo == TipoPlan.nutricional
        ? _p.planNutricional
        : _p.planEjercicio;
    final control = tipo == TipoPlan.nutricional
        ? _textoNutricional
        : _textoEjercicio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tipo.etiqueta.toUpperCase(), style: EstilosMarca.rotulo),
        const SizedBox(height: 6),
        if (usables.isEmpty && actual == null)
          const Text(
            'Ninguna plantilla aprobada: revísalas y apruébalas en Ajustes → '
            'Programa de peso.',
            style: TextStyle(color: ColoresMarca.textoSuave),
          )
        else ...[
          DropdownButtonFormField<String?>(
            initialValue: actual?.plantillaId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Plantilla'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin plan')),
              for (final p in usables)
                DropdownMenuItem(
                  value: p.id,
                  child: Text('${p.nombre} (v${p.vigente!.version})'),
                ),
              if (actual != null &&
                  !usables.any((p) => p.id == actual.plantillaId))
                DropdownMenuItem(
                  value: actual.plantillaId,
                  child: Text('${actual.nombre} (v${actual.version})'),
                ),
            ],
            onChanged: (v) => _elegirPlan(tipo, v),
          ),
          if (actual != null) ...[
            const SizedBox(height: 8),
            TextField(
              controller: control,
              minLines: 3,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: 'Texto para el paciente (${tipo.etiqueta})',
                helperText: 'Completa los «______» antes de imprimir.',
              ),
            ),
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return _Dialogo(
      titulo: widget.programa == null
          ? 'Programa de peso'
          : 'Editar el programa de peso',
      icono: Icons.monitor_weight_outlined,
      ancho: 680,
      error: _error,
      ocupado: _ocupado,
      aceptar: widget.programa == null ? 'Iniciar programa' : 'Guardar',
      alAceptar: _guardar,
      children: [
        RejillaCampos(
          anchoMinimo: 180,
          children: [
            CampoFecha(
              etiqueta: 'Inicio',
              valor: p.inicio,
              requerido: true,
              primera: DateTime(2000),
              ultima: DateTime.now().add(const Duration(days: 365)),
              alCambiar: (f) {
                if (f != null) setState(() => _p = _p.copyWith(inicio: f));
              },
            ),
            CampoNumero(
              etiqueta: 'Peso meta',
              valor: p.metaPeso,
              unidad: 'kg',
              rango: Rangos.peso,
              alCambiar: (v) => setState(() => _p = _p.copyWith(metaPeso: v)),
            ),
            CampoNumero(
              etiqueta: 'Cintura meta',
              valor: p.metaCintura,
              unidad: 'cm',
              alCambiar: (v) =>
                  setState(() => _p = _p.copyWith(metaCintura: v)),
            ),
            CampoFecha(
              etiqueta: 'Fecha de la meta',
              valor: p.metaFecha,
              primera: DateTime(2000),
              ultima: DateTime(2100),
              alCambiar: (f) => setState(() => _p = _p.copyWith(metaFecha: f)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CampoTexto(
          etiqueta: 'Proteína indicada',
          valorInicial: p.proteina,
          pista: 'La cantidad la fijas tú; p. ej. g/kg/día',
          alCambiar: (v) => _p = _p.copyWith(proteina: v.trim()),
        ),
        const SizedBox(height: 8),
        const _Recordatorio(),
        const SizedBox(height: 14),
        _plan(TipoPlan.nutricional),
        const SizedBox(height: 14),
        _plan(TipoPlan.ejercicio),
        const SizedBox(height: 12),
        CampoTexto(
          etiqueta: 'Notas internas',
          valorInicial: p.notas,
          lineas: 2,
          alCambiar: (v) => _p = _p.copyWith(notas: v.trim()),
        ),
      ],
    );
  }
}

/// «Proteína suficiente y entrenamiento de fuerza…» (pregunta 26).
class _Recordatorio extends StatelessWidget {
  const _Recordatorio();

  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.info_outline, size: 18, color: ColoresMarca.primario),
      SizedBox(width: 6),
      Expanded(
        child: Text(
          'Recuerda: $recordatorioProteinaFuerza',
          style: TextStyle(color: ColoresMarca.textoSuave),
        ),
      ),
    ],
  );
}

// ───────────────────────── Contraindicaciones ─────────────────────────

/// Revisión de la lista de contraindicaciones del GLP-1 (pregunta 25).
Future<void> revisarContraindicaciones(
  BuildContext context, {
  required FichaPaciente ficha,
  required ProgramaPeso programa,
}) => showDialog<void>(
  context: context,
  builder: (_) => _DialogoContraindicaciones(ficha: ficha, programa: programa),
);

class _DialogoContraindicaciones extends ConsumerStatefulWidget {
  const _DialogoContraindicaciones({
    required this.ficha,
    required this.programa,
  });

  final FichaPaciente ficha;
  final ProgramaPeso programa;

  @override
  ConsumerState<_DialogoContraindicaciones> createState() =>
      _DialogoContraindicacionesState();
}

class _DialogoContraindicacionesState
    extends ConsumerState<_DialogoContraindicaciones> {
  late final Map<String, RespuestaItem> _r = {
    ...?widget.programa.contraindicaciones?.respuestas,
  };
  String? _error;
  var _ocupado = false;

  Future<void> _guardar() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await _peso(ref).revisarContraindicaciones(
        widget.programa.id,
        _r,
        sexo: widget.ficha.sexo,
      );
      ref.read(versionIndiceProvider.notifier).cambio();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _ocupado = false;
        _error = mensajeDeError(e);
      });
    }
  }

  Widget _item(ItemContraindicacion item) {
    final r = _r[item.id];
    final pideNota =
        !item.absoluta && r != null && r.respuesta != RespuestaContra.no;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectorOpciones(
            etiqueta: '${item.texto}${item.absoluta ? ' · absoluta' : ''}',
            opciones: [
              for (final o in RespuestaContra.values)
                Opcion(o.name, o.etiqueta),
            ],
            valor: r?.respuesta.name,
            alCambiar: (v) {
              if (v == null) return;
              setState(
                () => _r[item.id] = RespuestaItem(
                  RespuestaContra.values.byName(v),
                  r?.nota ?? '',
                ),
              );
            },
          ),
          if (item.absoluta && r != null && r.respuesta != RespuestaContra.no)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                r.respuesta == RespuestaContra.si
                    ? 'Impide iniciar el GLP-1.'
                    : 'Acláralo antes de iniciar el GLP-1.',
                style: const TextStyle(color: ColoresMarca.error),
              ),
            ),
          if (pideNota) ...[
            const SizedBox(height: 6),
            CampoTexto(
              etiqueta: 'Nota *',
              valorInicial: r.nota,
              alCambiar: (v) =>
                  _r[item.id] = RespuestaItem(r.respuesta, v.trim()),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = contraindicacionesAplicables(widget.ficha.sexo);
    return _Dialogo(
      titulo: 'Contraindicaciones del GLP-1',
      icono: Icons.fact_check_outlined,
      ancho: 640,
      error: _error,
      ocupado: _ocupado,
      aceptar: 'Guardar revisión',
      alAceptar: _guardar,
      children: [
        const Text(
          'Las absolutas en «Sí» o sin aclarar impiden iniciar el GLP-1. Una '
          'precaución en «Sí» o «No sabe» pide una nota. Lista de referencia: '
          'VERIFICAR contra la ficha técnica con registro Invima.',
          style: TextStyle(color: ColoresMarca.textoSuave),
        ),
        const SizedBox(height: 12),
        const Text('ABSOLUTAS', style: EstilosMarca.rotulo),
        const SizedBox(height: 8),
        for (final i in items.where((i) => i.absoluta)) _item(i),
        const Text('PRECAUCIONES', style: EstilosMarca.rotulo),
        const SizedBox(height: 8),
        for (final i in items.where((i) => !i.absoluta)) _item(i),
      ],
    );
  }
}

// ─────────────────────────── GLP-1 ───────────────────────────

/// Inicia el GLP-1 del programa (si la lista lo permite).
Future<void> iniciarGlp1(
  BuildContext context, {
  required FichaPaciente ficha,
  required ProgramaPeso programa,
}) => showDialog<void>(
  context: context,
  builder: (_) => _DialogoDosis(ficha: ficha, programa: programa, inicio: true),
);

/// Registra un cambio de dosis del GLP-1 activo.
Future<void> cambiarDosis(
  BuildContext context, {
  required FichaPaciente ficha,
  required ProgramaPeso programa,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _DialogoDosis(ficha: ficha, programa: programa, inicio: false),
);

class _DialogoDosis extends ConsumerStatefulWidget {
  const _DialogoDosis({
    required this.ficha,
    required this.programa,
    required this.inicio,
  });

  final FichaPaciente ficha;
  final ProgramaPeso programa;
  final bool inicio;

  @override
  ConsumerState<_DialogoDosis> createState() => _DialogoDosisState();
}

class _DialogoDosisState extends ConsumerState<_DialogoDosis> {
  late String _medicamentoId =
      widget.programa.glp1?.medicamentoId ?? _peso(ref).catalogo.first.id;
  late DateTime _fecha = _hoy();
  double? _dosis;
  late var _copiar = tieneHistorias(ref, widget.ficha.id);
  String? _error;
  var _ocupado = false;

  DateTime _hoy() {
    final a = _peso(ref).reloj.ahora();
    return DateTime(a.year, a.month, a.day);
  }

  Future<void> _guardar() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    final peso = _peso(ref);
    try {
      final dosis = DosisGlp1(fecha: _fecha, dosis: _dosis ?? 0);
      final p = widget.inicio
          ? await peso.iniciarGlp1(
              widget.programa.id,
              medicamentoId: _medicamentoId,
              dosis: dosis,
              sexo: widget.ficha.sexo,
            )
          : await peso.cambiarDosis(widget.programa.id, dosis);
      ref.read(versionIndiceProvider.notifier).cambio();
      if (!mounted) return;
      if (_copiar) {
        await copiarALaEvolucion(
          context,
          ref,
          pacienteId: widget.ficha.id,
          texto: widget.inicio
              ? textoInicioGlp1(p.glp1!, p.contraindicaciones)
              : textoCambioDosis(p.glp1!, dosis),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _ocupado = false;
        _error = mensajeDeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final peso = _peso(ref);
    final m = peso.medicamento(_medicamentoId);
    final g = widget.programa.glp1;
    final semana = g == null ? 0 : _fecha.difference(g.inicio).inDays ~/ 7;
    final sugerido = widget.inicio
        ? m?.pasoEnSemana(0)
        : m?.pasoEnSemana(semana);
    return _Dialogo(
      titulo: widget.inicio ? 'Iniciar GLP-1' : 'Cambio de dosis',
      icono: Icons.vaccines_outlined,
      error: _error,
      ocupado: _ocupado,
      aceptar: widget.inicio ? 'Iniciar' : 'Guardar dosis',
      alAceptar: _guardar,
      children: [
        if (widget.inicio)
          DropdownButtonFormField<String>(
            initialValue: _medicamentoId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Medicamento'),
            items: [
              for (final c in peso.catalogo)
                DropdownMenuItem(value: c.id, child: Text(c.nombre)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _medicamentoId = v);
            },
          )
        else
          Text(g!.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (m != null) ...[
          const SizedBox(height: 8),
          InfoMedicamento(medicamento: m),
        ],
        const SizedBox(height: 12),
        RejillaCampos(
          anchoMinimo: 180,
          children: [
            CampoFecha(
              etiqueta: 'Fecha',
              valor: _fecha,
              requerido: true,
              primera: DateTime(2000),
              ultima: DateTime.now().add(const Duration(days: 365)),
              alCambiar: (f) {
                if (f != null) setState(() => _fecha = f);
              },
            ),
            CampoNumero(
              etiqueta: 'Dosis',
              valor: _dosis,
              unidad: 'mg',
              alCambiar: (v) => _dosis = v,
            ),
          ],
        ),
        if (sugerido != null) ...[
          const SizedBox(height: 6),
          Text(
            'El esquema aprobado sugiere ${formatoNumero(sugerido.dosis)} '
            '${sugerido.unidad} desde la semana ${sugerido.semana}.',
            style: const TextStyle(color: ColoresMarca.textoSuave),
          ),
        ],
        if (tieneHistorias(ref, widget.ficha.id))
          CasillaEvolucion(
            valor: _copiar,
            alCambiar: (v) => setState(() => _copiar = v),
          ),
      ],
    );
  }
}

/// Registro Invima, indicación y esquema de un medicamento del catálogo,
/// con sus avisos.
class InfoMedicamento extends StatelessWidget {
  const InfoMedicamento({super.key, required this.medicamento});

  final MedicamentoGlp1 medicamento;

  @override
  Widget build(BuildContext context) {
    final m = medicamento;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        m.registroConfirmado
            ? EtiquetaEstado(
                icono: Icons.verified_outlined,
                texto: 'Invima ${m.registroInvima}',
                color: ColoresMarca.estadoOk,
              )
            : const EtiquetaEstado(
                icono: Icons.warning_amber_rounded,
                texto: 'Registro Invima sin confirmar',
                color: ColoresMarca.aviso,
              ),
        EtiquetaEstado(
          icono: Icons.info_outline,
          texto: m.indicacion.isEmpty
              ? 'Indicación aprobada sin confirmar (VERIFICAR)'
              : 'Indicación aprobada: ${m.indicacion} (VERIFICAR)',
          color: ColoresMarca.aviso,
        ),
        m.esquemaAprobado
            ? const EtiquetaEstado(
                icono: Icons.check,
                texto: 'Esquema aprobado',
                color: ColoresMarca.estadoOk,
              )
            : const EtiquetaEstado(
                icono: Icons.edit_note,
                texto: 'Esquema sin aprobar',
                color: ColoresMarca.textoSuave,
              ),
      ],
    );
  }
}

/// Tolerancia, evento adverso o suspensión del GLP-1.
enum RegistroGlp1 { tolerancia, evento, suspension }

Future<void> registrarGlp1(
  BuildContext context, {
  required FichaPaciente ficha,
  required ProgramaPeso programa,
  required RegistroGlp1 tipo,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _DialogoRegistro(ficha: ficha, programa: programa, tipo: tipo),
);

class _DialogoRegistro extends ConsumerStatefulWidget {
  const _DialogoRegistro({
    required this.ficha,
    required this.programa,
    required this.tipo,
  });

  final FichaPaciente ficha;
  final ProgramaPeso programa;
  final RegistroGlp1 tipo;

  @override
  ConsumerState<_DialogoRegistro> createState() => _DialogoRegistroState();
}

class _DialogoRegistroState extends ConsumerState<_DialogoRegistro> {
  late DateTime _fecha = () {
    final a = _peso(ref).reloj.ahora();
    return DateTime(a.year, a.month, a.day);
  }();
  var _texto = '';
  var _conducta = '';
  var _intensidad = Intensidad.leve;
  var _gravedad = Gravedad.leve;
  var _reportado = false;
  late var _copiar =
      widget.tipo != RegistroGlp1.tolerancia &&
      tieneHistorias(ref, widget.ficha.id);
  String? _error;
  var _ocupado = false;

  Future<void> _guardar() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    final peso = _peso(ref);
    final id = widget.programa.id;
    try {
      final String? texto;
      switch (widget.tipo) {
        case RegistroGlp1.tolerancia:
          await peso.registrarTolerancia(
            id,
            RegistroTolerancia(
              fecha: _fecha,
              sintomas: _texto.trim(),
              intensidad: _intensidad,
            ),
          );
          texto = null;
        case RegistroGlp1.evento:
          final e = EventoAdverso(
            fecha: _fecha,
            descripcion: _texto.trim(),
            gravedad: _gravedad,
            conducta: _conducta.trim(),
            reportadoInvima: _reportado,
          );
          final p = await peso.registrarEvento(id, e);
          texto = textoEventoAdverso(p.glp1!, e);
        case RegistroGlp1.suspension:
          final p = await peso.suspenderGlp1(id, _texto);
          texto = textoSuspension(p.glp1!);
      }
      ref.read(versionIndiceProvider.notifier).cambio();
      if (!mounted) return;
      if (_copiar && texto != null) {
        await copiarALaEvolucion(
          context,
          ref,
          pacienteId: widget.ficha.id,
          texto: texto,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _ocupado = false;
        _error = mensajeDeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final (titulo, icono, aceptar) = switch (widget.tipo) {
      RegistroGlp1.tolerancia => (
        'Tolerancia',
        Icons.sentiment_neutral_outlined,
        'Guardar',
      ),
      RegistroGlp1.evento => (
        'Evento adverso',
        Icons.report_outlined,
        'Registrar evento',
      ),
      RegistroGlp1.suspension => (
        'Suspender el GLP-1',
        Icons.block_outlined,
        'Suspender',
      ),
    };
    return _Dialogo(
      titulo: titulo,
      icono: icono,
      error: _error,
      ocupado: _ocupado,
      aceptar: aceptar,
      alAceptar: _guardar,
      children: [
        if (widget.tipo != RegistroGlp1.suspension) ...[
          CampoFecha(
            etiqueta: 'Fecha',
            valor: _fecha,
            requerido: true,
            primera: DateTime(2000),
            ultima: DateTime.now().add(const Duration(days: 1)),
            alCambiar: (f) {
              if (f != null) setState(() => _fecha = f);
            },
          ),
          const SizedBox(height: 12),
        ],
        CampoTexto(
          etiqueta: switch (widget.tipo) {
            RegistroGlp1.tolerancia => 'Síntomas *',
            RegistroGlp1.evento => 'Descripción *',
            RegistroGlp1.suspension => 'Motivo *',
          },
          lineas: 2,
          alCambiar: (v) => _texto = v,
        ),
        const SizedBox(height: 12),
        if (widget.tipo == RegistroGlp1.tolerancia)
          SelectorOpciones(
            etiqueta: 'Intensidad',
            opciones: [
              for (final i in Intensidad.values) Opcion(i.name, i.etiqueta),
            ],
            valor: _intensidad.name,
            alCambiar: (v) {
              if (v != null) {
                setState(() => _intensidad = Intensidad.values.byName(v));
              }
            },
          ),
        if (widget.tipo == RegistroGlp1.evento) ...[
          SelectorOpciones(
            etiqueta: 'Gravedad',
            opciones: [
              for (final g in Gravedad.values) Opcion(g.name, g.etiqueta),
            ],
            valor: _gravedad.name,
            alCambiar: (v) {
              if (v != null) {
                setState(() => _gravedad = Gravedad.values.byName(v));
              }
            },
          ),
          const SizedBox(height: 12),
          CampoTexto(
            etiqueta: 'Conducta',
            lineas: 2,
            alCambiar: (v) => _conducta = v,
          ),
          CheckboxListTile(
            value: _reportado,
            onChanged: (v) => setState(() => _reportado = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Reportado a Invima (farmacovigilancia)'),
          ),
        ],
        if (widget.tipo != RegistroGlp1.tolerancia &&
            tieneHistorias(ref, widget.ficha.id))
          CasillaEvolucion(
            valor: _copiar,
            alCambiar: (v) => setState(() => _copiar = v),
          ),
      ],
    );
  }
}
