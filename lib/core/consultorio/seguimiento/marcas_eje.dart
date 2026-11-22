import 'dart:math' as math;

/// Marcas redondas para un eje de [minimo] a [maximo] (paso 1, 2 o 5 por
/// una potencia de 10, unas 4 a 7 marcas), con los decimales que pide el
/// paso.
({List<double> marcas, int decimales}) marcasEje(double minimo, double maximo) {
  var rango = maximo - minimo;
  if (rango <= 0) rango = math.max(minimo.abs() * 0.1, 1);
  final bruto = rango / 4;
  final potencia = math
      .pow(10, (math.log(bruto) / math.ln10).floor())
      .toDouble();
  final paso = [
    1,
    2,
    5,
    10,
  ].map((k) => k * potencia).firstWhere((p) => rango / p <= 5);
  // Un poco de aire para que los puntos no queden sobre el borde.
  final desde = ((minimo - rango * 0.08) / paso).floor() * paso;
  var hasta = ((maximo + rango * 0.08) / paso).ceil() * paso;
  if (hasta <= desde) hasta = desde + paso;
  final n = ((hasta - desde) / paso).round();
  final decimales = paso >= 1 ? 0 : (-(math.log(paso) / math.ln10).floor());
  return (
    marcas: [for (var i = 0; i <= n; i++) desde + i * paso],
    decimales: decimales,
  );
}
