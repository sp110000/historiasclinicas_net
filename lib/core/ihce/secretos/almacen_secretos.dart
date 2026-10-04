import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/config_ihce.dart';

/// Dónde viven las credenciales de IHCE y las llaves de cifrado del
/// dispositivo. En la app es `flutter_secure_storage`; las pruebas usan
/// [AlmacenSecretosMemoria]. Nada de esto va a preferencias, a la base
/// clínica, a `--dart-define` ni a los logs.
abstract interface class AlmacenSecretos {
  Future<String?> leer(String clave);
  Future<void> escribir(String clave, String valor);
  Future<void> borrar(String clave);
}

/// Claves del almacén. Las credenciales son por prestador y por ambiente.
abstract final class ClavesSecretas {
  static String clientId(AmbienteIhce a) => 'ihce.${a.name}.client_id';
  static String clientSecret(AmbienteIhce a) => 'ihce.${a.name}.client_secret';

  /// Clave de suscripción de Azure API Management. TODO(IHCE-VERIFICAR):
  /// confirmar si es por ambiente o por prestador (Manual de Operaciones
  /// §5 habla de «llaves del API»).
  static String subscriptionKey(AmbienteIhce a) =>
      'ihce.${a.name}.subscription_key';

  /// Llave AES-256 de los datos del RDA en reposo (generada en el equipo).
  static const llaveDatos = 'ihce.llave_datos.v1';
}

class AlmacenSecretosMemoria implements AlmacenSecretos {
  final valores = <String, String>{};

  /// Registro de cada clave leída (para verificar el acceso en pruebas).
  final lecturas = <String>[];

  @override
  Future<String?> leer(String clave) async {
    lecturas.add(clave);
    return valores[clave];
  }

  @override
  Future<void> escribir(String clave, String valor) async =>
      valores[clave] = valor;

  @override
  Future<void> borrar(String clave) async => valores.remove(clave);
}

/// `flutter_secure_storage`: llavero del sistema en Android, iOS, macOS,
/// Windows y Linux; en la web es experimental (WebCrypto sobre
/// `localStorage`, solo en HTTPS, atado al dominio y al navegador).
class AlmacenSecretosSeguro implements AlmacenSecretos {
  AlmacenSecretosSeguro([FlutterSecureStorage? almacen])
    : _almacen = almacen ?? const FlutterSecureStorage();

  final FlutterSecureStorage _almacen;

  @override
  Future<String?> leer(String clave) => _almacen.read(key: clave);

  @override
  Future<void> escribir(String clave, String valor) =>
      _almacen.write(key: clave, value: valor);

  @override
  Future<void> borrar(String clave) => _almacen.delete(key: clave);
}

/// Credenciales del prestador para el ambiente activo.
class CredencialesIhce {
  const CredencialesIhce({
    required this.clientId,
    required this.clientSecret,
    this.subscriptionKey,
  });

  final String clientId;
  final String clientSecret;
  final String? subscriptionKey;

  /// Los valores secretos, para redactarlos de cualquier texto.
  List<String> get secretos => [clientSecret, ?subscriptionKey];

  @override
  String toString() => 'CredencialesIhce(<redactado>)';
}

/// Lee y guarda las credenciales solo a través del [AlmacenSecretos].
class ServicioCredenciales {
  ServicioCredenciales(this._almacen, this._ambiente);

  final AlmacenSecretos _almacen;
  final AmbienteIhce _ambiente;

  /// `null` si falta el ClientID o el ClientSecret: el módulo queda inactivo.
  Future<CredencialesIhce?> leer() async {
    final id = await _almacen.leer(ClavesSecretas.clientId(_ambiente));
    final secreto = await _almacen.leer(ClavesSecretas.clientSecret(_ambiente));
    if (id == null || id.isEmpty || secreto == null || secreto.isEmpty) {
      return null;
    }
    final clave = await _almacen.leer(
      ClavesSecretas.subscriptionKey(_ambiente),
    );
    return CredencialesIhce(
      clientId: id,
      clientSecret: secreto,
      subscriptionKey: clave == null || clave.isEmpty ? null : clave,
    );
  }

  Future<bool> configuradas() async => await leer() != null;

  /// Aprovisiona sin interfaz (pruebas y despliegues gestionados) o desde
  /// el formulario «ClientID/ClientSecret de MinSalud». Un valor `null` no
  /// cambia el guardado (así se reemplaza solo el secreto).
  Future<void> guardar({
    String? clientId,
    String? clientSecret,
    String? subscriptionKey,
  }) async {
    Future<void> poner(String clave, String? valor) async {
      if (valor == null) return;
      final v = valor.trim();
      v.isEmpty
          ? await _almacen.borrar(clave)
          : await _almacen.escribir(clave, v);
    }

    await poner(ClavesSecretas.clientId(_ambiente), clientId);
    await poner(ClavesSecretas.clientSecret(_ambiente), clientSecret);
    await poner(ClavesSecretas.subscriptionKey(_ambiente), subscriptionKey);
  }

  /// El ClientID guardado (no es secreto; se muestra para confirmar).
  Future<String?> clientIdGuardado() =>
      _almacen.leer(ClavesSecretas.clientId(_ambiente));
}
