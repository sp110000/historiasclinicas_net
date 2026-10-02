import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/clinica/rangos.dart';
import '../../../core/integridad/cadena_hash.dart';
import '../../../core/models/historia.dart';
import '../../../core/presentacion/datos_historia.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/campos.dart';
import '../estado/historia_controller.dart';

const plantillaSoap = 'S: \nO: \nA: \nP: ';

class SeccionEvoluciones extends ConsumerWidget {
  const SeccionEvoluciones({super.key, required this.alAgregar});

  /// Agrega una evolución (la página confirma antes si hay alteraciones).
  final VoidCallback alAgregar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(historiaProvider);
    if (!e.abierta) {
      return const _Nota(
        icono: Icons.info_outline,
        texto:
            'Las evoluciones se agregan al final, después de finalizar la '
            'historia: en esta misma sesión o al reabrir su PDF otro día. Cada '
            'una lleva fecha y hora, y las anteriores nunca se editan ni se '
            'borran.',
      );
    }
    final alterada = e.integridad?.primeraAlterada;
    final selladas = e.evolucionesSelladas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selladas.isEmpty && e.evolucionesNuevas.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Aún no hay evoluciones.',
              style: TextStyle(color: ColoresMarca.textoSuave),
            ),
          ),
        for (final (i, ev) in selladas.indexed)
          _EvolucionSellada(
            numero: i + 1,
            evolucion: ev,
            noCoincide: alterada != null && alterada > 0 && i + 1 >= alterada,
          ),
        for (final (i, ev) in e.evolucionesNuevas.indexed)
          _EditorEvolucion(
            key: ValueKey('${ev.id}-${e.versionFormulario}'),
            id: ev.id,
            numero: selladas.length + i + 1,
          ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: alAgregar,
            icon: const Icon(Icons.add),
            label: const Text('Agregar evolución'),
          ),
        ),
      ],
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, color: ColoresMarca.textoSuave, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(color: ColoresMarca.textoSuave),
          ),
        ),
      ],
    );
  }
}

class _EvolucionSellada extends StatelessWidget {
  const _EvolucionSellada({
    required this.numero,
    required this.evolucion,
    required this.noCoincide,
  });

  final int numero;
  final Evolucion evolucion;
  final bool noCoincide;

  @override
  Widget build(BuildContext context) {
    final ev = evolucion;
    final signos = resumenSignos(ev.signos);
    final colorBorde = noCoincide
        ? ColoresMarca.error
        : ColoresMarca.textoSuave;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: ColoresMarca.bloqueado,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: colorBorde, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Evolución $numero · ${formatoFechaHora(ev.fechaHora)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              _Chip(
                icono: noCoincide ? Icons.gpp_bad_outlined : Icons.lock_outline,
                texto: noCoincide
                    ? 'No coincide'
                    : 'sellada${ev.hash == null ? '' : ' · ${huella(ev.hash!)}'}',
                color: noCoincide
                    ? ColoresMarca.error
                    : ColoresMarca.textoSuave,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(ev.texto, style: const TextStyle(height: 1.45)),
          if (signos.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              signos,
              style: const TextStyle(
                fontSize: 13,
                color: ColoresMarca.textoSuave,
              ),
            ),
          ],
          if (ev.avisoIntegridad != null) ...[
            const SizedBox(height: 6),
            Text(
              ev.avisoIntegridad!,
              style: const TextStyle(fontSize: 12.5, color: ColoresMarca.aviso),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icono, required this.texto, required this.color});

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorEvolucion extends ConsumerStatefulWidget {
  const _EditorEvolucion({super.key, required this.id, required this.numero});

  final String id;
  final int numero;

  @override
  ConsumerState<_EditorEvolucion> createState() => _EditorEvolucionState();
}

class _EditorEvolucionState extends ConsumerState<_EditorEvolucion> {
  late final Evolucion _inicial = _buscar(
    ref.read(historiaProvider).evolucionesNuevas,
  )!;
  late final _texto = TextEditingController(text: _inicial.texto);
  late bool _conSignos = !_inicial.signos.vacio;

  Evolucion? _buscar(List<Evolucion> lista) {
    for (final e in lista) {
      if (e.id == widget.id) return e;
    }
    return null;
  }

  int get _indice => ref
      .read(historiaProvider)
      .evolucionesNuevas
      .indexWhere((e) => e.id == widget.id);

  void _editar(Evolucion Function(Evolucion e) cambio) {
    final i = _indice;
    if (i < 0) return;
    final lista = ref.read(historiaProvider).evolucionesNuevas;
    ref
        .read(historiaProvider.notifier)
        .actualizarEvolucion(i, cambio(lista[i]));
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _insertarSoap() {
    final actual = _texto.text.trimRight();
    _texto.text = actual.isEmpty ? plantillaSoap : '$actual\n$plantillaSoap';
    _editar((e) => e.copyWith(texto: _texto.text));
  }

  Future<void> _descartar() async {
    if (_texto.text.trim().isNotEmpty) {
      final si = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Descartar esta evolución?'),
          content: const Text(
            'Todavía no está guardada: se perderá lo escrito.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (si != true) return;
    }
    final i = _indice;
    if (i >= 0) ref.read(historiaProvider.notifier).descartarEvolucion(i);
  }

  @override
  Widget build(BuildContext context) {
    final ev =
        ref.watch(
          historiaProvider.select((e) => _buscar(e.evolucionesNuevas)),
        ) ??
        _inicial;
    final s = ev.signos;
    Widget numero(
      String etiqueta,
      double? valor,
      String unidad,
      RangoSigno rango,
      SignosVitales Function(SignosVitales, double?) cambio,
    ) => CampoNumero(
      etiqueta: etiqueta,
      valor: valor,
      unidad: unidad,
      rango: rango,
      alCambiar: (v) => _editar((e) => e.copyWith(signos: cambio(e.signos, v))),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8FB),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: ColoresMarca.primario, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note, color: ColoresMarca.primario),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Evolución ${widget.numero} · nueva',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(
                        text: '  se sellará al descargar la historia',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: ColoresMarca.primario,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _descartar,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Descartar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilaCampos(
            anchoMinimo: 420,
            children: [
              CampoFecha(
                etiqueta: 'Fecha',
                valor: ev.fechaHora,
                requerido: true,
                alCambiar: (f) {
                  if (f == null) return;
                  _editar(
                    (e) => e.copyWith(
                      fechaHora: DateTime(
                        f.year,
                        f.month,
                        f.day,
                        e.fechaHora.hour,
                        e.fechaHora.minute,
                      ),
                    ),
                  );
                },
              ),
              CampoHora(
                etiqueta: 'Hora',
                hora: ev.fechaHora.hour,
                minuto: ev.fechaHora.minute,
                alCambiar: (h, m) => _editar(
                  (e) => e.copyWith(
                    fechaHora: DateTime(
                      e.fechaHora.year,
                      e.fechaHora.month,
                      e.fechaHora.day,
                      h,
                      m,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CampoTexto(
            etiqueta: 'Nueva evolución',
            pista: 'Evolución del paciente, hallazgos y conducta…',
            requerido: true,
            lineas: 4,
            controller: _texto,
            alCambiar: (v) => _editar((e) => e.copyWith(texto: v)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _insertarSoap,
                icon: const Icon(Icons.playlist_add, size: 20),
                label: const Text('Plantilla SOAP'),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _conSignos = !_conSignos),
                icon: Icon(
                  _conSignos ? Icons.remove : Icons.monitor_heart_outlined,
                  size: 20,
                ),
                label: Text(
                  _conSignos
                      ? 'Ocultar signos vitales'
                      : 'Agregar signos vitales',
                ),
              ),
            ],
          ),
          if (_conSignos) ...[
            const SizedBox(height: 10),
            RejillaCampos(
              anchoMinimo: 130,
              children: [
                numero(
                  'PA sistólica',
                  s.paSistolica,
                  'mmHg',
                  Rangos.paSistolica,
                  (s, v) => s.copyWith(paSistolica: v),
                ),
                numero(
                  'PA diastólica',
                  s.paDiastolica,
                  'mmHg',
                  Rangos.paDiastolica,
                  (s, v) => s.copyWith(paDiastolica: v),
                ),
                numero(
                  'FC',
                  s.fc,
                  'lpm',
                  Rangos.fc,
                  (s, v) => s.copyWith(fc: v),
                ),
                numero(
                  'FR',
                  s.fr,
                  'rpm',
                  Rangos.fr,
                  (s, v) => s.copyWith(fr: v),
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
                ),
                numero(
                  'Peso',
                  s.peso,
                  'kg',
                  Rangos.peso,
                  (s, v) => s.copyWith(peso: v),
                ),
                numero(
                  'Glucemia',
                  s.glucemia,
                  'mg/dL',
                  Rangos.glucemia,
                  (s, v) => s.copyWith(glucemia: v),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Wrap(
            spacing: 24,
            children: [
              _Interruptor(
                texto: 'Incluir firma',
                valor: ev.incluirFirma,
                alCambiar: (v) => _editar((e) => e.copyWith(incluirFirma: v)),
              ),
              _Interruptor(
                texto: 'Incluir sello',
                valor: ev.incluirSello,
                alCambiar: (v) => _editar((e) => e.copyWith(incluirSello: v)),
              ),
            ],
          ),
          if (ev.avisoIntegridad != null)
            Text(
              ev.avisoIntegridad!,
              style: const TextStyle(fontSize: 12.5, color: ColoresMarca.aviso),
            ),
        ],
      ),
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
        const SizedBox(width: 6),
        Text(texto),
      ],
    );
  }
}
