import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/consultorio/modelos/foto.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../../historia/widgets/dialogos.dart';
import '../documentos/firma_autorizacion.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';
import 'piezas_fotos.dart';
import 'secuencia_fotos.dart';

DateTime _dia(DateTime f) => DateTime(f.year, f.month, f.day);

/// Fotos de la ficha: tomar (con consentimiento), comparar y galería.
class SeccionFotos extends ConsumerWidget {
  const SeccionFotos({super.key, required this.ficha});

  final FichaPaciente ficha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(versionIndiceProvider);
    final s = ref.read(servicioConsultorioProvider);
    final consentimiento = s.documentos.consentimientoImagenVigente(ficha);
    final fotos = s.seguimiento.fotosDe(ficha.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (consentimiento == null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: RadiosMarca.tarjeta,
              border: Border.all(color: ColoresMarca.borde),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Para tomar fotos hace falta el consentimiento de uso de '
                  'imagen, con el uso clínico.',
                ),
                FilledButton.icon(
                  onPressed: () =>
                      pedirConsentimientoImagen(context, ficha: ficha),
                  icon: const Icon(Icons.draw_outlined),
                  label: const Text('Pedir consentimiento'),
                ),
              ],
            ),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () async {
                final n = await tomarFotos(context, pacienteId: ficha.id);
                if (n != null && n > 0 && context.mounted) {
                  mostrarMensaje(
                    context,
                    n == 1 ? '1 foto guardada.' : '$n fotos guardadas.',
                  );
                }
              },
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Tomar fotos'),
            ),
          ),
        const SizedBox(height: 12),
        if (fotos.isEmpty)
          const Text(
            'Sin fotos todavía. Se guardan cifradas, sin metadatos (ni la '
            'ubicación), y solo salen en un PDF si lo pides.',
            style: TextStyle(color: ColoresMarca.textoSuave),
          )
        else ...[
          _Comparacion(fotos: fotos),
          const SizedBox(height: 16),
          const Text('GALERÍA', style: EstilosMarca.rotulo),
          const SizedBox(height: 8),
          _Galeria(fotos: fotos),
        ],
      ],
    );
  }
}

class _Comparacion extends StatefulWidget {
  const _Comparacion({required this.fotos});

  final List<Foto> fotos;

  @override
  State<_Comparacion> createState() => _ComparacionState();
}

class _ComparacionState extends State<_Comparacion> {
  VistaFoto? _vista;
  DateTime? _antes;
  DateTime? _despues;
  var _cortina = false;
  var _corte = 0.5;

  @override
  Widget build(BuildContext context) {
    final vistas = {for (final f in widget.fotos) f.vista}.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final vista = vistas.contains(_vista) ? _vista! : vistas.first;
    final deLaVista = [
      for (final f in widget.fotos)
        if (f.vista == vista) f,
    ];
    final dias = {for (final f in deLaVista) _dia(f.fecha)}.toList()..sort();
    final antes = dias.contains(_antes) ? _antes! : dias.first;
    final despues = dias.contains(_despues) ? _despues! : dias.last;
    Foto fotoDe(DateTime d) => deLaVista.lastWhere((f) => _dia(f.fecha) == d);
    final a = fotoDe(antes);
    final b = fotoDe(despues);
    final angosta = MediaQuery.sizeOf(context).width < 700;

    DropdownButtonFormField<T> selector<T>(
      String etiqueta,
      T valor,
      List<T> opciones,
      String Function(T) texto,
      ValueChanged<T> alCambiar,
    ) => DropdownButtonFormField<T>(
      initialValue: valor,
      isExpanded: true,
      decoration: InputDecoration(labelText: etiqueta),
      items: [
        for (final o in opciones)
          DropdownMenuItem(value: o, child: Text(texto(o))),
      ],
      onChanged: (v) {
        if (v != null) alCambiar(v);
      },
    );

    Widget panel(Foto f, String rotulo) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: RadiosMarca.control,
            child: ColoredBox(
              color: ColoresMarca.bloqueado,
              child: FotoCifrada(foto: f),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$rotulo · ${formatoFecha(f.fecha)}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: ColoresMarca.textoSuave),
        ),
      ],
    );

    final filtros = [
      selector<VistaFoto>(
        'Vista',
        vista,
        vistas,
        (v) => v.etiqueta,
        (v) => setState(() => _vista = v),
      ),
      selector<DateTime>(
        'Antes',
        antes,
        dias,
        formatoFecha,
        (v) => setState(() => _antes = v),
      ),
      selector<DateTime>(
        'Después',
        despues,
        dias,
        formatoFecha,
        (v) => setState(() => _despues = v),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RadiosMarca.tarjeta,
        border: Border.all(color: ColoresMarca.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('COMPARAR', style: EstilosMarca.rotulo),
          const SizedBox(height: 8),
          if (angosta)
            for (final f in filtros) ...[f, const SizedBox(height: 8)]
          else
            Row(
              children: [
                for (final (i, f) in filtros.indexed) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: f),
                ],
              ],
            ),
          SwitchListTile(
            value: _cortina,
            onChanged: (v) => setState(() => _cortina = v),
            contentPadding: EdgeInsets.zero,
            title: const Text('Cortina'),
            subtitle: const Text(
              'Una sobre otra, con una línea que se desliza',
            ),
          ),
          Text(
            'Diferencia: ${despues.difference(antes).inDays} días',
            style: const TextStyle(color: ColoresMarca.textoSuave),
          ),
          const SizedBox(height: 8),
          if (_cortina)
            Column(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRRect(
                      borderRadius: RadiosMarca.control,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          FotoCifrada(foto: b),
                          ClipRect(
                            clipper: _Corte(_corte),
                            child: FotoCifrada(foto: a),
                          ),
                          Align(
                            alignment: Alignment(_corte * 2 - 1, 0),
                            child: Container(width: 2, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Slider(
                  value: _corte,
                  onChanged: (v) => setState(() => _corte = v),
                  label: 'Cortina',
                  semanticFormatterCallback: (v) =>
                      'Antes a la izquierda: ${(v * 100).round()} %',
                ),
                Text(
                  'Izquierda: ${formatoFecha(a.fecha)} · derecha: '
                  '${formatoFecha(b.fecha)}',
                  style: const TextStyle(color: ColoresMarca.textoSuave),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: panel(a, 'Antes')),
                const SizedBox(width: 12),
                Expanded(child: panel(b, 'Después')),
              ],
            ),
        ],
      ),
    );
  }
}

class _Corte extends CustomClipper<Rect> {
  _Corte(this.fraccion);

  final double fraccion;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraccion, size.height);

  @override
  bool shouldReclip(_Corte anterior) => anterior.fraccion != fraccion;
}

class _Galeria extends ConsumerWidget {
  const _Galeria({required this.fotos});

  final List<Foto> fotos;

  Future<void> _ver(BuildContext context, WidgetRef ref, Foto f) async {
    final borrar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: TituloDialogo(
          '${f.titulo} · ${formatoFecha(f.fecha)}',
          icono: Icons.photo_outlined,
        ),
        content: SizedBox(
          width: 560,
          child: AspectRatio(
            aspectRatio: f.alto == 0 ? 3 / 4 : f.ancho / f.alto,
            child: InteractiveViewer(child: FotoCifrada(foto: f)),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ColoresMarca.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    if (borrar != true || !context.mounted) return;
    final si = await confirmar(
      context,
      titulo: '¿Borrar la foto?',
      texto:
          'Se borra del consultorio. Si ya estaba en un respaldo, allí '
          'sigue. Queda en la bitácora.',
      aceptar: 'Borrar',
      icono: Icons.delete_outline,
      peligro: true,
    );
    if (!si) return;
    await ref.read(servicioConsultorioProvider).seguimiento.borrarFoto(f.id);
    ref.read(versionIndiceProvider.notifier).cambio();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final porDia = <DateTime, List<Foto>>{};
    for (final f in fotos.reversed) {
      (porDia[_dia(f.fecha)] ??= []).add(f);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in porDia.entries) ...[
          Text(
            formatoFecha(e.key),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in e.value)
                Tooltip(
                  message: f.titulo,
                  child: InkWell(
                    onTap: () => _ver(context, ref, f),
                    borderRadius: RadiosMarca.control,
                    child: SizedBox(
                      width: 96,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 96,
                            height: 128,
                            child: ClipRRect(
                              borderRadius: RadiosMarca.control,
                              child: FotoCifrada(
                                foto: f,
                                miniatura: true,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Text(
                            f.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
