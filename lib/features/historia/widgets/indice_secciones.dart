import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/models/historia.dart';
import '../estado/borrador_provider.dart';
import '../estado/historia_controller.dart';
import '../estado/validacion.dart';

/// Índice lateral (escritorio) con el avance de cada sección.
class IndiceLateral extends ConsumerWidget {
  const IndiceLateral({
    super.key,
    required this.activa,
    required this.alElegir,
  });

  final SeccionHistoria activa;
  final ValueChanged<SeccionHistoria> alElegir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(historiaProvider);
    final h = estado.historia;
    return Container(
      width: 264,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: ColoresMarca.borde)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              estado.abierta ? 'HISTORIA ABIERTA' : 'HISTORIA NUEVA',
              style: const TextStyle(
                fontSize: 11.5,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                color: ColoresMarca.textoSuave,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (final s in SeccionHistoria.values)
                  _ElementoIndice(
                    seccion: s,
                    titulo: s == SeccionHistoria.signos
                        ? h.perfil.etiquetaSignosVitales
                        : s.tituloCorto,
                    activa: s == activa,
                    estado: _estadoElemento(
                      s,
                      estado.abierta,
                      h,
                      estado.evolucionesSelladas.length +
                          estado.evolucionesNuevas.length,
                    ),
                    alPulsar: () => alElegir(s),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          const _EstadoBorrador(),
        ],
      ),
    );
  }
}

/// Índice horizontal (tablet).
class IndiceHorizontal extends ConsumerWidget {
  const IndiceHorizontal({
    super.key,
    required this.activa,
    required this.alElegir,
  });

  final SeccionHistoria activa;
  final ValueChanged<SeccionHistoria> alElegir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(historiaProvider);
    final h = estado.historia;
    return Container(
      height: 54,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: ColoresMarca.borde)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        children: [
          for (final s in SeccionHistoria.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: s == activa,
                showCheckmark: false,
                avatar: _IconoEstado(
                  _estadoElemento(s, estado.abierta, h, 0),
                  pequeno: true,
                ),
                label: Text(
                  '${s.numero}. ${s == SeccionHistoria.signos ? h.perfil.etiquetaSignosVitales : s.tituloCorto}',
                ),
                onSelected: (_) => alElegir(s),
              ),
            ),
        ],
      ),
    );
  }
}

enum _EstadoElemento { vacia, parcial, completa, bloqueada, activa }

class _InfoElemento {
  const _InfoElemento(this.estado, [this.contador]);

  final _EstadoElemento estado;
  final int? contador;
}

_InfoElemento _estadoElemento(
  SeccionHistoria s,
  bool abierta,
  HistoriaClinica h,
  int evoluciones,
) {
  if (s == SeccionHistoria.evoluciones) {
    return _InfoElemento(
      abierta ? _EstadoElemento.activa : _EstadoElemento.vacia,
      abierta ? evoluciones : null,
    );
  }
  if (abierta) return const _InfoElemento(_EstadoElemento.bloqueada);
  return _InfoElemento(switch (avanceSeccion(s, h)) {
    Avance.vacia => _EstadoElemento.vacia,
    Avance.parcial => _EstadoElemento.parcial,
    Avance.completa => _EstadoElemento.completa,
  });
}

class _ElementoIndice extends StatelessWidget {
  const _ElementoIndice({
    required this.seccion,
    required this.titulo,
    required this.activa,
    required this.estado,
    required this.alPulsar,
  });

  final SeccionHistoria seccion;
  final String titulo;
  final bool activa;
  final _InfoElemento estado;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: activa ? ColoresMarca.tinte : Colors.transparent,
        borderRadius: RadiosMarca.control,
        child: InkWell(
          onTap: alPulsar,
          borderRadius: RadiosMarca.control,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                _NumeroIndice(
                  numero: seccion.numero,
                  estado: estado.estado,
                  activa: activa,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    semanticsLabel: '${seccion.numero}. $titulo',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: activa ? FontWeight.w600 : FontWeight.w500,
                      color: activa ? ColoresMarca.primario : null,
                    ),
                  ),
                ),
                if (estado.contador != null && estado.contador! > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: ColoresMarca.primario,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${estado.contador}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                _IconoEstado(estado),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Círculo numerado del índice: se rellena según el estado de la sección.
class _NumeroIndice extends StatelessWidget {
  const _NumeroIndice({
    required this.numero,
    required this.estado,
    required this.activa,
  });

  final int numero;
  final _EstadoElemento estado;
  final bool activa;

  @override
  Widget build(BuildContext context) {
    final (Color fondo, Color borde, Color texto) = activa
        ? (ColoresMarca.primario, ColoresMarca.primario, Colors.white)
        : switch (estado) {
            _EstadoElemento.completa => (
              ColoresMarca.estadoOk,
              ColoresMarca.estadoOk,
              Colors.white,
            ),
            _EstadoElemento.parcial => (
              ColoresMarca.avisoFondo,
              ColoresMarca.aviso,
              ColoresMarca.aviso,
            ),
            _EstadoElemento.bloqueada => (
              ColoresMarca.bloqueado,
              ColoresMarca.borde,
              ColoresMarca.textoSuave,
            ),
            _EstadoElemento.activa => (
              ColoresMarca.tinte,
              ColoresMarca.primario,
              ColoresMarca.primario,
            ),
            _EstadoElemento.vacia => (
              Colors.white,
              ColoresMarca.bordeCampo,
              ColoresMarca.textoSuave,
            ),
          };
    return ExcludeSemantics(
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fondo,
          shape: BoxShape.circle,
          border: Border.all(color: borde, width: 1.5),
        ),
        child: Text(
          '$numero',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: texto,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _IconoEstado extends StatelessWidget {
  const _IconoEstado(this.info, {this.pequeno = false});

  final _InfoElemento info;
  final bool pequeno;

  @override
  Widget build(BuildContext context) {
    final tam = pequeno ? 16.0 : 18.0;
    final (IconData icono, Color color, String ayuda) = switch (info.estado) {
      _EstadoElemento.vacia => (
        Icons.radio_button_unchecked,
        ColoresMarca.borde,
        'Sin datos',
      ),
      _EstadoElemento.parcial => (
        Icons.pending,
        ColoresMarca.aviso,
        'Incompleta',
      ),
      _EstadoElemento.completa => (
        Icons.check_circle,
        ColoresMarca.estadoOk,
        'Completa',
      ),
      _EstadoElemento.bloqueada => (
        Icons.lock_outline,
        ColoresMarca.textoSuave,
        'Solo lectura',
      ),
      _EstadoElemento.activa => (
        Icons.edit_outlined,
        ColoresMarca.primario,
        'Zona activa',
      ),
    };
    return Tooltip(
      message: ayuda,
      child: Icon(icono, size: tam, color: color),
    );
  }
}

class _EstadoBorrador extends ConsumerWidget {
  const _EstadoBorrador();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(borradorProvider);
    final texto = b.desactivado
        ? 'Borrador desactivado en este equipo'
        : b.guardadoEn == null
        ? 'Sin borrador guardado'
        : 'Borrador guardado ${horaCorta(b.guardadoEn!)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 14),
      child: Row(
        children: [
          Icon(
            b.desactivado ? Icons.cloud_off_outlined : Icons.save_outlined,
            size: 18,
            color: ColoresMarca.textoSuave,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 12.5,
                color: ColoresMarca.textoSuave,
              ),
            ),
          ),
          if (b.guardadoEn != null)
            IconButton(
              onPressed: () => ref.read(borradorProvider.notifier).borrar(),
              icon: const Icon(Icons.delete_outline, size: 19),
              tooltip: 'Borrar el borrador de este navegador',
            ),
        ],
      ),
    );
  }
}

/// "10:42"
String horaCorta(DateTime f) =>
    '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
