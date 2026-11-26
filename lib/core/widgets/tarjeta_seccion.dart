import 'package:flutter/material.dart';

import '../../app/tema.dart';
import '../presentacion/datos_historia.dart';

/// Estado que muestra el chip de la cabecera.
enum InsigniaSeccion { ninguna, completa, incompleta, soloLectura, activa }

/// Tarjeta de una sección del formulario: número en un círculo con el
/// color de su estado y el título al lado ([icono] lo usan el índice y los
/// tests).
///
/// * Editable: cabecera con número, título y avance.
/// * Bloqueada (historia abierta): fondo cálido, candado y, si está
///   plegada, un resumen de una línea; se despliega al pulsar la cabecera.
/// * Activa: borde naranja (zona de evoluciones).
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
    this.enLista = false,
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

  /// Fila dentro de la lista compacta de la historia abierta: sin borde ni
  /// radio propios (los pone la lista).
  final bool enLista;

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final estrecho = ancho < 600;
    final relleno = estrecho ? 16.0 : 28.0;
    final cabecera = Row(
      children: [
        _NumeroSeccion(numero: numero, insignia: insignia, chico: estrecho),
        SizedBox(width: estrecho ? 10 : 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                semanticsLabel: '$numero · $titulo',
                style: EstilosMarca.titulo.copyWith(
                  fontSize: estrecho ? 17 : 20,
                  letterSpacing: -0.3,
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
      decoration: enLista
          ? BoxDecoration(
              color: plegada ? ColoresMarca.bloqueado : Colors.white,
            )
          : BoxDecoration(
              color: bloqueada ? ColoresMarca.bloqueado : Colors.white,
              borderRadius: RadiosMarca.tarjeta,
              border: Border.all(
                color: activa ? ColoresMarca.marca : ColoresMarca.borde,
                width: activa ? 1.5 : 1,
              ),
              boxShadow: bloqueada ? null : sombraTarjeta,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: alAlternar,
              borderRadius: enLista ? null : RadiosMarca.tarjeta,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  relleno,
                  relleno * 0.7,
                  relleno * 0.75,
                  relleno * 0.7,
                ),
                child: cabecera,
              ),
            ),
          ),
          if (!plegada) ...[
            const Divider(height: 1, color: ColoresMarca.separador),
            Padding(
              padding: EdgeInsets.fromLTRB(relleno, 22, relleno, relleno),
              child: child,
            ),
          ],
        ],
      ),
    );
  }
}

/// Sombra suave de las tarjetas blancas sobre el fondo cálido.
const sombraTarjeta = [
  BoxShadow(color: Color(0x0D3C1E0F), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0F3C1E0F), blurRadius: 28, offset: Offset(0, 10)),
];

/// Colores (fondo, texto) de cada estado: verde = completa, ámbar = falta
/// algo, neutro = solo lectura o sin datos, tinte naranja = zona activa.
(Color, Color) coloresInsignia(InsigniaSeccion tipo) => switch (tipo) {
  InsigniaSeccion.completa => (
    ColoresMarca.estadoOkFondo,
    ColoresMarca.estadoOk,
  ),
  InsigniaSeccion.incompleta => (
    ColoresMarca.avisoFondo,
    ColoresMarca.avisoTexto,
  ),
  InsigniaSeccion.activa => (ColoresMarca.tinte, ColoresMarca.tinteTexto),
  InsigniaSeccion.soloLectura || InsigniaSeccion.ninguna => (
    ColoresMarca.neutroFondo,
    ColoresMarca.tintaSuave,
  ),
};

/// Número de la sección en un círculo con el color de su estado.
class _NumeroSeccion extends StatelessWidget {
  const _NumeroSeccion({
    required this.numero,
    required this.insignia,
    required this.chico,
  });

  final int numero;
  final InsigniaSeccion insignia;
  final bool chico;

  @override
  Widget build(BuildContext context) {
    final (fondo, texto) = coloresInsignia(insignia);
    final lado = chico ? 30.0 : 36.0;
    return ExcludeSemantics(
      child: Container(
        width: lado,
        height: lado,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
        child: Text(
          '$numero',
          style: TextStyle(
            fontSize: chico ? 13 : 15,
            fontWeight: FontWeight.w800,
            color: texto,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _Insignia extends StatelessWidget {
  const _Insignia(this.tipo);

  final InsigniaSeccion tipo;

  @override
  Widget build(BuildContext context) {
    final (IconData? icono, String texto) = switch (tipo) {
      InsigniaSeccion.ninguna => (null, ''),
      InsigniaSeccion.completa => (Icons.check_rounded, 'Completa'),
      InsigniaSeccion.incompleta => (Icons.more_horiz_rounded, 'Incompleta'),
      InsigniaSeccion.soloLectura => (Icons.lock_outline, 'Solo lectura'),
      InsigniaSeccion.activa => (Icons.edit_outlined, 'Zona activa'),
    };
    final (fondo, color) = coloresInsignia(tipo);
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
            color: fondo,
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
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
