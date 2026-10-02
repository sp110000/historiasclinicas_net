import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/clinica/rangos.dart';
import '../../../core/models/historia.dart';
import '../../../core/models/medico.dart';
import '../../../core/pais/perfil_pais.dart';
import '../../../core/presentacion/datos_historia.dart';
import '../../../core/widgets/campos.dart';
import '../../medico/medico_provider.dart';
import '../estado/historia_controller.dart';
import 'edicion.dart';

// ─────────────────────────── Motivo ───────────────────────────

class FormularioMotivo extends ConsumerWidget {
  const FormularioMotivo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.read(historiaProvider).historia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampoTexto(
          etiqueta: 'Motivo de consulta',
          pista: 'En palabras del paciente',
          requerido: true,
          lineas: 2,
          valorInicial: h.motivoConsulta,
          alCambiar: (v) => ref.editar((h) => h.copyWith(motivoConsulta: v)),
        ),
        const SizedBox(height: 14),
        CampoTexto(
          etiqueta: 'Enfermedad actual',
          pista:
              'Tiempo de evolución, forma de inicio, curso, síntomas asociados…',
          requerido: true,
          lineas: 5,
          valorInicial: h.enfermedadActual,
          alCambiar: (v) => ref.editar((h) => h.copyWith(enfermedadActual: v)),
        ),
      ],
    );
  }
}

// ─────────────────────────── Antecedentes ───────────────────────────

class FormularioAntecedentes extends ConsumerWidget {
  const FormularioAntecedentes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(historiaProvider.select((e) => e.historia));
    final a = h.antecedentes;

    Widget texto(
      String etiqueta,
      String valor,
      Antecedentes Function(Antecedentes, String) cambio,
    ) => CampoTexto(
      etiqueta: etiqueta,
      lineas: 2,
      valorInicial: valor,
      alCambiar: (v) => ref.editarAntecedentes((a) => cambio(a, v)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BloqueAlergias(antecedentes: a),
        const SizedBox(height: 18),
        FilaCampos(
          children: [
            texto(
              'Personales patológicos',
              a.personales,
              (a, v) => a.copyWith(personales: v),
            ),
            texto(
              'Medicación actual',
              a.medicacionActual,
              (a, v) => a.copyWith(medicacionActual: v),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilaCampos(
          children: [
            texto(
              'Quirúrgicos',
              a.quirurgicos,
              (a, v) => a.copyWith(quirurgicos: v),
            ),
            texto(
              'Familiares',
              a.familiares,
              (a, v) => a.copyWith(familiares: v),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilaCampos(
          children: [
            texto(
              'Hábitos (tabaco, alcohol, otras sustancias)',
              a.habitos,
              (a, v) => a.copyWith(habitos: v),
            ),
            texto(
              'Otros antecedentes',
              a.otros,
              (a, v) => a.copyWith(otros: v),
            ),
          ],
        ),
        if (h.esFemenino) ...[
          const SizedBox(height: 18),
          _BloqueGineco(historia: h),
        ],
      ],
    );
  }
}

class _BloqueAlergias extends ConsumerWidget {
  const _BloqueAlergias({required this.antecedentes});

  final Antecedentes antecedentes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = antecedentes;
    final esquema = Theme.of(context).colorScheme;
    return FormField<bool>(
      validator: (_) => a.alergiasRegistradas
          ? null
          : 'Registra las alergias o marca "Niega alergias conocidas"',
      builder: (campo) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        decoration: BoxDecoration(
          color: ColoresMarca.aviso.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: campo.hasError
                ? esquema.error
                : ColoresMarca.aviso.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              header: true,
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: ColoresMarca.aviso,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Alergias *',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se usarán para avisar al formular la receta',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: ColoresMarca.textoSuave,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CampoEtiquetas(
              etiqueta: 'Alergia (medicamento, alimento, otro)',
              pista: 'Escribe y pulsa Enter: penicilina, AINEs…',
              valores: a.alergias,
              habilitado: !a.niegaAlergias,
              alCambiar: (lista) {
                ref.editarAntecedentes(
                  (a) => a.copyWith(alergias: lista, niegaAlergias: false),
                );
                campo.didChange(true);
              },
            ),
            CheckboxListTile(
              value: a.niegaAlergias,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Niega alergias conocidas'),
              onChanged: (v) {
                ref.editarAntecedentes(
                  (a) => a.copyWith(
                    niegaAlergias: v ?? false,
                    alergias: (v ?? false) ? const [] : a.alergias,
                  ),
                );
                campo.didChange(true);
              },
            ),
            if (campo.hasError)
              Text(
                campo.errorText!,
                style: TextStyle(color: esquema.error, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

class _BloqueGineco extends ConsumerWidget {
  const _BloqueGineco({required this.historia});

  final HistoriaClinica historia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = historia.antecedentes.gineco;
    final gestacion = textoGestacion(historia);
    void editar(GinecoObstetricos Function(GinecoObstetricos g) cambio) =>
        ref.editarAntecedentes((a) => a.copyWith(gineco: cambio(a.gineco)));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColoresMarca.fondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresMarca.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Gineco-obstétricos',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          RejillaCampos(
            anchoMinimo: 96,
            maxColumnas: 5,
            children: [
              CampoEntero(
                etiqueta: 'G',
                valor: g.gestaciones,
                alCambiar: (v) => editar((g) => g.copyWith(gestaciones: v)),
              ),
              CampoEntero(
                etiqueta: 'P',
                valor: g.partos,
                alCambiar: (v) => editar((g) => g.copyWith(partos: v)),
              ),
              CampoEntero(
                etiqueta: 'C',
                valor: g.cesareas,
                alCambiar: (v) => editar((g) => g.copyWith(cesareas: v)),
              ),
              CampoEntero(
                etiqueta: 'A',
                valor: g.abortos,
                alCambiar: (v) => editar((g) => g.copyWith(abortos: v)),
              ),
              CampoEntero(
                etiqueta: 'V',
                valor: g.vivos,
                alCambiar: (v) => editar((g) => g.copyWith(vivos: v)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilaCampos(
            children: [
              CampoFecha(
                etiqueta: 'FUM (última menstruación)',
                valor: g.fum,
                ultima: DateTime.now(),
                alCambiar: (f) => editar((g) => g.copyWith(fum: f)),
              ),
              CampoTexto(
                etiqueta: 'Método anticonceptivo',
                valorInicial: g.anticoncepcion,
                alCambiar: (v) => editar((g) => g.copyWith(anticoncepcion: v)),
              ),
            ],
          ),
          SwitchListTile(
            value: g.gestante,
            contentPadding: EdgeInsets.zero,
            title: const Text('Gestante'),
            subtitle: Text(
              gestacion.isNotEmpty
                  ? gestacion
                  : g.gestante
                  ? 'Escribe la FUM para calcular la edad gestacional y la FPP'
                  : 'Calcula la edad gestacional y la fecha probable de parto',
              style: TextStyle(
                color: gestacion.isNotEmpty
                    ? ColoresMarca.secundario
                    : ColoresMarca.textoSuave,
                fontWeight: gestacion.isNotEmpty
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
            onChanged: (v) => editar((g) => g.copyWith(gestante: v)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Signos vitales ───────────────────────────

class FormularioSignos extends ConsumerWidget {
  const FormularioSignos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(historiaProvider.select((e) => e.historia));
    final s = h.signos;
    final adulto = (h.edadAnios ?? 18) >= 18;

    Widget numero(
      String etiqueta,
      double? valor,
      String unidad,
      RangoSigno rango,
      SignosVitales Function(SignosVitales, double?) cambio, {
      bool decimales = true,
    }) => CampoNumero(
      etiqueta: etiqueta,
      valor: valor,
      unidad: unidad,
      rango: rango,
      decimales: decimales,
      avisarFueraDeRango: adulto,
      alCambiar: (v) => ref.editarSignos((s) => cambio(s, v)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RejillaCampos(
          children: [
            numero(
              'PA sistólica',
              s.paSistolica,
              'mmHg',
              Rangos.paSistolica,
              (s, v) => s.copyWith(paSistolica: v),
              decimales: false,
            ),
            numero(
              'PA diastólica',
              s.paDiastolica,
              'mmHg',
              Rangos.paDiastolica,
              (s, v) => s.copyWith(paDiastolica: v),
              decimales: false,
            ),
            numero(
              'FC',
              s.fc,
              'lpm',
              Rangos.fc,
              (s, v) => s.copyWith(fc: v),
              decimales: false,
            ),
            numero(
              'FR',
              s.fr,
              'rpm',
              Rangos.fr,
              (s, v) => s.copyWith(fr: v),
              decimales: false,
            ),
            numero(
              'Temperatura',
              s.temperatura,
              '°C',
              Rangos.temperatura,
              (s, v) => s.copyWith(temperatura: v),
            ),
            numero(
              'SpO₂',
              s.spo2,
              '%',
              Rangos.spo2,
              (s, v) => s.copyWith(spo2: v),
              decimales: false,
            ),
            numero(
              'Peso',
              s.peso,
              'kg',
              Rangos.peso,
              (s, v) => s.copyWith(peso: v),
            ),
            numero(
              'Talla',
              s.talla,
              'cm',
              Rangos.talla,
              (s, v) => s.copyWith(talla: v),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilaCampos(
          flex: const [2, 1, 1],
          children: [
            ValorCalculado(
              etiqueta: 'IMC (calculado)',
              valor: textoImc(h),
              vacio: 'Escribe peso y talla',
              destacado: true,
            ),
            numero(
              'Glucemia capilar',
              s.glucemia,
              'mg/dL',
              Rangos.glucemia,
              (s, v) => s.copyWith(glucemia: v),
              decimales: false,
            ),
            numero(
              'Perímetro abdominal',
              s.perimetroAbdominal,
              'cm',
              Rangos.perimetroAbdominal,
              (s, v) => s.copyWith(perimetroAbdominal: v),
            ),
          ],
        ),
        if (!adulto)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Paciente menor de 18 años: no se marcan rangos habituales de '
              'adulto; solo se revisan valores imposibles.',
              style: TextStyle(fontSize: 12.5, color: ColoresMarca.textoSuave),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────── Examen físico ───────────────────────────

const plantillaExamenPorSistemas = '''Cabeza y cuello:
Tórax:
Cardiopulmonar:
Abdomen:
Genitourinario:
Extremidades:
Neurológico:
Piel y faneras: ''';

class FormularioExamen extends ConsumerStatefulWidget {
  const FormularioExamen({super.key});

  @override
  ConsumerState<FormularioExamen> createState() => _FormularioExamenState();
}

class _FormularioExamenState extends ConsumerState<FormularioExamen> {
  late final _hallazgos = TextEditingController(
    text: ref.read(historiaProvider).historia.examen.hallazgos,
  );

  @override
  void dispose() {
    _hallazgos.dispose();
    super.dispose();
  }

  void _insertarPlantilla() {
    final actual = _hallazgos.text.trimRight();
    _hallazgos.text = actual.isEmpty
        ? plantillaExamenPorSistemas
        : '$actual\n$plantillaExamenPorSistemas';
    ref.editarExamen((e) => e.copyWith(hallazgos: _hallazgos.text));
  }

  @override
  Widget build(BuildContext context) {
    final examen = ref.read(historiaProvider).historia.examen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampoTexto(
          etiqueta: 'Estado general',
          pista: 'Alerta, orientado, hidratado…',
          valorInicial: examen.estadoGeneral,
          alCambiar: (v) =>
              ref.editarExamen((e) => e.copyWith(estadoGeneral: v)),
        ),
        const SizedBox(height: 14),
        CampoTexto(
          etiqueta: 'Hallazgos del examen físico',
          lineas: 6,
          controller: _hallazgos,
          alCambiar: (v) => ref.editarExamen((e) => e.copyWith(hallazgos: v)),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _insertarPlantilla,
            icon: const Icon(Icons.playlist_add, size: 20),
            label: const Text('Insertar plantilla por sistemas'),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Análisis ───────────────────────────

class FormularioAnalisis extends ConsumerWidget {
  const FormularioAnalisis({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analisis = ref.read(historiaProvider).historia.analisis;
    return CampoTexto(
      etiqueta: 'Análisis',
      pista:
          'Interpretación clínica de los hallazgos, razonamiento diagnóstico, '
          'diagnósticos diferenciales…',
      lineas: 5,
      valorInicial: analisis,
      alCambiar: (v) => ref.editar((h) => h.copyWith(analisis: v)),
    );
  }
}

// ─────────────────────────── Plan ───────────────────────────

class FormularioPlan extends ConsumerWidget {
  const FormularioPlan({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.read(historiaProvider).historia.plan;
    final hoy = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampoTexto(
          etiqueta: 'Plan terapéutico',
          lineas: 3,
          valorInicial: p.planTerapeutico,
          alCambiar: (v) =>
              ref.editarPlan((p) => p.copyWith(planTerapeutico: v)),
        ),
        const SizedBox(height: 14),
        FilaCampos(
          children: [
            CampoTexto(
              etiqueta: 'Exámenes solicitados',
              lineas: 2,
              valorInicial: p.examenesSolicitados,
              alCambiar: (v) =>
                  ref.editarPlan((p) => p.copyWith(examenesSolicitados: v)),
            ),
            CampoTexto(
              etiqueta: 'Interconsultas',
              lineas: 2,
              valorInicial: p.interconsultas,
              alCambiar: (v) =>
                  ref.editarPlan((p) => p.copyWith(interconsultas: v)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        CampoTexto(
          etiqueta: 'Indicaciones y signos de alarma',
          lineas: 3,
          valorInicial: p.indicaciones,
          alCambiar: (v) => ref.editarPlan((p) => p.copyWith(indicaciones: v)),
        ),
        const SizedBox(height: 14),
        FilaCampos(
          children: [
            CampoFecha(
              etiqueta: 'Próximo control',
              valor: p.proximoControl,
              primera: DateTime(hoy.year - 1),
              alCambiar: (f) =>
                  ref.editarPlan((p) => p.copyWith(proximoControl: f)),
            ),
            const SizedBox.shrink(),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────── Firma ───────────────────────────

class FormularioFirma extends ConsumerWidget {
  const FormularioFirma({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(historiaProvider.select((e) => e.historia.firma));
    final pais = ref.watch(historiaProvider.select((e) => e.historia.pais));
    final m = ref.watch(medicoProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (m.configurado)
          _ResumenMedico(
            medico: m,
            pais: pais,
            conFirma: f.incluirFirma,
            conSello: f.incluirSello,
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ColoresMarca.aviso.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ColoresMarca.aviso.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.badge_outlined, color: ColoresMarca.aviso),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Aún no configuras tus datos de médico',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Sin ellos, la historia se imprime sin tu nombre, '
                        'registro, firma ni sello. Se configuran una sola vez.',
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: () => context.push('/medico'),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Configurar ahora'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        FilaCampos(
          children: [
            SwitchListTile(
              value: f.incluirFirma,
              contentPadding: EdgeInsets.zero,
              title: const Text('Incluir firma'),
              subtitle: m.configurado && m.firma == null
                  ? const Text('No has cargado tu firma')
                  : null,
              onChanged: (v) => ref.editar(
                (h) => h.copyWith(firma: h.firma.copyWith(incluirFirma: v)),
              ),
            ),
            SwitchListTile(
              value: f.incluirSello,
              contentPadding: EdgeInsets.zero,
              title: const Text('Incluir sello'),
              subtitle: m.configurado && m.sello == null
                  ? const Text('No has cargado tu sello')
                  : null,
              onChanged: (v) => ref.editar(
                (h) => h.copyWith(firma: h.firma.copyWith(incluirSello: v)),
              ),
            ),
          ],
        ),
        const Text(
          'La firma y el sello son imágenes: no equivalen a una firma digital '
          'certificada. VERIFICAR su validez legal.',
          style: TextStyle(fontSize: 12.5, color: ColoresMarca.textoSuave),
        ),
      ],
    );
  }
}

/// Cómo quedará el bloque de firma, con los datos del médico configurado.
class _ResumenMedico extends StatelessWidget {
  const _ResumenMedico({
    required this.medico,
    required this.pais,
    required this.conFirma,
    required this.conSello,
  });

  final Medico medico;
  final Pais pais;
  final bool conFirma;
  final bool conSello;

  @override
  Widget build(BuildContext context) {
    final m = medico;
    final firma = conFirma ? m.firma : null;
    final sello = conSello ? m.sello : null;
    const suave = TextStyle(fontSize: 13, color: ColoresMarca.textoSuave);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresMarca.borde),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 240,
            child: Column(
              children: [
                SizedBox(
                  height: 58,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (sello != null)
                        Flexible(
                          child: SizedBox(
                            width: 64,
                            height: 58,
                            child: Image.memory(
                              sello,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                      if (firma != null)
                        Flexible(
                          flex: 2,
                          child: SizedBox(
                            width: 150,
                            height: 46,
                            child: Image.memory(
                              firma,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                      if (firma == null && sello == null)
                        const Flexible(
                          child: Text(
                            '(sin firma ni sello)',
                            style: suave,
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 8, color: Colors.black87),
                Text(
                  m.nombre.trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${etiquetaRegistro(pais)} ${m.registro.trim()}',
                  textAlign: TextAlign.center,
                  style: suave,
                ),
                if (m.especialidad.trim().isNotEmpty)
                  Text(
                    m.especialidad.trim(),
                    textAlign: TextAlign.center,
                    style: suave,
                  ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => context.push('/medico'),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Editar datos del médico'),
          ),
        ],
      ),
    );
  }
}
