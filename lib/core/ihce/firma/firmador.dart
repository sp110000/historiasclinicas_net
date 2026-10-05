import 'dart:typed_data';

import '../config/config_ihce.dart';

/// Firma digital del documento RDA al generarlo (Anexo Técnico §3.2.1 d).
///
/// TODO(IHCE-VERIFICAR): ni el Manual de Operaciones v01.4 ni la colección
/// Postman v1.5 definen el formato de firma en el API. Candidatos a
/// confirmar con la mesa de ayuda de IHCE: `Bundle.signature` (tipo
/// `Signature` de FHIR R4, que el perfil no restringe) y la extensión
/// `ExtensionContentSignatureRDA` de `DocumentReference` (firma del PDF).
/// Hasta entonces el modo por defecto es `off`. La llave privada y el
/// certificado X.509 del prestador vendrían solo del `AlmacenSecretos`.
abstract interface class FirmadorDocumento {
  /// Recibe los bytes canónicos y devuelve los bytes firmados que se
  /// persisten y se envían tal cual (sin re-serializar).
  Future<Uint8List> firmar(Uint8List bundleCanonico);
}

/// `IHCE_SIGNING_MODE=off`: devuelve los mismos bytes.
class FirmadorNoOp implements FirmadorDocumento {
  const FirmadorNoOp();

  @override
  Future<Uint8List> firmar(Uint8List bundleCanonico) async => bundleCanonico;
}

FirmadorDocumento firmadorPara(ModoFirma modo) => switch (modo) {
  ModoFirma.off => const FirmadorNoOp(),
};
