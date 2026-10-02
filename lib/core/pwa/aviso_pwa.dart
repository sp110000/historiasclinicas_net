/// Avisos del service worker (ver web/flutter_bootstrap.js y tool/pwa). Los
/// nombres coinciden con los que envía flutter_bootstrap.js.
enum AvisoPwa {
  /// La app quedó guardada en este navegador por primera vez: ya funciona
  /// sin conexión.
  listaSinConexion,

  /// Se instaló una versión nueva; se usa al recargar.
  versionNueva,
}
