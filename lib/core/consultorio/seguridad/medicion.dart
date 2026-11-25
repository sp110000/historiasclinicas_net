import 'derivacion.dart';

/// Cuánto tarda en este equipo derivar una llave con [p] (para decidir
/// entre PBKDF2 y Argon2id con datos reales).
Future<Duration> medirDerivacion(ParametrosDerivacion p) async {
  final reloj = Stopwatch()..start();
  await derivarLlave('frase de prueba para medir', List.filled(16, 7), p);
  reloj.stop();
  return reloj.elapsed;
}
