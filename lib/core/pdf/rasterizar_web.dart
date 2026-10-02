import 'dart:js_interop';
import 'dart:typed_data';

/// Definida en web/pdfjs/iniciar.js.
@JS('hcRasterizarPdf')
external JSPromise<JSArray<JSUint8Array>> _rasterizar(
  JSUint8Array datos,
  double escala,
);

Stream<Uint8List> rasterizarPdf(Uint8List pdf, double dpi) async* {
  final paginas = await _rasterizar(pdf.toJS, dpi / 72).toDart;
  for (final p in paginas.toDart) {
    yield p.toDart;
  }
}
