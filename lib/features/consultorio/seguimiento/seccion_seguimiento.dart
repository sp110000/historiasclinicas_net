import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/consultorio/modelos/medicion.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/utils/numeros.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';
import 'dialogo_medicion.dart';
import 'grafica_seguimiento.dart';
import 'informe.dart';
import 'medidas_eco.dart';

/// Qué se grafica.
enum SerieSeguimiento {
  peso('Peso', 'kg', null),
  imc('IMC', 'kg/m²', 1),
  cintura('Cintura', 'cm', null),
  icc('ICC', '', 2);

  const SerieSeguimiento(this.etiqueta, this.unidad, this.decimales);

  final String etiqueta;
  final String unidad;
  final int? decimales;

  double? de(Medicion m) => switch (this) {
    peso => m.peso,
    imc => m.imc,
    cintura => m.cintura,
    icc => m.icc,
  };
}

/// Seguimiento antropométrico de la ficha: cambios, gráfica y tabla.
class SeccionSeguimiento extends ConsumerStatefulWidget {
  const SeccionSeguimiento({super.key, required this.ficha, this.acciones});

  final FichaPaciente ficha;

  /// Botones extra (p. ej. el informe de seguimiento).
  final List<Widget>? acciones;

  @override
  ConsumerState<SeccionSeguimiento> createState() => _SeccionSeguimientoState();
}

class _SeccionSeguimientoState extends ConsumerState<SeccionSeguimiento> {
  var _serie = SerieSeguimiento.peso;

  @override
  Widget build(BuildContext context) {
    ref.watch(versionIndiceProvider);
    final servicio = ref.read(servicioConsultorioProvider);
    final mediciones = servicio.seguimiento.medicionesDe(widget.ficha.id);
    final programa = servicio.peso.programaDe(widget.ficha.id);
    final puntos = [
      for (final m in mediciones)
        if (_serie.de(m) case final v?) (fecha: m.fecha, valor: v),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () =>
                  editarMedicion(context, pacienteId: widget.ficha.id),
              icon: const Icon(Icons.add),
              label: const Text('Medición'),
            ),
            if (mediciones.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => descargarInformeSeguimiento(
                  context,
                  ref,
                  ficha: widget.ficha,
                ),
                icon: const Icon(Icons.summarize_outlined),
                label: const Text('Informe de seguimiento'),
              ),
            ...?widget.acciones,
          ],
        ),
        const SizedBox(height: 12),
        if (mediciones.isEmpty)
          const Text(
            'Sin mediciones todavía. También aparecen aquí el peso, la talla, '
            'la cintura y la PA que quedaron en las historias.',
            style: TextStyle(color: ColoresMarca.textoSuave),
          )
        else ...[
          _Cambios(mediciones: mediciones),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: RadiosMarca.tarjeta,
              border: Border.all(color: ColoresMarca.borde),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final s in SerieSeguimiento.values)
                      ChoiceChip(
                        label: Text(s.etiqueta),
                        selected: _serie == s,
                        onSelected: (_) => setState(() => _serie = s),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                GraficaSeguimiento(
                  puntos: puntos,
                  nombre: _serie.etiqueta,
                  unidad: _serie.unidad,
                  decimales: _serie.decimales,
                  // Meta del programa de peso (pregunta 27), si la hay.
                  meta: switch (_serie) {
                    SerieSeguimiento.peso => programa?.metaPeso,
                    SerieSeguimiento.cintura => programa?.metaCintura,
                    _ => null,
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Tabla(mediciones: mediciones.reversed.toList()),
        ],
        MedidasEcografia(pacienteId: widget.ficha.id),
      ],
    );
  }
}

class _Cambios extends StatelessWidget {
  const _Cambios({required this.mediciones});

  final List<Medicion> mediciones;

  @override
  Widget build(BuildContext context) {
    String n(double v, int? d) => formatoNumero(v, decimales: d);
    final pildoras = <Widget>[];
    for (final s in SerieSeguimiento.values) {
      final c = cambioEn(mediciones, s.de);
      if (c == null) continue;
      final signo = c.porcentaje > 0 ? '+' : '';
      pildoras.add(
        EtiquetaEstado(
          icono: c.ultima <= c.primera
              ? Icons.trending_down
              : Icons.trending_up,
          texto:
              '${s.etiqueta} ${n(c.primera, s.decimales)} → '
              '${n(c.ultima, s.decimales)}'
              '${s.unidad.isEmpty ? '' : ' ${s.unidad}'} '
              '($signo${formatoNumero(c.porcentaje, decimales: 1)} %)',
          color: ColoresMarca.primario,
        ),
      );
    }
    if (pildoras.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 6, children: pildoras);
  }
}

class _Tabla extends StatelessWidget {
  const _Tabla({required this.mediciones});

  final List<Medicion> mediciones;

  @override
  Widget build(BuildContext context) {
    String v(double? x, [int? d]) =>
        x == null ? '—' : formatoNumero(x, decimales: d);
    String par(double? d, double? i) =>
        d == null && i == null ? '—' : '${v(d)}/${v(i)}';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RadiosMarca.tarjeta,
        border: Border.all(color: ColoresMarca.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            color: ColoresMarca.tintaSuave,
            fontSize: 13,
          ),
          columnSpacing: 18,
          columns: const [
            DataColumn(label: Text('Fecha')),
            DataColumn(label: Text('Peso'), numeric: true),
            DataColumn(label: Text('Talla'), numeric: true),
            DataColumn(label: Text('IMC'), numeric: true),
            DataColumn(label: Text('Cintura'), numeric: true),
            DataColumn(label: Text('Cadera'), numeric: true),
            DataColumn(label: Text('ICC'), numeric: true),
            DataColumn(label: Text('Abdomen'), numeric: true),
            DataColumn(label: Text('Flanco D/I')),
            DataColumn(label: Text('Muslo D/I')),
            DataColumn(label: Text('Brazo D/I')),
            DataColumn(label: Text('PA')),
            DataColumn(label: Text('% grasa'), numeric: true),
            DataColumn(label: Text('Origen')),
          ],
          rows: [
            for (final m in mediciones)
              DataRow(
                onSelectChanged: m.editable
                    ? (_) => editarMedicion(
                        context,
                        pacienteId: m.pacienteId,
                        medicion: m,
                      )
                    : null,
                cells: [
                  DataCell(Text(formatoFecha(m.fecha))),
                  DataCell(Text(v(m.peso))),
                  DataCell(Text(v(m.talla))),
                  DataCell(Text(v(m.imc, 1))),
                  DataCell(Text(v(m.cintura))),
                  DataCell(Text(v(m.cadera))),
                  DataCell(Text(v(m.icc, 2))),
                  DataCell(Text(v(m.abdomen))),
                  DataCell(Text(par(m.flancoDerecho, m.flancoIzquierdo))),
                  DataCell(Text(par(m.musloDerecho, m.musloIzquierdo))),
                  DataCell(Text(par(m.brazoDerecho, m.brazoIzquierdo))),
                  DataCell(
                    Text(
                      m.paSistolica == null || m.paDiastolica == null
                          ? '—'
                          : '${v(m.paSistolica)}/${v(m.paDiastolica)}',
                    ),
                  ),
                  DataCell(Text(v(m.grasa))),
                  DataCell(
                    Text(
                      m.editable ? 'Medición' : m.fuente,
                      style: const TextStyle(color: ColoresMarca.textoSuave),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
