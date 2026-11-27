import '../../models/mapa.dart';
import '../modelos/ficha_paciente.dart';

/// Un servicio del catálogo de la caja (pregunta 44). Los valores en pesos
/// son enteros.
class Servicio {
  const Servicio({
    required this.id,
    required this.nombre,
    required this.linea,
    required this.tarifa,
    this.abonable = false,
    this.sesionesPaquete = 0,
    this.plantillaId,
    this.activo = true,
  });

  final String id;
  final String nombre;
  final LineaAtencion linea;
  final int tarifa;

  /// Su valor queda como crédito para el tratamiento (la valoración).
  final bool abonable;

  /// Más de 0: es un paquete de ese número de sesiones.
  final int sesionesPaquete;

  /// El procedimiento de un paquete o de una sesión.
  final String? plantillaId;
  final bool activo;

  bool get esPaquete => sesionesPaquete > 0;

  Servicio copyWith({
    String? nombre,
    LineaAtencion? linea,
    int? tarifa,
    bool? abonable,
    int? sesionesPaquete,
    Object? plantillaId = sin,
    bool? activo,
  }) => Servicio(
    id: id,
    nombre: nombre ?? this.nombre,
    linea: linea ?? this.linea,
    tarifa: tarifa ?? this.tarifa,
    abonable: abonable ?? this.abonable,
    sesionesPaquete: sesionesPaquete ?? this.sesionesPaquete,
    plantillaId: cambio<String>(plantillaId, this.plantillaId),
    activo: activo ?? this.activo,
  );

  Map<String, Object?> aMapa() => compacto({
    'id': id,
    'nombre': nombre.trim(),
    'linea': linea.name,
    'tarifa': tarifa,
    'abonable': abonable ? true : null,
    'sesionesPaquete': sesionesPaquete > 0 ? sesionesPaquete : null,
    'plantillaId': plantillaId,
    'activo': activo ? null : false,
  });

  static Servicio desdeMapa(Map<String, Object?> m) => Servicio(
    id: m.texto('id'),
    nombre: m.texto('nombre'),
    linea: LineaAtencion.values.byName(m.texto('linea')),
    tarifa: m.entero('tarifa') ?? 0,
    abonable: m.booleano('abonable'),
    sesionesPaquete: m.entero('sesionesPaquete') ?? 0,
    plantillaId: m.textoONulo('plantillaId'),
    activo: m.booleano('activo', porDefecto: true),
  );
}

/// Las tarifas iniciales de la pregunta 44, todas editables.
const serviciosIniciales = [
  Servicio(
    id: 'consulta_primera_vez',
    nombre: 'Consulta de primera vez',
    linea: LineaAtencion.general,
    tarifa: 80000,
  ),
  Servicio(
    id: 'control',
    nombre: 'Control',
    linea: LineaAtencion.general,
    tarifa: 45000,
  ),
  Servicio(
    id: 'certificado',
    nombre: 'Certificado',
    linea: LineaAtencion.general,
    tarifa: 40000,
  ),
  Servicio(
    id: 'valoracion_estetica',
    nombre: 'Valoración estética (abonable al tratamiento)',
    linea: LineaAtencion.estetica,
    tarifa: 70000,
    abonable: true,
    plantillaId: 'hidrolipoclasia',
  ),
  Servicio(
    id: 'sesion_hidrolipoclasia',
    nombre: 'Sesión de hidrolipoclasia por zona',
    linea: LineaAtencion.estetica,
    tarifa: 240000,
    plantillaId: 'hidrolipoclasia',
  ),
  Servicio(
    id: 'paquete_hidrolipoclasia_4',
    nombre: 'Paquete de 4 sesiones',
    linea: LineaAtencion.estetica,
    tarifa: 880000,
    sesionesPaquete: 4,
    plantillaId: 'hidrolipoclasia',
  ),
  ...serviciosEcografia,
];

/// Los servicios de ecografía, con tarifas de ejemplo (editables). Un
/// catálogo guardado antes de que existieran los recibe una vez al cargar.
const serviciosEcografia = [
  Servicio(
    id: 'ecografia',
    nombre: 'Ecografía',
    linea: LineaAtencion.general,
    tarifa: 100000,
  ),
  Servicio(
    id: 'ecografia_obstetrica',
    nombre: 'Ecografía obstétrica',
    linea: LineaAtencion.general,
    tarifa: 120000,
  ),
  Servicio(
    id: 'ecografia_transvaginal',
    nombre: 'Ecografía transvaginal',
    linea: LineaAtencion.general,
    tarifa: 120000,
  ),
];

/// Medios de pago (pregunta 46).
enum MedioPago {
  efectivo('Efectivo'),
  transferencia('Transferencia'),
  nequi('Nequi'),
  daviplata('Daviplata'),
  tarjeta('Tarjeta');

  const MedioPago(this.etiqueta);

  final String etiqueta;
}

/// «$ 80.000»
String formatoPesos(int valor) {
  final s = valor.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${valor < 0 ? '-' : ''}\$ $b';
}
