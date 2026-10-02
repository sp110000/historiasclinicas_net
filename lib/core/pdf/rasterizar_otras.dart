import 'dart:typed_data';

import 'package:printing/printing.dart';

Stream<Uint8List> rasterizarPdf(Uint8List pdf, double dpi) =>
    Printing.raster(pdf, dpi: dpi).asyncMap((p) => p.toPng());
