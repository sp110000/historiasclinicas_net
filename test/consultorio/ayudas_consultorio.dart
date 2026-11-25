import 'package:historiasclinicas_net/core/consultorio/almacen/almacen.dart';
import 'package:historiasclinicas_net/core/consultorio/almacen/navegador_stub.dart';
import 'package:historiasclinicas_net/core/consultorio/seguridad/derivacion.dart';
import 'package:historiasclinicas_net/core/consultorio/seguridad/llavero.dart';
import 'package:historiasclinicas_net/core/consultorio/seguridad/motor_aes_dart.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/ihce/reloj.dart';

/// Pocas iteraciones: en las pruebas la derivación no tiene que ser lenta.
const parametrosDePrueba = ParametrosDerivacion.pbkdf2(1000);

const fraseDePrueba = 'caballo correcto batería grapa';

FabricaLlavero fabricaDePrueba(MotorAesDart motor) => FabricaLlavero(
  motor,
  parametrosFrase: parametrosDePrueba,
  parametrosCodigo: parametrosDePrueba,
);

/// Servicio con almacén en memoria, AES en Dart y reloj fijo.
class BancoConsultorio {
  BancoConsultorio({AlmacenMemoria? almacen, DateTime? ahora})
    : almacen = almacen ?? AlmacenMemoria(),
      reloj = RelojFalso(ahora ?? DateTime(2026, 11, 21, 9, 30)) {
    servicio = ServicioConsultorio(
      almacen: this.almacen,
      motor: motor,
      candado: candado,
      fabrica: fabricaDePrueba(motor),
      reloj: reloj,
      versionApp: 'pruebas',
    );
  }

  final AlmacenMemoria almacen;
  final RelojFalso reloj;
  final motor = MotorAesDart();
  final candado = CandadoMemoria();
  late final ServicioConsultorio servicio;

  /// Todos los bytes guardados, para buscar texto en claro.
  List<int> get todosLosBytes => [
    for (final d in almacen.datos.values)
      for (final v in d.values) ...v,
  ];
}

/// `true` si [texto] (UTF-8) aparece en [bytes].
bool contieneTexto(List<int> bytes, String texto) {
  final aguja = texto.codeUnits;
  outer:
  for (var i = 0; i + aguja.length <= bytes.length; i++) {
    for (var j = 0; j < aguja.length; j++) {
      if (bytes[i + j] != aguja[j]) continue outer;
    }
    return true;
  }
  return false;
}
