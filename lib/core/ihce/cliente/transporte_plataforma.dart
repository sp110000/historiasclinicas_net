import '../config/config_ihce.dart';
import 'transporte.dart';

/// Navegador: no hay adaptador directo válido (ver [TransporteNoDisponible]).
TransporteIhce crearTransporte(ConfigIhce config) =>
    const TransporteNoDisponible();
