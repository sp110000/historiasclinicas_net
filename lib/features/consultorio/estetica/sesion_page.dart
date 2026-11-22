import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/clinica/rangos.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/consultorio/procedimientos/plantilla_procedimiento.dart';
import '../../../core/consultorio/procedimientos/sesion.dart';
import '../../../core/consultorio/reglas/estetica.dart';
import '../../../core/consultorio/reglas/sesion.dart';
import '../../../core/pais/pais_provider.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/utils/numeros.dart';
import '../../../core/widgets/campos.dart';
import '../../medico/medico_provider.dart';
import '../estado/consultorio_provider.dart';
import '../integracion/sellado.dart';
import '../widgets/comunes.dart';
import 'seccion_estetica.dart' show etiquetaValoracion;

/// Registro de una sesión del procedimiento (5.3, pregunta 35): verificación
/// previa, zonas, solución, anestésico con la dosis en mg/kg, equipo,
/// insumos y cierre. Si algo bloquea, el botón dice por qué.
class SesionPage extends ConsumerStatefulWidget {
  const SesionPage({
    super.key,
    required this.pacienteId,
    required this.plantillaId,
  });

  final String pacienteId;
  final String plantillaId;

  @override
  ConsumerState<SesionPage> createState() => _SesionPageState();
}

class _SesionPageState extends ConsumerState<SesionPage> {
  Sesion? _s;
  DefinicionProcedimiento? _d;
  String? _sinPlantilla;
  var _registrarPeso = false;
  var _sellando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = ref.read(servicioConsultorioProvider);
    final ficha = s.indice.ficha(widget.pacienteId);
    try {
      if (ficha == null) throw StateError('No existe la ficha.');
      _s = s.procedimientos.nuevaSesion(ficha, widget.plantillaId);
      _d = s.procedimientos.vigente(widget.plantillaId).definicion;
    } on StateError catch (e) {
      _sinPlantilla = e.message;
    }
  }

  void _poner(Sesion s) => setState(() => _s = s);

  FichaPaciente get _ficha =>
      ref.read(servicioConsultorioProvider).indice.ficha(widget.pacienteId)!;

  Future<void> _sellar() async {
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
      final (guardada, sellada) = await s.procedimientos.sellarSesion(
        _s!,
        _ficha,
        medico: ref.read(medicoProvider),
        pais: ref.read(paisProvider),
        registrarPeso: _registrarPeso,
      );
      alSellarEnHistoria(ref, sellada);
      if (!mounted) return;
      mostrarMensaje(
        context,
        '${guardada.titulo} sellada en la historia. Se descargó '
        '${sellada.nombreArchivo}.',
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
    final s = _s;
    final d = _d;
    final servicio = ref.read(servicioConsultorioProvider);
    final e = s == null ? null : servicio.procedimientos.evaluar(s, _ficha);
    final angosta = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver a la ficha',
          onPressed: () => context.go('/pacientes/${widget.pacienteId}'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          s == null || d == null ? 'Sesión' : '${s.titulo} · ${d.nombre}',
          style: const TextStyle(fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      bottomNavigationBar: s == null || e == null
          ? null
          : _BarraSellar(
              evaluacion: e,
              error: _error,
              sellando: _sellando,
              alSellar: _sellar,
            ),
      body: s == null || d == null
          ? CuerpoConsultorio(
              children: [
                Text(
                  _sinPlantilla ?? '',
                  style: const TextStyle(color: ColoresMarca.error),
                ),
              ],
            )
          : CuerpoConsultorio(
              children: [
                _Estado(s: s, ficha: _ficha, familia: d.familia),
                if (e!.avisos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final a in e.avisos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                ],
                const SizedBox(height: 12),
                _Seccion(
                  angosta: angosta,
                  abierta: true,
                  titulo:
                      'Verificación previa '
                      '${s.verificacion.values.where((v) => v).length}/'
                      '${s.verificacion.length}',
                  children: [
                    for (final i in s.verificacion.keys)
                      CheckboxListTile(
                        value: s.verificacion[i],
                        onChanged: (v) => _poner(
                          s.copyWith(
                            verificacion: {...s.verificacion, i: v ?? false},
                          ),
                        ),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(i),
                      ),
                  ],
                ),
                _Seccion(
                  angosta: angosta,
                  titulo:
                      'Zonas · ${formatoNumero(s.volumenTotalMl)} mL'
                      '${d.volumenMaximoSesionMl == null ? '' : ' de ${formatoNumero(d.volumenMaximoSesionMl!)}'}',
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final z in d.zonas)
                          FilterChip(
                            label: Text(z),
                            selected: s.zonas.any((x) => x.zona == z),
                            onSelected: (si) => _poner(
                              s.copyWith(
                                zonas: si
                                    ? [...s.zonas, ZonaSesion(zona: z)]
                                    : [
                                        for (final x in s.zonas)
                                          if (x.zona != z) x,
                                      ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    for (final (i, z) in s.zonas.indexed)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: CampoNumero(
                          key: ValueKey('zona${z.zona}'),
                          etiqueta: 'Volumen (${z.zona})',
                          unidad: 'mL',
                          valor: z.volumenMl,
                          alCambiar: (v) => _poner(
                            s.copyWith(
                              zonas: [...s.zonas]
                                ..[i] = ZonaSesion(zona: z.zona, volumenMl: v),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (s.componentes.isNotEmpty)
                  _Seccion(
                    angosta: angosta,
                    titulo: 'Solución',
                    children: [
                      for (final (i, c) in s.componentes.indexed)
                        _CampoLote(
                          nombre: c.nombre,
                          lote: c.lote,
                          alCambiar: (l) => _poner(
                            s.copyWith(
                              componentes: [...s.componentes]
                                ..[i] = ComponenteSesion(
                                  nombre: c.nombre,
                                  lote: l,
                                ),
                            ),
                          ),
                        ),
                    ],
                  ),
                _Seccion(
                  angosta: angosta,
                  titulo: 'Anestésico',
                  children: [
                    _Anestesico(
                      s: s,
                      d: d,
                      hoy: servicio.reloj.ahora(),
                      alCambiar: _poner,
                      alPesarHoy: (p) {
                        final a = servicio.reloj.ahora();
                        _registrarPeso = p != null;
                        _poner(
                          s.copyWith(
                            pesoKg: p,
                            fechaPeso: p == null
                                ? null
                                : DateTime(a.year, a.month, a.day),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                _Seccion(
                  angosta: angosta,
                  titulo: 'Equipo',
                  children: [
                    RejillaCampos(
                      anchoMinimo: 180,
                      children: [
                        CampoTexto(
                          etiqueta: 'Equipo',
                          valorInicial: s.equipo.nombre,
                          alCambiar: (v) => _poner(
                            s.copyWith(
                              equipo: EquipoSesion(
                                nombre: v,
                                serie: s.equipo.serie,
                                registroInvima: s.equipo.registroInvima,
                                parametros: s.equipo.parametros,
                              ),
                            ),
                          ),
                        ),
                        CampoTexto(
                          etiqueta: 'Serie',
                          valorInicial: s.equipo.serie,
                          alCambiar: (v) => _poner(
                            s.copyWith(
                              equipo: EquipoSesion(
                                nombre: s.equipo.nombre,
                                serie: v,
                                registroInvima: s.equipo.registroInvima,
                                parametros: s.equipo.parametros,
                              ),
                            ),
                          ),
                        ),
                        CampoTexto(
                          etiqueta: 'Registro Invima del equipo',
                          valorInicial: s.equipo.registroInvima,
                          alCambiar: (v) => _poner(
                            s.copyWith(
                              equipo: EquipoSesion(
                                nombre: s.equipo.nombre,
                                serie: s.equipo.serie,
                                registroInvima: v,
                                parametros: s.equipo.parametros,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    CampoTexto(
                      etiqueta: 'Parámetros',
                      valorInicial: s.equipo.parametros,
                      alCambiar: (v) => _poner(
                        s.copyWith(
                          equipo: EquipoSesion(
                            nombre: s.equipo.nombre,
                            serie: s.equipo.serie,
                            registroInvima: s.equipo.registroInvima,
                            parametros: v,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                _Seccion(
                  angosta: angosta,
                  titulo: 'Insumos',
                  children: [
                    for (final (i, x) in s.insumos.indexed)
                      _Insumo(
                        key: ValueKey('insumo$i${s.insumos.length}'),
                        insumo: x,
                        alCambiar: (n) => _poner(
                          s.copyWith(insumos: [...s.insumos]..[i] = n),
                        ),
                        alQuitar: () => _poner(
                          s.copyWith(insumos: [...s.insumos]..removeAt(i)),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _poner(
                          s.copyWith(
                            insumos: [
                              ...s.insumos,
                              const InsumoSesion(nombre: ''),
                            ],
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar insumo'),
                      ),
                    ),
                    const Text(
                      'El enlace con el inventario (descontar al sellar) llega '
                      'en la 5.7.',
                      style: TextStyle(
                        color: ColoresMarca.textoSuave,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                _Seccion(
                  angosta: angosta,
                  titulo: 'Cierre',
                  children: [
                    RejillaCampos(
                      anchoMinimo: 180,
                      children: [
                        CampoNumero(
                          etiqueta: 'Duración',
                          unidad: 'min',
                          decimales: false,
                          valor: s.duracionMin?.toDouble(),
                          alCambiar: (v) =>
                              _poner(s.copyWith(duracionMin: v?.round())),
                        ),
                        CampoFecha(
                          etiqueta: 'Control',
                          valor: s.control,
                          primera: DateTime(2000),
                          ultima: DateTime(2100),
                          alCambiar: (f) => _poner(s.copyWith(control: f)),
                        ),
                      ],
                    ),
                    CampoTexto(
                      etiqueta: 'Eventos adversos',
                      valorInicial: s.eventosAdversos,
                      alCambiar: (v) => _poner(s.copyWith(eventosAdversos: v)),
                    ),
                    CampoTexto(
                      etiqueta: 'Indicaciones posteriores',
                      valorInicial: s.indicaciones,
                      lineas: 4,
                      alCambiar: (v) => _poner(s.copyWith(indicaciones: v)),
                    ),
                    if (s.poliza.isNotEmpty)
                      Text(
                        'Póliza: ${s.poliza}',
                        style: const TextStyle(color: ColoresMarca.textoSuave),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _Estado extends ConsumerWidget {
  const _Estado({required this.s, required this.ficha, required this.familia});

  final Sesion s;
  final FichaPaciente ficha;
  final String familia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicio = ref.read(servicioConsultorioProvider);
    final p = servicio.procedimientos;
    final ahora = servicio.reloj.ahora();
    final edad = bloqueoPorEdad(ficha, ahora);
    final valoracion = ultimaValoracion(
      p.valoracionesDe(ficha.id),
      s.plantillaId,
    );
    final consentimiento = p.consentimientoVigente(ficha.id, s.plantillaId);
    final certificacion = p.certificacionVigente(familia);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Text(
          ficha.nombreCompleto,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        edad == null
            ? const EtiquetaEstado(
                icono: Icons.check,
                texto: 'Mayor de edad',
                color: ColoresMarca.estadoOk,
              )
            : const EtiquetaEstado(
                icono: Icons.block_outlined,
                texto: 'Edad sin comprobar o menor',
                color: ColoresMarca.error,
              ),
        etiquetaValoracion(valoracion, ahora),
        consentimiento == null
            ? const EtiquetaEstado(
                icono: Icons.block_outlined,
                texto: 'Sin consentimiento',
                color: ColoresMarca.error,
              )
            : EtiquetaEstado(
                icono: Icons.check,
                texto: 'Consentimiento ${consentimiento.numero}',
                color: ColoresMarca.estadoOk,
              ),
        certificacion == null
            ? const EtiquetaEstado(
                icono: Icons.warning_amber_rounded,
                texto: 'Sin certificación registrada',
                color: ColoresMarca.aviso,
              )
            : const EtiquetaEstado(
                icono: Icons.workspace_premium_outlined,
                texto: 'Certificación vigente',
                color: ColoresMarca.estadoOk,
              ),
      ],
    );
  }
}

/// Una sección: tarjeta en pantallas anchas; plegable en las angostas
/// (pregunta 35, boceto de 320 px).
class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.angosta,
    required this.titulo,
    required this.children,
    this.abierta = false,
  });

  final bool angosta;
  final String titulo;
  final List<Widget> children;
  final bool abierta;

  @override
  Widget build(BuildContext context) {
    final contenido = [
      for (final c in children) ...[c, const SizedBox(height: 10)],
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: angosta ? 2 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RadiosMarca.tarjeta,
        border: Border.all(color: ColoresMarca.borde),
      ),
      child: angosta
          ? ExpansionTile(
              initiallyExpanded: abierta,
              tilePadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(titulo.toUpperCase(), style: EstilosMarca.rotulo),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: contenido,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(titulo.toUpperCase(), style: EstilosMarca.rotulo),
                const SizedBox(height: 10),
                ...contenido,
              ],
            ),
    );
  }
}

class _CampoLote extends StatelessWidget {
  const _CampoLote({
    required this.nombre,
    required this.lote,
    required this.alCambiar,
  });

  final String nombre;
  final LoteSesion lote;
  final ValueChanged<LoteSesion> alCambiar;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      RejillaCampos(
        anchoMinimo: 160,
        children: [
          CampoTexto(
            etiqueta: 'Lote ($nombre)',
            valorInicial: lote.lote,
            mayusculas: TextCapitalization.characters,
            alCambiar: (v) => alCambiar(LoteSesion(lote: v, vence: lote.vence)),
          ),
          CampoFecha(
            etiqueta: 'Vence ($nombre)',
            valor: lote.vence,
            primera: DateTime(2000),
            ultima: DateTime(2100),
            alCambiar: (f) => alCambiar(LoteSesion(lote: lote.lote, vence: f)),
          ),
        ],
      ),
    ],
  );
}

class _Anestesico extends StatelessWidget {
  const _Anestesico({
    required this.s,
    required this.d,
    required this.hoy,
    required this.alCambiar,
    required this.alPesarHoy,
  });

  final Sesion s;
  final DefinicionProcedimiento d;
  final DateTime hoy;
  final ValueChanged<Sesion> alCambiar;
  final ValueChanged<double?> alPesarHoy;

  @override
  Widget build(BuildContext context) {
    final a = s.anestesico;
    final opciones = [
      for (final x in d.anestesicos)
        if (x.completo) x,
    ];
    final fraccion = a?.fraccion(s.pesoKg);
    final color = fraccion == null
        ? ColoresMarca.textoSuave
        : fraccion > 1
        ? ColoresMarca.error
        : fraccion >= avisoDosis
        ? ColoresMarca.aviso
        : ColoresMarca.estadoOk;
    final pesoViejo =
        s.fechaPeso == null ||
        DateTime(hoy.year, hoy.month, hoy.day).difference(s.fechaPeso!).inDays >
            diasVigenciaPeso;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: a?.nombre,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Anestésico'),
          items: [
            for (final x in opciones)
              DropdownMenuItem(
                value: x.nombre,
                child: Text(
                  '${x.nombre} · ${formatoNumero(x.concentracionMgMl!)} mg/mL',
                ),
              ),
          ],
          onChanged: (v) {
            final x = opciones.firstWhere((o) => o.nombre == v);
            alCambiar(
              s.copyWith(
                anestesico: AnestesicoSesion(
                  nombre: x.nombre,
                  concentracionMgMl: x.concentracionMgMl!,
                  maximoMgKg: x.maximoMgKg!,
                  volumenMl: a?.volumenMl,
                  lote: a?.lote ?? const LoteSesion(),
                ),
              ),
            );
          },
        ),
        if (a != null) ...[
          const SizedBox(height: 10),
          CampoNumero(
            etiqueta: 'Volumen del anestésico',
            unidad: 'mL',
            valor: a.volumenMl,
            alCambiar: (v) =>
                alCambiar(s.copyWith(anestesico: a.copyWith(volumenMl: v))),
          ),
          const SizedBox(height: 10),
          _CampoLote(
            nombre: a.nombre,
            lote: a.lote,
            alCambiar: (l) =>
                alCambiar(s.copyWith(anestesico: a.copyWith(lote: l))),
          ),
          const SizedBox(height: 10),
          Text(
            s.pesoKg == null
                ? 'Sin peso registrado.'
                : 'Peso ${formatoNumero(s.pesoKg!)} kg del '
                      '${formatoFecha(s.fechaPeso!)}.',
            style: const TextStyle(color: ColoresMarca.textoSuave),
          ),
          if (pesoViejo) ...[
            const SizedBox(height: 6),
            CampoNumero(
              etiqueta: 'Peso de hoy',
              unidad: 'kg',
              valor: null,
              rango: Rangos.peso,
              alCambiar: alPesarHoy,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '→ ${textoDosis(a, s.pesoKg).isEmpty ? '—' : textoDosis(a, s.pesoKg)}'
            ' · máximo del protocolo ${formatoNumero(a.maximoMgKg)} mg/kg'
            '${fraccion == null ? '' : ' (${(fraccion * 100).round()} %)'}',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

class _Insumo extends StatelessWidget {
  const _Insumo({
    super.key,
    required this.insumo,
    required this.alCambiar,
    required this.alQuitar,
  });

  final InsumoSesion insumo;
  final ValueChanged<InsumoSesion> alCambiar;
  final VoidCallback alQuitar;

  @override
  Widget build(BuildContext context) {
    final x = insumo;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RejillaCampos(
            anchoMinimo: 150,
            children: [
              CampoTexto(
                etiqueta: 'Insumo',
                valorInicial: x.nombre,
                alCambiar: (v) => alCambiar(
                  InsumoSesion(nombre: v, cantidad: x.cantidad, lote: x.lote),
                ),
              ),
              CampoNumero(
                etiqueta: 'Cantidad',
                valor: x.cantidad,
                alCambiar: (v) => alCambiar(
                  InsumoSesion(
                    nombre: x.nombre,
                    cantidad: v ?? 1,
                    lote: x.lote,
                  ),
                ),
              ),
              CampoTexto(
                etiqueta: 'Lote del insumo',
                valorInicial: x.lote.lote,
                mayusculas: TextCapitalization.characters,
                alCambiar: (v) => alCambiar(
                  InsumoSesion(
                    nombre: x.nombre,
                    cantidad: x.cantidad,
                    lote: LoteSesion(lote: v, vence: x.lote.vence),
                  ),
                ),
              ),
              CampoFecha(
                etiqueta: 'Vence el insumo',
                valor: x.lote.vence,
                primera: DateTime(2000),
                ultima: DateTime(2100),
                alCambiar: (f) => alCambiar(
                  InsumoSesion(
                    nombre: x.nombre,
                    cantidad: x.cantidad,
                    lote: LoteSesion(lote: x.lote.lote, vence: f),
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Quitar el insumo',
          onPressed: alQuitar,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

/// Botón de sellar fijo abajo, con el motivo del primer bloqueo encima.
class _BarraSellar extends StatelessWidget {
  const _BarraSellar({
    required this.evaluacion,
    required this.error,
    required this.sellando,
    required this.alSellar,
  });

  final EvaluacionSesion evaluacion;
  final String? error;
  final bool sellando;
  final VoidCallback alSellar;

  @override
  Widget build(BuildContext context) {
    final motivo = error ?? evaluacion.bloqueos.firstOrNull;
    return Material(
      color: Colors.white,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  motivo ??
                      (evaluacion.avisos.isEmpty
                          ? 'Lista para sellar.'
                          : 'Lista para sellar, con '
                                '${evaluacion.avisos.length} '
                                '${evaluacion.avisos.length == 1 ? 'aviso' : 'avisos'}.'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: motivo == null
                        ? ColoresMarca.estadoOk
                        : ColoresMarca.error,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: sellando || !evaluacion.permiteSellar
                    ? null
                    : alSellar,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Sellar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
