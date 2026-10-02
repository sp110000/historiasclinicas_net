String? _guardado;

Future<String?> leerCatalogoGuardado() async => _guardado;

Future<void> guardarCatalogo(String json) async => _guardado = json;

Future<void> borrarCatalogo() async => _guardado = null;
