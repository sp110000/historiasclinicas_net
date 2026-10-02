import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'archivo.dart';

// API de acceso a archivos (Chrome y Edge). No está en package:web porque
// es una especificación del WICG.
@JS('showOpenFilePicker')
external JSPromise<JSArray<web.FileSystemFileHandle>> _showOpenFilePicker(
  JSAny opciones,
);

@JS('showSaveFilePicker')
external JSPromise<web.FileSystemFileHandle> _showSaveFilePicker(
  JSAny opciones,
);

extension type _ConPermisos(JSObject _) implements JSObject {
  external JSPromise<JSString> requestPermission(JSAny descriptor);
}

final _tiposPdf = [
  {
    'description': 'Historia clínica (PDF)',
    'accept': {
      'application/pdf': ['.pdf'],
    },
  },
];

/// `true` en navegadores que permiten sobrescribir el archivo abierto.
bool get puedeSobrescribirArchivos =>
    web.window.has('showOpenFilePicker') &&
    web.window.has('showSaveFilePicker');

bool _cancelado(Object error) => error.toString().contains('AbortError');

Future<Uint8List> _leer(web.Blob archivo) async =>
    (await archivo.arrayBuffer().toDart).toDart.asUint8List();

/// Pide al usuario un PDF. Devuelve `null` si cancela.
Future<ArchivoAbierto?> elegirPdf() async {
  if (puedeSobrescribirArchivos) {
    try {
      final manejadores = await _showOpenFilePicker(
        {'types': _tiposPdf, 'multiple': false}.jsify()!,
      ).toDart;
      final manejador = manejadores.toDart.first;
      final archivo = await manejador.getFile().toDart;
      return ArchivoAbierto(
        nombre: archivo.name,
        bytes: await _leer(archivo),
        manejador: manejador,
      );
    } catch (e) {
      if (_cancelado(e)) return null;
      // Cualquier otro fallo del selector moderno: se usa el clásico.
    }
  }
  return _elegirConInput();
}

Future<ArchivoAbierto?> _elegirConInput() {
  final completer = Completer<ArchivoAbierto?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.pdf,application/pdf'
    ..style.display = 'none';

  void terminar(ArchivoAbierto? resultado) {
    input.remove();
    if (!completer.isCompleted) completer.complete(resultado);
  }

  input.addEventListener(
    'change',
    (web.Event _) {
      final archivo = input.files?.item(0);
      if (archivo == null) {
        terminar(null);
        return;
      }
      _leer(archivo).then(
        (bytes) => terminar(ArchivoAbierto(nombre: archivo.name, bytes: bytes)),
        onError: (Object e, StackTrace s) {
          input.remove();
          if (!completer.isCompleted) completer.completeError(e, s);
        },
      );
    }.toJS,
  );
  input.addEventListener('cancel', ((web.Event _) => terminar(null)).toJS);
  web.document.body!.append(input);
  input.click();
  return completer.future;
}

/// Decide dónde guardar **antes** de generar el PDF: los selectores de
/// archivos exigen que se abran justo después del clic del usuario.
///
/// * Con [sobrescribir] (y un archivo abierto con manejador) pide permiso
///   de escritura sobre ese mismo archivo.
/// * Si el navegador lo permite, muestra "Guardar como…".
/// * Si no, se usará una descarga normal.
///
/// Devuelve `null` si el usuario cancela o niega el permiso.
Future<DestinoGuardado?> prepararGuardado({
  required String nombreSugerido,
  ArchivoAbierto? sobrescribir,
}) async {
  final existente = sobrescribir?.manejador;
  if (existente != null) {
    final manejador = existente as web.FileSystemFileHandle;
    final permiso = await _ConPermisos(
      manejador,
    ).requestPermission({'mode': 'readwrite'}.jsify()!).toDart;
    if (permiso.toDart != 'granted') return null;
    return DestinoGuardado(nombre: manejador.name, manejador: manejador);
  }
  if (puedeSobrescribirArchivos) {
    try {
      final manejador = await _showSaveFilePicker(
        {'suggestedName': nombreSugerido, 'types': _tiposPdf}.jsify()!,
      ).toDart;
      return DestinoGuardado(nombre: manejador.name, manejador: manejador);
    } catch (e) {
      if (_cancelado(e)) return null;
      // Sin permiso para abrir el selector: se recurre a la descarga.
    }
  }
  return DestinoGuardado(nombre: nombreSugerido);
}

Future<void> escribirArchivo(DestinoGuardado destino, Uint8List bytes) async {
  final manejador = destino.manejador;
  if (manejador != null) {
    final escritor = await (manejador as web.FileSystemFileHandle)
        .createWritable()
        .toDart;
    await escritor.write(bytes.toJS).toDart;
    await escritor.close().toDart;
    return;
  }
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final enlace = web.HTMLAnchorElement()
    ..href = url
    ..download = destino.nombre
    ..style.display = 'none';
  web.document.body!.append(enlace);
  enlace.click();
  enlace.remove();
  Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
}

/// Escucha PDF arrastrados sobre la ventana. Devuelve la función que deja
/// de escuchar.
void Function() escucharArchivosSoltados({
  required void Function(ArchivoAbierto archivo) alSoltar,
  required void Function(bool arrastrando) alArrastrar,
}) {
  var profundidad = 0;
  bool conArchivos(web.DragEvent e) =>
      e.dataTransfer?.types.toDart.any((t) => t.toDart == 'Files') ?? false;

  final sobre = (web.DragEvent e) {
    if (!conArchivos(e)) return;
    e.preventDefault();
    e.dataTransfer!.dropEffect = 'copy';
  }.toJS;
  final entra = (web.DragEvent e) {
    if (!conArchivos(e)) return;
    profundidad++;
    alArrastrar(true);
  }.toJS;
  final sale = (web.DragEvent e) {
    if (!conArchivos(e)) return;
    profundidad--;
    if (profundidad <= 0) {
      profundidad = 0;
      alArrastrar(false);
    }
  }.toJS;
  final suelta = (web.DragEvent e) {
    if (!conArchivos(e)) return;
    e.preventDefault();
    profundidad = 0;
    alArrastrar(false);
    final datos = e.dataTransfer!;
    // El manejador debe pedirse durante el evento, antes de cualquier await.
    JSPromise<JSAny?>? promesaManejador;
    if (datos.items.length > 0) {
      final item = datos.items[0];
      if (item.has('getAsFileSystemHandle')) {
        promesaManejador = item.callMethod<JSPromise<JSAny?>>(
          'getAsFileSystemHandle'.toJS,
        );
      }
    }
    final archivo = datos.files.item(0);
    if (archivo == null) return;
    () async {
      Object? manejador;
      try {
        final m = await promesaManejador?.toDart;
        if (m != null && (m as JSObject).has('createWritable')) manejador = m;
      } catch (_) {
        // Sin manejador: se podrá guardar, pero no sobrescribir.
      }
      alSoltar(
        ArchivoAbierto(
          nombre: archivo.name,
          bytes: await _leer(archivo),
          manejador: manejador,
        ),
      );
    }();
  }.toJS;

  web.window
    ..addEventListener('dragover', sobre)
    ..addEventListener('dragenter', entra)
    ..addEventListener('dragleave', sale)
    ..addEventListener('drop', suelta);
  return () {
    web.window
      ..removeEventListener('dragover', sobre)
      ..removeEventListener('dragenter', entra)
      ..removeEventListener('dragleave', sale)
      ..removeEventListener('drop', suelta);
  };
}
