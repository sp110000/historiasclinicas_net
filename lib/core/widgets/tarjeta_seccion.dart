import 'package:flutter/material.dart';

import '../../app/tema.dart';
import '../presentacion/datos_historia.dart';

/// Estado que muestra el chip de la cabecera.
enum InsigniaSeccion { ninguna, completa, incompleta, soloLectura, activa }

/// Tarjeta de una sección del formulario.
///
/// * Editable: cabecera con número, título y avance.
/// * Bloqueada (historia abierta): fondo gris azulado, candado y, si está
///   plegada, un resumen de una línea; se despliega al pulsar la cabecera.
/// * Activa: borde primario (zona de evoluciones).
class TarjetaSeccion extends StatelessWidget {
  const TarjetaSeccion({
    super.key,
    required this.numero,
    required this.titulo,
    required this.icono,
    required this.child,
    this.insignia = InsigniaSeccion.ninguna,
    this.bloqueada = false,
    this.activa = false,
    this.resumen,
    this.plegada = false,
    this.alAlternar,
    this.accion,
  });

  final int numero;
  final String titulo;
  final IconData icono;
  final Widget child;
  final InsigniaSeccion insignia;
  final bool bloqueada;
  final bool activa;
  final String? resumen;
  final bool plegada;
  final VoidCallback? alAlternar;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final relleno = ancho < 600 ? 16.0 : 24.0;
    final cabecera = Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (activa ? ColoresMarca.primario : ColoresMarca.primario)
                .withValues(alpha: activa ? 1 : 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icono,
            size: 19,
            color: activa ? Colors.white : ColoresMarca.primario,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$numero · $titulo',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  height: 1.25,
                ),
              ),
              if (plegada && (resumen ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    resumen!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ColoresMarca.textoSuave,
                      fontSize: 13.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ?accion,
        _Insignia(insignia),
        if (alAlternar != null)
          Icon(
            plegada ? Icons.expand_more : Icons.expand_less,
            color: ColoresMarca.textoSuave,
          ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: bloqueada ? ColoresMarca.bloqueado : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activa ? ColoresMarca.primario : ColoresMarca.borde,
          width: activa ? 2 : 1,
        ),
        boxShadow: activa
            ? [
                BoxShadow(
                  color: ColoresMarca.primario.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: alAlternar,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  relleno,
                  relleno * 0.75,
                  relleno * 0.75,
                  plegada ? relleno * 0.75 : 0,
                ),
                child: cabecera,
              ),
            ),
          ),
          if (!plegada)
            Padding(
              padding: EdgeInsets.fromLTRB(relleno, 18, relleno, relleno),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _Insignia extends StatelessWidget {
  const _Insignia(this.tipo);

  final InsigniaSeccion tipo;

  @override
  Widget build(BuildContext context) {
    final (IconData? icono, String texto, Color color) = switch (tipo) {
      InsigniaSeccion.ninguna => (null, '', Colors.transparent),
      InsigniaSeccion.completa => (
        Icons.check_circle,
        'Completa',
        ColoresMarca.secundario,
      ),
      InsigniaSeccion.incompleta => (
        Icons.pending_outlined,
        'Incompleta',
        ColoresMarca.aviso,
      ),
      InsigniaSeccion.soloLectura => (
        Icons.lock_outline,
        'Solo lectura',
        ColoresMarca.textoSuave,
      ),
      InsigniaSeccion.activa => (
        Icons.edit_outlined,
        'Zona activa',
        ColoresMarca.primario,
      ),
    };
    if (icono == null) return const SizedBox.shrink();
    final estrecho = MediaQuery.sizeOf(context).width < 600;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: texto,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: estrecho ? 6 : 10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 15, color: color),
              if (!estrecho) ...[
                const SizedBox(width: 5),
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Datos en solo lectura (historia abierta).
class DatosLectura extends StatelessWidget {
  const DatosLectura(
    this.datos, {
    super.key,
    this.vacio = 'Sin datos registrados.',
  });

  final List<DatoMostrado> datos;
  final String vacio;

  @override
  Widget build(BuildContext context) {
    if (datos.isEmpty) {
      return Text(
        vacio,
        style: const TextStyle(color: ColoresMarca.textoSuave),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        double ancho(AnchoDato a) => switch (a) {
          AnchoDato.corto => c.maxWidth < 420 ? c.maxWidth : 190,
          AnchoDato.medio => c.maxWidth < 420 ? c.maxWidth : 300,
          AnchoDato.completo => c.maxWidth,
        };
        return Wrap(
          spacing: 28,
          runSpacing: 16,
          children: [
            for (final d in datos)
              SizedBox(
                width: ancho(d.ancho),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.etiqueta.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w600,
                        color: ColoresMarca.textoSuave,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      d.valor,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
