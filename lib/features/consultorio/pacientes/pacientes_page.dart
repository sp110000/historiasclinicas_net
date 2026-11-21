import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/archivos/archivos.dart' as archivos;
import '../../../core/consultorio/indice/indice_pacientes.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/utils/fechas.dart';
import '../../historia/widgets/avisos.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import 'dialogo_ficha.dart';
import '../widgets/comunes.dart';
import 'importacion.dart';

/// Lista de pacientes con búsqueda y filtros.
class PacientesPage extends ConsumerStatefulWidget {
  const PacientesPage({super.key});

  @override
  ConsumerState<PacientesPage> createState() => _PacientesPageState();
}

class _PacientesPageState extends ConsumerState<PacientesPage> {
  final _busqueda = TextEditingController();
  LineaAtencion? _linea;
  FiltroUltimaAtencion? _ultima;
  final _etiquetas = <String>{};
  var _soloVencidos = false;
  var _arrastrando = false;
  late final void Function() _dejarDeEscuchar;

  @override
  void initState() {
    super.initState();
    _dejarDeEscuchar = archivos.escucharVariosSoltados(
      alSoltar: (lista) {
        final pdf = [
          for (final a in lista)
            if (a.nombre.toLowerCase().endsWith('.pdf')) a,
        ];
        if (mounted && pdf.isNotEmpty) {
          importarPdfs(context, ref, archivos: pdf);
        }
      },
      alArrastrar: (v) {
        if (mounted) setState(() => _arrastrando = v);
      },
    );
  }

  @override
  void dispose() {
    _dejarDeEscuchar();
    _busqueda.dispose();
    super.dispose();
  }

  void _abrir(FichaPaciente f) => context.go('/pacientes/${f.id}');

  Future<void> _nuevo() async {
    final f = await editarFicha(context);
    if (f != null && mounted) _abrir(f);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(versionIndiceProvider);
    final s = ref.read(servicioConsultorioProvider);
    final indice = s.indice;
    final ahora = s.reloj.ahora();
    final resultados = indice.buscar(
      texto: _busqueda.text,
      linea: _linea,
      etiquetas: _etiquetas,
      ultimaAtencion: _ultima,
      soloControlesVencidos: _soloVencidos,
    );
    final total = indice.fichasActivas.length;
    final ancho = MediaQuery.sizeOf(context).width;
    final movil = ancho < 700;
    final margen = math.max(movil ? 12.0 : 24.0, (ancho - 1100) / 2);
    final filtrando =
        _busqueda.text.trim().isNotEmpty ||
        _linea != null ||
        _ultima != null ||
        _etiquetas.isNotEmpty ||
        _soloVencidos;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          total == 0 ? 'Pacientes' : 'Pacientes · $total',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (movil)
            IconButton(
              onPressed: () => importarPdfs(context, ref),
              icon: const Icon(Icons.upload_file_outlined),
              tooltip: 'Importar PDF',
            )
          else ...[
            TextButton.icon(
              onPressed: () => importarPdfs(context, ref),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Importar PDF'),
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: _nuevo,
              icon: const Icon(Icons.person_add_alt_outlined),
              label: const Text('Paciente'),
            ),
          ],
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: movil
          ? FloatingActionButton.extended(
              onPressed: _nuevo,
              backgroundColor: ColoresMarca.primario,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_outlined),
              label: const Text('Paciente'),
            )
          : null,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(margen, 16, margen, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (indice.registrosIlegibles.isNotEmpty) ...[
                        Aviso(
                          icono: Icons.gpp_bad_outlined,
                          color: ColoresMarca.error,
                          titulo:
                              '${indice.registrosIlegibles.length} registros '
                              'del índice no se pudieron leer',
                          texto: const Text(
                            'Pueden estar dañados o alterados. Las historias '
                            'siguen en sus PDF: restaura un respaldo o vuelve '
                            'a importarlas.',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _Filtros(
                        busqueda: _busqueda,
                        linea: _linea,
                        ultima: _ultima,
                        etiquetas: _etiquetas,
                        etiquetasUsadas: indice.etiquetasUsadas,
                        soloVencidos: _soloVencidos,
                        vencidos: indice.controlesVencidos,
                        alBuscar: () => setState(() {}),
                        alEnviar: () {
                          if (resultados.isNotEmpty) {
                            _abrir(resultados.first.ficha);
                          }
                        },
                        alCambiarLinea: (v) => setState(() => _linea = v),
                        alCambiarUltima: (v) => setState(() => _ultima = v),
                        alCambiarEtiqueta: (e, si) => setState(
                          () => si ? _etiquetas.add(e) : _etiquetas.remove(e),
                        ),
                        alCambiarVencidos: (v) =>
                            setState(() => _soloVencidos = v),
                      ),
                      const SizedBox(height: 12),
                      if (filtrando && resultados.isNotEmpty)
                        Text(
                          resultados.length == 1
                              ? '1 paciente'
                              : '${resultados.length} pacientes',
                          style: const TextStyle(
                            color: ColoresMarca.textoSuave,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (resultados.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: margen),
                  sliver: SliverToBoxAdapter(
                    child: _Vacio(
                      hayPacientes: total > 0,
                      alImportar: () => importarPdfs(context, ref),
                      alCrear: _nuevo,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(margen, 0, margen, 96),
                  sliver: SliverList.builder(
                    itemCount: resultados.length,
                    itemBuilder: (context, i) => _FilaPaciente(
                      resumen: resultados[i],
                      ahora: ahora,
                      primera: i == 0,
                      ultima: i == resultados.length - 1,
                      alAbrir: () => _abrir(resultados[i].ficha),
                    ),
                  ),
                ),
            ],
          ),
          if (_arrastrando)
            const Positioned.fill(child: IgnorePointer(child: _ZonaSoltar())),
        ],
      ),
    );
  }
}

class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.busqueda,
    required this.linea,
    required this.ultima,
    required this.etiquetas,
    required this.etiquetasUsadas,
    required this.soloVencidos,
    required this.vencidos,
    required this.alBuscar,
    required this.alEnviar,
    required this.alCambiarLinea,
    required this.alCambiarUltima,
    required this.alCambiarEtiqueta,
    required this.alCambiarVencidos,
  });

  final TextEditingController busqueda;
  final LineaAtencion? linea;
  final FiltroUltimaAtencion? ultima;
  final Set<String> etiquetas;
  final List<String> etiquetasUsadas;
  final bool soloVencidos;
  final int vencidos;
  final VoidCallback alBuscar;
  final VoidCallback alEnviar;
  final ValueChanged<LineaAtencion?> alCambiarLinea;
  final ValueChanged<FiltroUltimaAtencion?> alCambiarUltima;
  final void Function(String etiqueta, bool si) alCambiarEtiqueta;
  final ValueChanged<bool> alCambiarVencidos;

  @override
  Widget build(BuildContext context) {
    final buscador = TextField(
      controller: busqueda,
      onChanged: (_) => alBuscar(),
      onSubmitted: (_) => alEnviar(),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: 'Buscar paciente',
        hintText: 'Nombre o documento',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: busqueda.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  busqueda.clear();
                  alBuscar();
                },
                icon: const Icon(Icons.close),
                tooltip: 'Borrar la búsqueda',
              ),
      ),
    );
    final lineaCampo = DropdownButtonFormField<LineaAtencion?>(
      initialValue: linea,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Línea'),
      items: [
        const DropdownMenuItem(child: Text('Todas')),
        for (final l in LineaAtencion.values)
          DropdownMenuItem(value: l, child: Text(l.etiqueta)),
      ],
      onChanged: alCambiarLinea,
    );
    final ultimaCampo = DropdownButtonFormField<FiltroUltimaAtencion?>(
      initialValue: ultima,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Última atención'),
      items: [
        const DropdownMenuItem(child: Text('Cualquiera')),
        for (final f in FiltroUltimaAtencion.values)
          DropdownMenuItem(value: f, child: Text(f.etiqueta)),
      ],
      onChanged: alCambiarUltima,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) => c.maxWidth < 640
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buscador,
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: lineaCampo),
                        const SizedBox(width: 10),
                        Expanded(child: ultimaCampo),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 5, child: buscador),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: lineaCampo),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: ultimaCampo),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            FilterChip(
              avatar: const Icon(Icons.alarm, size: 18),
              label: Text('Controles vencidos ($vencidos)'),
              selected: soloVencidos,
              onSelected: alCambiarVencidos,
            ),
            for (final e in etiquetasUsadas)
              FilterChip(
                label: Text(e),
                selected: etiquetas.contains(e),
                onSelected: (si) => alCambiarEtiqueta(e, si),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilaPaciente extends StatelessWidget {
  const _FilaPaciente({
    required this.resumen,
    required this.ahora,
    required this.primera,
    required this.ultima,
    required this.alAbrir,
  });

  final ResumenPaciente resumen;
  final DateTime ahora;
  final bool primera;
  final bool ultima;
  final VoidCallback alAbrir;

  @override
  Widget build(BuildContext context) {
    final f = resumen.ficha;
    final edad = f.edadAnios(ahora);
    final vencido = resumen.controlVencido(ahora);
    final u = resumen.ultimaAtencion;
    final detalles = [
      if (f.documentoTexto.isNotEmpty) f.documentoTexto,
      if (edad != null) '$edad años',
      if (f.lineas.isNotEmpty)
        [
          for (final l in LineaAtencion.values)
            if (f.lineas.contains(l)) l.etiqueta,
        ].join(' · '),
      if (u != null) 'Última atención ${formatoFecha(u)}',
    ];
    const radio = Radius.circular(12);
    final angosta = MediaQuery.sizeOf(context).width < 600;
    const pildora = EtiquetaEstado(
      icono: Icons.alarm,
      texto: 'Control vencido',
      color: ColoresMarca.aviso,
    );
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: ColoresMarca.borde),
        borderRadius: BorderRadius.vertical(
          top: primera ? radio : Radius.zero,
          bottom: ultima ? radio : Radius.zero,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(
            TraversalDirection.down,
          ),
          SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(
            TraversalDirection.up,
          ),
        },
        child: InkWell(
          onTap: alAbrir,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.nombreCompleto,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (detalles.isNotEmpty)
                        Text(
                          detalles.join(' · '),
                          style: const TextStyle(
                            fontSize: 13,
                            color: ColoresMarca.textoSuave,
                          ),
                        ),
                      // En pantallas angostas el nombre tiene prioridad: la
                      // píldora va debajo.
                      if (vencido && angosta) ...[
                        const SizedBox(height: 4),
                        pildora,
                      ],
                    ],
                  ),
                ),
                if (vencido && !angosta) ...[const SizedBox(width: 8), pildora],
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: ColoresMarca.textoSuave),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({
    required this.hayPacientes,
    required this.alImportar,
    required this.alCrear,
  });

  final bool hayPacientes;
  final VoidCallback alImportar;
  final VoidCallback alCrear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RadiosMarca.tarjeta,
        border: Border.all(color: ColoresMarca.borde),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.people_outline,
            size: 40,
            color: ColoresMarca.textoSuave,
          ),
          const SizedBox(height: 10),
          Text(
            hayPacientes
                ? 'Ningún paciente coincide con la búsqueda.'
                : 'Todavía no hay pacientes.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (!hayPacientes) ...[
            const SizedBox(height: 6),
            const Text(
              'Se agregan solos cuando guardas o abres una historia. También '
              'puedes importar en lote los PDF que ya tienes, o soltarlos '
              'aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ColoresMarca.textoSuave),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: alImportar,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Importar PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: alCrear,
                  icon: const Icon(Icons.person_add_alt_outlined),
                  label: const Text('Paciente nuevo'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ZonaSoltar extends StatelessWidget {
  const _ZonaSoltar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ColoresMarca.primario.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: RadiosMarca.tarjeta,
          border: Border.all(color: ColoresMarca.primario, width: 2),
        ),
        child: const Text(
          'Suelta los PDF para importarlos',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: ColoresMarca.primario,
          ),
        ),
      ),
    );
  }
}
