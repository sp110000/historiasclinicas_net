import 'package:flutter/material.dart';

import '../../../app/tema.dart';
import '../estado/validacion.dart';

Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String texto,
  String aceptar = 'Continuar',
  IconData? icono,
  bool peligro = false,
}) async {
  final si = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: icono == null
          ? null
          : Icon(
              icono,
              color: peligro ? ColoresMarca.error : ColoresMarca.primario,
            ),
      title: Text(titulo),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Text(texto),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: peligro
              ? FilledButton.styleFrom(backgroundColor: ColoresMarca.error)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(aceptar),
        ),
      ],
    ),
  );
  return si ?? false;
}

/// Lista de lo que falta para finalizar. Devuelve la sección a revisar.
Future<SeccionHistoria?> mostrarPendientes(
  BuildContext context,
  List<Pendiente> pendientes,
) {
  final porSeccion = <SeccionHistoria, List<String>>{};
  for (final p in pendientes) {
    porSeccion.putIfAbsent(p.seccion, () => []).add(p.campo);
  }
  return showDialog<SeccionHistoria>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.fact_check_outlined, color: ColoresMarca.aviso),
      title: const Text('Faltan datos para finalizar'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in porSeccion.entries) ...[
                Text(
                  '${e.key.numero}. ${e.key.titulo}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                for (final campo in e.value)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 3),
                    child: Text('• $campo'),
                  ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, porSeccion.keys.first),
          child: Text('Ir a «${porSeccion.keys.first.tituloCorto}»'),
        ),
      ],
    ),
  );
}

/// Error al reabrir un PDF. Devuelve 'otro' o 'nueva'.
Future<String?> mostrarErrorApertura(BuildContext context, String mensaje) {
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.error_outline, color: ColoresMarca.error),
      title: const Text('No se pudo abrir la historia'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Text(mensaje),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'nueva'),
          child: const Text('Empezar historia nueva'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, 'otro'),
          child: const Text('Elegir otro archivo'),
        ),
      ],
    ),
  );
}

const limitaciones = [
  'Todo se procesa en este navegador: ningún dato de pacientes se envía a un servidor.',
  'La app no guarda historias: el único registro es el PDF que descargas, con los '
      'datos incrustados. Si lo pierdes o se daña, se pierde la historia: guarda '
      'copias de respaldo.',
  'Solo se pueden reabrir los PDF generados por historiasclinicas.net.',
  'Si otro programa modifica o vuelve a guardar el PDF (incluido "imprimir a '
      'PDF"), los datos incrustados pueden perderse.',
  'El bloqueo de lo anterior lo aplica esta aplicación, no el PDF. La cadena de '
      'huellas detecta alteraciones, pero no es una firma digital.',
  'El borrador automático se guarda solo en este navegador. Bórralo si usas un '
      'equipo compartido.',
  'La firma y el sello son imágenes: no equivalen a una firma digital certificada.',
];

Future<void> mostrarAcercaDe(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(
        Icons.health_and_safety_outlined,
        color: ColoresMarca.primario,
      ),
      title: const Text('historiasclinicas.net'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Historia clínica y receta en el navegador, sin servidor y sin '
                'conexión. Antes de usarla, ten en cuenta:',
              ),
              const SizedBox(height: 12),
              for (final l in limitaciones)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '•  ',
                        style: TextStyle(color: ColoresMarca.primario),
                      ),
                      Expanded(child: Text(l)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}
