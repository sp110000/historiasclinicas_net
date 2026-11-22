import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/clinica/rangos.dart';
import '../../../core/consultorio/procedimientos/plantilla_procedimiento.dart';
import '../../../core/consultorio/procedimientos/valoracion.dart';
import '../../../core/consultorio/reglas/estetica.dart';
import '../../../core/pais/pais_provider.dart';
import '../../../core/pais/perfil_pais.dart' show Opcion;
import '../../../core/utils/numeros.dart';
import '../../../core/widgets/campos.dart';
import '../../medico/medico_provider.dart';
import '../estado/consultorio_provider.dart';
import '../integracion/sellado.dart';
import '../widgets/comunes.dart';

/// Valoración para un procedimiento estético con su plantilla vigente
/// (5.3): candidato, contraindicaciones, tamizajes y resultado. Se sella
/// como evolución en la historia.
class ValoracionPage extends ConsumerStatefulWidget {
  const ValoracionPage({
    super.key,
    required this.pacienteId,
    required this.plantillaId,
  });

  final String pacienteId;
  final String plantillaId;

  @override
  ConsumerState<ValoracionPage> createState() => _ValoracionPageState();
}

class _ValoracionPageState extends ConsumerState<ValoracionPage> {
  Valoracion? _v;
  DefinicionProcedimiento? _d;
  String? _bloqueo;
  String? _error;
  var _sellando = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(servicioConsultorioProvider);
    final ficha = s.indice.ficha(widget.pacienteId);
    try {
      if (ficha == null) throw StateError('No existe la ficha.');
      _v = s.procedimientos.nuevaValoracion(ficha, widget.plantillaId);
      _d = s.procedimientos.vigente(widget.plantillaId).definicion;
    } on StateError catch (e) {
      _bloqueo = e.message;
    }
  }

  void _poner(Valoracion v) => setState(() => _v = v);

  Future<void> _sellar() async {
    final v = _v!;
    final problemas = problemasValoracion(v);
    if (problemas.isNotEmpty) {
      setState(() => _error = problemas.first);
      return;
    }
    final conflicto = conflictoConHistoriaEnCurso(ref, widget.pacienteId);
    if (conflicto != null) {
      setState(() => _error = conflicto);
      return;
    }
    setState(() {
      _sellando = true;
      _error = null;
    });
    final s = ref.read(servicioConsultorioProvider);
    try {
      final (guardada, sellada) = await s.procedimientos.sellarValoracion(
        v,
        s.indice.ficha(widget.pacienteId)!,
        medico: ref.read(medicoProvider),
        pais: ref.read(paisProvider),
      );
      alSellarEnHistoria(ref, sellada);
      if (!mounted) return;
      mostrarMensaje(
        context,
        'Valoración sellada en la historia (${guardada.resultado!.etiqueta.toLowerCase()}). '
        'Se descargó ${sellada.nombreArchivo}.',
      );
      context.go('/pacientes/${widget.pacienteId}');
    } catch (e) {
      setState(() {
        _sellando = false;
        _error = mensajeDeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    final d = _d;
    final ficha = ref
        .read(servicioConsultorioProvider)
        .indice
        .ficha(widget.pacienteId);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver a la ficha',
          onPressed: () => context.go('/pacientes/${widget.pacienteId}'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          d == null ? 'Valoración' : 'Valoración · ${d.nombre}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: v == null || d == null
          ? CuerpoConsultorio(
              children: [
                Text(
                  _bloqueo ?? '',
                  style: const TextStyle(color: ColoresMarca.error),
                ),
              ],
            )
          : CuerpoConsultorio(
              children: [
                Text(
                  '${ficha?.nombreCompleto ?? ''} · ${v.edad} años · '
                  'plantilla v${v.version}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _Bloque(
                  titulo: '1 Candidato',
                  child: _Candidato(v: v, d: d, alCambiar: _poner),
                ),
                const SizedBox(height: 12),
                _Bloque(
                  titulo: '2 Contraindicaciones y precauciones',
                  child: _Respuestas(v: v, alCambiar: _poner),
                ),
                if (v.tamizajes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _Bloque(
                    titulo: '3 Tamizaje',
                    child: _Tamizajes(v: v, alCambiar: _poner),
                  ),
                ],
                const SizedBox(height: 12),
                _Bloque(
                  titulo: '${v.tamizajes.isEmpty ? 3 : 4} Resultado',
                  child: _Resultado(v: v, d: d, alCambiar: _poner),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: ColoresMarca.error),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _sellando ? null : _sellar,
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Sellar valoración en la historia'),
                  ),
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Queda como evolución sellada y se descarga la versión '
                    'nueva del PDF de la historia.',
                    style: TextStyle(
                      color: ColoresMarca.textoSuave,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

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
        Text(titulo.toUpperCase(), style: EstilosMarca.rotulo),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _Candidato extends StatelessWidget {
  const _Candidato({required this.v, required this.d, required this.alCambiar});

  final Valoracion v;
  final DefinicionProcedimiento d;
  final ValueChanged<Valoracion> alCambiar;

  @override
  Widget build(BuildContext context) {
    final imc = v.imc;
    final seleccionadas = {for (final z in v.zonas) z.zona};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RejillaCampos(
          anchoMinimo: 140,
          children: [
            CampoNumero(
              etiqueta: 'Peso',
              unidad: 'kg',
              valor: v.peso,
              rango: Rangos.peso,
              alCambiar: (x) => alCambiar(v.copyWith(peso: x)),
            ),
            CampoNumero(
              etiqueta: 'Talla',
              unidad: 'cm',
              valor: v.talla,
              rango: Rangos.talla,
              alCambiar: (x) => alCambiar(v.copyWith(talla: x)),
            ),
            ValorCalculado(
              etiqueta: 'IMC',
              valor: imc == null ? '—' : formatoNumero(imc, decimales: 1),
            ),
          ],
        ),
        for (final a in avisosValoracion(v, d))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: ColoresMarca.aviso,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    a,
                    style: const TextStyle(color: ColoresMarca.aviso),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        const Text('Zonas', style: TextStyle(color: ColoresMarca.textoSuave)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final z in d.zonas)
              FilterChip(
                label: Text(z),
                selected: seleccionadas.contains(z),
                onSelected: (si) => alCambiar(
                  v.copyWith(
                    zonas: si
                        ? [...v.zonas, ZonaValorada(zona: z)]
                        : [
                            for (final x in v.zonas)
                              if (x.zona != z) x,
                          ],
                  ),
                ),
              ),
          ],
        ),
        for (final (i, z) in v.zonas.indexed) ...[
          const SizedBox(height: 10),
          Text(z.zona, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: SelectorOpciones(
                  etiqueta: 'Grasa pinzable',
                  opciones: const [Opcion('si', 'Sí'), Opcion('no', 'No')],
                  valor: z.pinzable ? 'si' : 'no',
                  alCambiar: (x) => alCambiar(
                    v.copyWith(
                      zonas: [...v.zonas]
                        ..[i] = z.copyWith(pinzable: x == 'si'),
                    ),
                  ),
                ),
              ),
              if (z.pinzable)
                SizedBox(
                  width: 160,
                  child: CampoNumero(
                    etiqueta: 'Pinzable (${z.zona})',
                    unidad: 'cm',
                    valor: z.pinzableCm,
                    alCambiar: (x) => alCambiar(
                      v.copyWith(
                        zonas: [...v.zonas]..[i] = z.copyWith(pinzableCm: x),
                      ),
                    ),
                  ),
                ),
              SelectorOpciones(
                etiqueta: 'Elasticidad',
                opciones: [
                  for (final e in Elasticidad.values)
                    Opcion(e.name, e.etiqueta),
                ],
                valor: z.elasticidad.name,
                alCambiar: (x) => alCambiar(
                  v.copyWith(
                    zonas: [...v.zonas]
                      ..[i] = z.copyWith(
                        elasticidad: Elasticidad.values.byName(x!),
                      ),
                  ),
                ),
              ),
              SelectorOpciones(
                etiqueta: 'Flacidez (0 a 3)',
                opciones: [for (var n = 0; n <= 3; n++) Opcion('$n', '$n')],
                valor: '${z.flacidez}',
                alCambiar: (x) => alCambiar(
                  v.copyWith(
                    zonas: [...v.zonas]
                      ..[i] = z.copyWith(flacidez: int.parse(x!)),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        SelectorOpciones(
          etiqueta: 'Expectativas',
          opciones: const [
            Opcion('si', 'Realistas'),
            Opcion('no', 'No realistas'),
          ],
          valor: v.expectativasRealistas == null
              ? null
              : (v.expectativasRealistas! ? 'si' : 'no'),
          alCambiar: (x) =>
              alCambiar(v.copyWith(expectativasRealistas: x == 'si')),
        ),
        const SizedBox(height: 8),
        CampoTexto(
          etiqueta: 'Nota sobre las expectativas',
          valorInicial: v.notaExpectativas,
          alCambiar: (x) => alCambiar(v.copyWith(notaExpectativas: x)),
        ),
      ],
    );
  }
}

class _Respuestas extends StatelessWidget {
  const _Respuestas({required this.v, required this.alCambiar});

  final Valoracion v;
  final ValueChanged<Valoracion> alCambiar;

  void _poner(int i, RespuestaValoracion r) =>
      alCambiar(v.copyWith(respuestas: [...v.respuestas]..[i] = r));

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, r) in v.respuestas.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectorOpciones(
                etiqueta:
                    '${r.item.texto} · si «sí»: ${r.item.efecto.etiqueta.toLowerCase()}',
                opciones: const [Opcion('no', 'No'), Opcion('si', 'Sí')],
                valor: r.si == null ? null : (r.si! ? 'si' : 'no'),
                alCambiar: (x) => _poner(
                  i,
                  RespuestaValoracion(
                    item: r.item,
                    si: x == 'si',
                    nota: r.nota,
                  ),
                ),
              ),
              if (r.si == true) ...[
                const SizedBox(height: 6),
                CampoTexto(
                  etiqueta: r.item.efecto == EfectoItem.precaucion
                      ? 'Nota (${r.item.texto}) *'
                      : 'Nota (${r.item.texto})',
                  valorInicial: r.nota,
                  alCambiar: (x) => _poner(
                    i,
                    RespuestaValoracion(item: r.item, si: r.si, nota: x),
                  ),
                ),
              ],
            ],
          ),
        ),
    ],
  );
}

class _Tamizajes extends StatelessWidget {
  const _Tamizajes({required this.v, required this.alCambiar});

  final Valoracion v;
  final ValueChanged<Valoracion> alCambiar;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (ti, t) in v.tamizajes.indexed) ...[
        Text(
          '${t.instrumento.nombre} · ${t.texto}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: t.positivo ? ColoresMarca.aviso : null,
          ),
        ),
        Text(
          t.instrumento.referencia,
          style: const TextStyle(color: ColoresMarca.textoSuave, fontSize: 13),
        ),
        if (!t.instrumento.textosCargados)
          const Text(
            'Los textos de los ítems no se incluyen sin licencia confirmada: '
            'cárgalos en Ajustes → Procedimientos (pregunta 30).',
            style: TextStyle(color: ColoresMarca.textoSuave, fontSize: 13),
          ),
        const SizedBox(height: 6),
        for (var i = 0; i < t.instrumento.numeroItems; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SelectorOpciones(
              etiqueta: t.instrumento.textoItem(i),
              opciones: t.instrumento.maximoPorItem == 1
                  ? const [Opcion('0', 'No'), Opcion('1', 'Sí')]
                  : [
                      for (var n = 0; n <= t.instrumento.maximoPorItem; n++)
                        Opcion('$n', '$n'),
                    ],
              valor: t.respuestas[i]?.toString(),
              alCambiar: (x) {
                final rs = [...t.respuestas]..[i] = int.parse(x!);
                alCambiar(
                  v.copyWith(
                    tamizajes: [...v.tamizajes]
                      ..[ti] = TamizajeAplicado(
                        instrumento: t.instrumento,
                        respuestas: rs,
                      ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
      ],
    ],
  );
}

class _Resultado extends StatelessWidget {
  const _Resultado({required this.v, required this.d, required this.alCambiar});

  final Valoracion v;
  final DefinicionProcedimiento d;
  final ValueChanged<Valoracion> alCambiar;

  @override
  Widget build(BuildContext context) {
    final minimo = resultadoMinimo(v.respuestas);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (minimo != ResultadoValoracion.apto)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Por las contraindicaciones, como mínimo: '
              '${minimo.etiqueta.toLowerCase()}.',
              style: const TextStyle(color: ColoresMarca.error),
            ),
          ),
        SelectorOpciones(
          etiqueta: 'Resultado',
          requerido: true,
          opciones: [
            for (final r in ResultadoValoracion.values)
              if (r.rigor >= minimo.rigor) Opcion(r.name, r.etiqueta),
          ],
          valor: v.resultado?.name,
          alCambiar: (x) => alCambiar(
            v.copyWith(resultado: ResultadoValoracion.values.byName(x!)),
          ),
        ),
        if (v.resultado == ResultadoValoracion.apto)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Vale ${d.vigenciaDias} días desde hoy.',
              style: const TextStyle(color: ColoresMarca.textoSuave),
            ),
          ),
        const SizedBox(height: 10),
        CampoTexto(
          etiqueta:
              v.resultado == null || v.resultado == ResultadoValoracion.apto
              ? 'Motivo'
              : 'Motivo *',
          valorInicial: v.motivo,
          lineas: 2,
          alCambiar: (x) => alCambiar(v.copyWith(motivo: x)),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: d.recomendaciones.contains(v.recomendacion)
              ? v.recomendacion
              : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Recomendación'),
          items: [
            for (final r in d.recomendaciones)
              DropdownMenuItem(value: r, child: Text(r)),
          ],
          onChanged: (x) => alCambiar(v.copyWith(recomendacion: x ?? '')),
        ),
      ],
    );
  }
}
