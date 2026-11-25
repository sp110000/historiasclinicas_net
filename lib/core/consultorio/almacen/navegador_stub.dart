import 'navegador.dart';

Future<bool> pedirPersistencia() async => true;

Future<bool> estaPersistido() async => true;

Future<EspacioAlmacen?> estimarEspacio() async => null;

CandadoPestanas crearCandadoPestanas() => CandadoMemoria();

/// Candado de un solo proceso (pruebas): [ocupadoPorOtra] simula otra
/// pestaña que ya lo tiene.
class CandadoMemoria implements CandadoPestanas {
  bool ocupadoPorOtra = false;
  bool tomado = false;

  @override
  Future<bool> tomar() async {
    if (ocupadoPorOtra) return false;
    tomado = true;
    return true;
  }

  @override
  void soltar() => tomado = false;
}
