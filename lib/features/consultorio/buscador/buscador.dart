import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/indice/indice_pacientes.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/utils/texto.dart' show sinTildes;
import '../../../core/widgets/ilustraciones.dart';
import '../../historia/widgets/franja_paciente.dart' show iniciales;
import '../agenda/dialogo_cita.dart';
import '../caja/dialogo_cobro.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../integracion/enganche_historia.dart';
import '../shell/contenedor_consultorio.dart' show destinosConsultorio;
import '../widgets/comunes.dart' show mostrarMensaje;

/// Lo que se eligió en el buscador.
enum _Accion { ir, ficha, consulta, cita, cobrar }

typedef _Eleccion = ({_Accion accion, String valor});

/// Pantallas a las que se puede ir desde el buscador.
final _pantallas = <({String etiqueta, String ruta, IconData icono})>[
  for (final d in destinosConsultorio)
    (etiqueta: d.etiqueta, ruta: d.ruta, icono: d.icono),
  (etiqueta: 'Receta', ruta: '/receta', icono: Icons.medication_outlined),
  (etiqueta: 'Datos del médico', ruta: '/medico', icono: Icons.badge_outlined),
];

/// Abre el buscador (Ctrl + K o ⌘ + K): pacientes sin tildes, con sus
/// acciones, y las pantallas del consultorio.
Future<void> abrirBuscador(BuildContext context, WidgetRef ref) async {
  final e = await showDialog<_Eleccion>(
    context: context,
    barrierColor: const Color(0x73241A16),
    builder: (_) => const _Buscador(),
  );
  if (e == null || !context.mounted) return;
  switch (e.accion) {
    case _Accion.ir:
      context.go(e.valor);
    case _Accion.ficha:
      context.go('/pacientes/${e.valor}');
    case _Accion.consulta:
      await empezarConsultaPara(context, ref, e.valor);
    case _Accion.cita:
      final c = await editarCita(context, pacienteId: e.valor);
      if (c != null && context.mounted) {
        ref.read(versionIndiceProvider.notifier).cambio();
        mostrarMensaje(context, 'Cita agendada.');
      }
    case _Accion.cobrar:
      await abrirCobro(context, ref, pacienteId: e.valor);
  }
}

/// «JP» para «PEÑA MUÑOZ, José Ángel»: el primer nombre y el primer
/// apellido.
String inicialesFicha(FichaPaciente f) {
  final nombre = f.nombres.trim().split(RegExp(r'\s+')).first;
  final texto = '$nombre ${f.primerApellido}'.trim();
  return iniciales(texto.isEmpty ? f.nombreCompleto : texto);
}

/// Abre la consulta de [pacienteId]: una evolución de su historia más
/// reciente o, si no tiene, una historia nueva con sus datos (como
/// «Atender» en la agenda, sin cita).
Future<void> empezarConsultaPara(
  BuildContext context,
  WidgetRef ref,
  String pacienteId,
) async {
  final s = ref.read(servicioConsultorioProvider);
  final ficha = s.indice.fichaActiva(pacienteId);
  if (ficha == null) return;
  final tieneHistorias = s.indice.ultimaHistoria(ficha.id) != null;
  if (!await confirmarReemplazoHistoria(
    context,
    ref,
    pacienteId: ficha.id,
    continuar: tieneHistorias,
  )) {
    return;
  }
  if (tieneHistorias) {
    if (!await nuevaEvolucionPara(ref, ficha.id)) return;
  } else {
    await nuevaHistoriaPara(ref, ficha);
  }
  ref.read(versionIndiceProvider.notifier).cambio();
  if (context.mounted) context.go('/');
}

class _Buscador extends ConsumerStatefulWidget {
  const _Buscador();

  @override
  ConsumerState<_Buscador> createState() => _BuscadorState();
}

class _BuscadorState extends ConsumerState<_Buscador> {
  final _texto = TextEditingController();
  var _seleccion = 0;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _elegir(_Accion accion, String valor) =>
      Navigator.of(context).pop<_Eleccion>((accion: accion, valor: valor));

  @override
  Widget build(BuildContext context) {
    final e = ref.watch(consultorioProvider);
    final abierto = e.desbloqueado && e.codigoPendiente == null;
    final s = ref.read(servicioConsultorioProvider);
    final q = _texto.text.trim();
    final ahora = s.reloj.ahora();
    final pacientes = abierto
        ? s.indice.buscar(texto: q).take(q.isEmpty ? 4 : 6).toList()
        : <ResumenPaciente>[];
    final qSin = sinTildes(q.toLowerCase());
    final pantallas = q.isEmpty
        ? const <({String etiqueta, String ruta, IconData icono})>[]
        : [
            for (final p in _pantallas)
              if (sinTildes(p.etiqueta.toLowerCase()).contains(qSin)) p,
          ];
    final total = pacientes.length + pantallas.length;
    final sel = total == 0 ? -1 : _seleccion.clamp(0, total - 1);
    final movil = MediaQuery.sizeOf(context).width < 700;

    void abrir(int i) {
      if (i < 0) return;
      if (i < pacientes.length) {
        _elegir(_Accion.ficha, pacientes[i].ficha.id);
      } else {
        _elegir(_Accion.ir, pantallas[i - pacientes.length].ruta);
      }
    }

    Widget rotulo(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Text(t.toUpperCase(), style: EstilosMarca.rotulo),
    );

    final resultados = <Widget>[
      if (!abierto)
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 14, 14, 4),
          child: Text(
            'Desbloquea el consultorio para buscar pacientes.',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
        ),
      if (pacientes.isNotEmpty) ...[
        rotulo(q.isEmpty ? 'Pacientes recientes' : 'Pacientes'),
        for (final (i, r) in pacientes.indexed)
          _FilaPaciente(
            resumen: r,
            ahora: ahora,
            seleccionada: i == sel,
            movil: movil,
            alElegir: (a) => _elegir(a, r.ficha.id),
          ),
      ],
      if (pantallas.isNotEmpty) ...[
        rotulo('Ir a'),
        for (final (j, p) in pantallas.indexed)
          _FilaPantalla(
            etiqueta: p.etiqueta,
            icono: p.icono,
            seleccionada: pacientes.length + j == sel,
            alElegir: () => _elegir(_Accion.ir, p.ruta),
          ),
      ],
      if (q.isNotEmpty && total == 0)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: EstadoVacio(
            ilustracion: Ilustracion.sinResultados,
            titulo: 'Nada coincide con «$q»',
            texto: 'Busca por nombre, apellido o documento.',
            alto: 80,
          ),
        ),
    ];

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: EdgeInsets.fromLTRB(16, movil ? 16 : 88, 16, 16),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: RadiosMarca.dialogo),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      setState(
                        () => _seleccion = (sel + 1) % (total == 0 ? 1 : total),
                      ),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      setState(
                        () => _seleccion = total == 0
                            ? 0
                            : (sel - 1 + total) % total,
                      ),
                },
                child: TextField(
                  controller: _texto,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() => _seleccion = 0),
                  onSubmitted: (_) => abrir(sel),
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'Buscar',
                    hintText: 'Paciente, documento o pantalla',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: ColoresMarca.primario,
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: ColoresMarca.separador),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                children: resultados,
              ),
            ),
            Container(
              color: ColoresMarca.fondo,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (!movil)
                    const Text(
                      '↑ ↓ moverte · Enter abrir la ficha · Esc cerrar',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: ColoresMarca.textoSuave,
                      ),
                    ),
                  const Text(
                    'Sin tildes también encuentra: «pena» → «Peña»',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: ColoresMarca.textoSuave,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaPaciente extends StatelessWidget {
  const _FilaPaciente({
    required this.resumen,
    required this.ahora,
    required this.seleccionada,
    required this.movil,
    required this.alElegir,
  });

  final ResumenPaciente resumen;
  final DateTime ahora;
  final bool seleccionada;
  final bool movil;
  final ValueChanged<_Accion> alElegir;

  @override
  Widget build(BuildContext context) {
    final f = resumen.ficha;
    final edad = f.edadAnios(ahora);
    final u = resumen.ultimaAtencion;
    final detalle = [
      if (f.numeroDocumento.isNotEmpty)
        '${f.tipoDocumento} ${f.numeroDocumento}',
      if (edad != null) '$edad años',
      u == null ? 'sin atenciones' : 'última atención ${formatoFecha(u)}',
    ].join(' · ');
    final acciones = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        FilledButton(
          onPressed: () => alElegir(_Accion.consulta),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: const Text('Consulta'),
        ),
        OutlinedButton(
          onPressed: () => alElegir(_Accion.cita),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: const Text('Cita'),
        ),
        OutlinedButton(
          onPressed: () => alElegir(_Accion.cobrar),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: const Text('Cobrar'),
        ),
      ],
    );
    final datos = Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: seleccionada ? Colors.white : ColoresMarca.neutroFondo,
              shape: BoxShape.circle,
            ),
            child: Text(
              inicialesFicha(f),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f.nombreCompleto,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                detalle,
                style: const TextStyle(
                  fontSize: 13,
                  color: ColoresMarca.textoSuave,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return Material(
      color: seleccionada ? ColoresMarca.tinte : Colors.transparent,
      borderRadius: RadiosMarca.control,
      child: InkWell(
        onTap: () => alElegir(_Accion.ficha),
        borderRadius: RadiosMarca.control,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: movil
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [datos, const SizedBox(height: 8), acciones],
                )
              : Row(
                  children: [
                    Expanded(child: datos),
                    const SizedBox(width: 10),
                    acciones,
                  ],
                ),
        ),
      ),
    );
  }
}

class _FilaPantalla extends StatelessWidget {
  const _FilaPantalla({
    required this.etiqueta,
    required this.icono,
    required this.seleccionada,
    required this.alElegir,
  });

  final String etiqueta;
  final IconData icono;
  final bool seleccionada;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) => Material(
    color: seleccionada ? ColoresMarca.tinte : Colors.transparent,
    borderRadius: RadiosMarca.control,
    child: InkWell(
      onTap: alElegir,
      borderRadius: RadiosMarca.control,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icono, size: 20, color: ColoresMarca.tintaSuave),
            const SizedBox(width: 12),
            Text('Ir a $etiqueta'),
          ],
        ),
      ),
    ),
  );
}
