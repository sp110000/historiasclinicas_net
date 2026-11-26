import 'package:flutter/material.dart';

import '../../app/tema.dart';

/// El logo de historiasclinicas.net (la cruz con el pulso y la hoja), en
/// naranja. Va junto al nombre, así que no lo lee el lector de pantalla.
class LogoMarca extends StatelessWidget {
  const LogoMarca({super.key, this.lado = 32});

  final double lado;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/marca/logo.png',
    width: lado,
    height: lado,
    filterQuality: FilterQuality.medium,
    excludeFromSemantics: true,
  );
}

/// Logo y nombre: «historiasclinicas» en tinta y «.net» en naranja, con un
/// [sufijo] opcional («· Consultorio»).
class NombreMarca extends StatelessWidget {
  const NombreMarca({
    super.key,
    this.tamano = 18,
    this.sufijo,
    this.conLogo = true,
  });

  final double tamano;
  final String? sufijo;
  final bool conLogo;

  @override
  Widget build(BuildContext context) {
    final texto = Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: 'historiasclinicas',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: ColoresMarca.tinta,
            ),
          ),
          const TextSpan(
            text: '.net',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: ColoresMarca.marca,
            ),
          ),
          if (sufijo != null)
            TextSpan(
              text: sufijo,
              style: const TextStyle(color: ColoresMarca.tinta),
            ),
        ],
      ),
      semanticsLabel: 'historiasclinicas.net${sufijo ?? ''}',
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: tamano, letterSpacing: -0.2),
    );
    if (!conLogo) return texto;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LogoMarca(lado: tamano * 1.7),
        SizedBox(width: tamano * 0.45),
        Flexible(child: texto),
      ],
    );
  }
}
