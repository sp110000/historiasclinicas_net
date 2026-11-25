/// Módulo del consultorio (Fase 5): índice de pacientes y datos de gestión
/// en un almacén local cifrado. Ver docs/FASE5.md.
library;

/// `--dart-define=CONSULTORIO_ENABLED=true` enciende el módulo; apagado por
/// defecto.
///
/// Es una **constante**: con la bandera apagada, el compilador elimina todo
/// el código que solo se alcanza desde un `if (consultorioHabilitado)`, así
/// que el sitio público queda igual que antes de la Fase 5 (lo comprueba
/// `tool/consultorio/verificar_compilacion.dart`).
const consultorioHabilitado = bool.fromEnvironment('CONSULTORIO_ENABLED');

/// Nombre de la base de IndexedDB del consultorio. Sirve también de marca:
/// no debe aparecer en `main.dart.js` cuando la bandera está apagada.
const baseDeDatosConsultorio = 'historiasclinicas_consultorio';
