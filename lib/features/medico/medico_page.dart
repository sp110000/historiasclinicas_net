import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tema.dart';
import '../../core/archivos/archivos.dart' as archivos;
import '../../core/imagenes/procesar_imagen.dart';
import '../../core/models/medico.dart';
import '../../core/pais/pais_provider.dart';
import '../../core/pais/perfil_pais.dart';
import '../../core/widgets/campos.dart';
import '../../core/widgets/lienzo_firma.dart';
import '../historia/estado/historia_controller.dart';
import '../historia/widgets/dialogos.dart';
import 'medico_provider.dart';

/// Panel "Datos del médico": se configura una vez y se guarda solo en este
/// navegador.
class MedicoPage extends ConsumerWidget {
  const MedicoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(medicoProvider);
    final pais = ref.watch(paisProvider);
    final ctrl = ref.read(medicoProvider.notifier);
    final movil = MediaQuery.sizeOf(context).width < 700;

    void volver() => context.canPop() ? context.pop() : context.go('/');

    Future<void> borrarTodo() async {
      if (await confirmar(
        context,
        titulo: '¿Borrar tus datos de este navegador?',
        texto:
            'Se eliminarán tu nombre, registro, consultorio, firma, sello y '
            'logo. Las historias ya guardadas en PDF no cambian.',
        aceptar: 'Borrar',
        icono: Icons.delete_forever_outlined,
        peligro: true,
      )) {
        await ctrl.borrarTodo();
        if (context.mounted) volver();
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: volver,
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver a la historia',
        ),
        title: const Text(
          'Datos del médico',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (m.configurado)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_done_outlined,
                    size: 18,
                    color: ColoresMarca.secundario,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Guardado en este navegador',
                    style: TextStyle(
                      fontSize: 13,
                      color: ColoresMarca.secundario,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: movil ? 12 : 24,
          vertical: 20,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Se configuran una sola vez y se guardan solo en este navegador. '
                  'Aparecen en el encabezado y en la firma de tus historias y recetas.',
                  style: TextStyle(color: ColoresMarca.textoSuave),
                ),
                const SizedBox(height: 16),
                _Tarjeta(
                  icono: Icons.badge_outlined,
                  titulo: 'Datos profesionales',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilaCampos(
                        children: [
                          CampoTexto(
                            etiqueta: 'Nombre completo',
                            requerido: true,
                            pista: 'Dra. Ana Pérez Gómez',
                            mayusculas: TextCapitalization.words,
                            valorInicial: m.nombre,
                            alCambiar: (v) =>
                                ctrl.actualizar((m) => m.copyWith(nombre: v)),
                          ),
                          CampoTexto(
                            etiqueta: 'Especialidad',
                            pista: 'Medicina interna',
                            valorInicial: m.especialidad,
                            alCambiar: (v) => ctrl.actualizar(
                              (m) => m.copyWith(especialidad: v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      FilaCampos(
                        children: [
                          CampoTexto(
                            etiqueta: etiquetaRegistro(pais),
                            requerido: true,
                            valorInicial: m.registro,
                            alCambiar: (v) =>
                                ctrl.actualizar((m) => m.copyWith(registro: v)),
                          ),
                          CampoTexto(
                            etiqueta: 'Documento de identidad (opcional)',
                            valorInicial: m.documento,
                            alCambiar: (v) => ctrl.actualizar(
                              (m) => m.copyWith(documento: v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SelectorOpciones(
                        etiqueta: 'País de ejercicio',
                        opciones: [
                          for (final p in Pais.values)
                            Opcion(p.codigo, p.nombre),
                        ],
                        valor: pais.codigo,
                        alCambiar: (codigo) async {
                          if (codigo == null) return;
                          final p = Pais.desdeCodigo(codigo);
                          await ref.read(paisProvider.notifier).cambiar(p);
                          ref.read(historiaProvider.notifier).cambiarPais(p);
                        },
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Define los tipos de documento y las etiquetas de las historias '
                        'nuevas (VERIFICAR la norma de cada país).',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: ColoresMarca.textoSuave,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Tarjeta(
                  icono: Icons.local_hospital_outlined,
                  titulo: 'Consultorio',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CampoTexto(
                        etiqueta: 'Nombre del consultorio o institución',
                        valorInicial: m.consultorio,
                        alCambiar: (v) =>
                            ctrl.actualizar((m) => m.copyWith(consultorio: v)),
                      ),
                      const SizedBox(height: 14),
                      FilaCampos(
                        flex: const [3, 2],
                        children: [
                          CampoTexto(
                            etiqueta: 'Dirección',
                            valorInicial: m.direccion,
                            alCambiar: (v) => ctrl.actualizar(
                              (m) => m.copyWith(direccion: v),
                            ),
                          ),
                          CampoTexto(
                            etiqueta: 'Ciudad',
                            valorInicial: m.ciudad,
                            mayusculas: TextCapitalization.words,
                            alCambiar: (v) =>
                                ctrl.actualizar((m) => m.copyWith(ciudad: v)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      FilaCampos(
                        children: [
                          CampoTexto(
                            etiqueta: 'Teléfono',
                            teclado: TextInputType.phone,
                            valorInicial: m.telefono,
                            alCambiar: (v) =>
                                ctrl.actualizar((m) => m.copyWith(telefono: v)),
                          ),
                          CampoTexto(
                            etiqueta: 'Correo electrónico',
                            teclado: TextInputType.emailAddress,
                            mayusculas: TextCapitalization.none,
                            valorInicial: m.correo,
                            alCambiar: (v) =>
                                ctrl.actualizar((m) => m.copyWith(correo: v)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Tarjeta(
                  icono: Icons.draw_outlined,
                  titulo: 'Firma',
                  child: _EditorImagen(
                    tipo: TipoImagen.firma,
                    bytes: m.firma,
                    permitirDibujar: true,
                    quitarFondoInicial: true,
                    ayuda:
                        'Dibújala aquí mismo o sube una foto o escaneo sobre papel blanco.',
                    alCambiar: (b) async {
                      ctrl.actualizar((m) => m.copyWith(firma: b));
                      await ctrl.guardarAhora();
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _Tarjeta(
                  icono: Icons.approval_outlined,
                  titulo: 'Sello',
                  child: _EditorImagen(
                    tipo: TipoImagen.sello,
                    bytes: m.sello,
                    quitarFondoInicial: true,
                    ayuda:
                        'Sube una foto o escaneo del sello estampado sobre papel blanco.',
                    alCambiar: (b) async {
                      ctrl.actualizar((m) => m.copyWith(sello: b));
                      await ctrl.guardarAhora();
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _Tarjeta(
                  icono: Icons.image_outlined,
                  titulo: 'Logo (opcional)',
                  child: _EditorImagen(
                    tipo: TipoImagen.logo,
                    bytes: m.logo,
                    quitarFondoInicial: false,
                    ayuda:
                        'Aparece a la izquierda del encabezado. Mejor en PNG con fondo transparente.',
                    alCambiar: (b) async {
                      ctrl.actualizar((m) => m.copyWith(logo: b));
                      await ctrl.guardarAhora();
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ColoresMarca.aviso.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ColoresMarca.aviso.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.gavel_outlined, color: ColoresMarca.aviso),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'La firma y el sello son imágenes: no equivalen a una firma '
                          'digital certificada. VERIFICAR su validez legal en tu país. '
                          'Cualquiera con acceso a este navegador podría usarlas: '
                          'bórralas si el equipo es compartido.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Tarjeta(
                  icono: Icons.visibility_outlined,
                  titulo: 'Así aparecerá en tus documentos',
                  child: VistaPreviaMedico(medico: m, pais: pais),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColoresMarca.error,
                      side: const BorderSide(color: ColoresMarca.error),
                    ),
                    onPressed: m.vacio ? null : borrarTodo,
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Borrar mis datos de este navegador'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.icono,
    required this.titulo,
    required this.child,
  });

  final IconData icono;
  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final relleno = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    return Container(
      padding: EdgeInsets.all(relleno),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresMarca.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: ColoresMarca.primario.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, size: 19, color: ColoresMarca.primario),
              ),
              const SizedBox(width: 12),
              Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

/// Vista, carga, dibujo y eliminación de una imagen del médico.
class _EditorImagen extends StatefulWidget {
  const _EditorImagen({
    required this.tipo,
    required this.bytes,
    required this.alCambiar,
    required this.ayuda,
    this.permitirDibujar = false,
    this.quitarFondoInicial = true,
  });

  final TipoImagen tipo;
  final Uint8List? bytes;
  final Future<void> Function(Uint8List? bytes) alCambiar;
  final String ayuda;
  final bool permitirDibujar;
  final bool quitarFondoInicial;

  @override
  State<_EditorImagen> createState() => _EditorImagenState();
}

class _EditorImagenState extends State<_EditorImagen> {
  late bool _quitarFondo = widget.quitarFondoInicial;
  var _procesando = false;

  void _error(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: ColoresMarca.error),
    );
  }

  Future<void> _subir() async {
    final archivo = await archivos.elegirImagen();
    if (archivo == null) return;
    setState(() => _procesando = true);
    try {
      final png = await prepararImagen(
        archivo.bytes,
        tipo: widget.tipo,
        quitarFondo: _quitarFondo,
      );
      await widget.alCambiar(png);
    } on ImagenNoValida catch (e) {
      _error(e.mensaje);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _dibujar() async {
    final png = await showDialog<Uint8List>(
      context: context,
      builder: (_) => const DialogoFirma(),
    );
    if (png != null) await widget.alCambiar(png);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = widget.bytes;
    final tieneImagen = bytes != null;
    final vista = Container(
      height: 130,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresMarca.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: const _Ajedrez(),
        child: Center(
          child: _procesando
              ? const CircularProgressIndicator()
              : tieneImagen
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                  ),
                )
              : const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      color: ColoresMarca.textoSuave,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Sin imagen',
                      style: TextStyle(color: ColoresMarca.textoSuave),
                    ),
                  ],
                ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.ayuda,
          style: const TextStyle(fontSize: 13, color: ColoresMarca.textoSuave),
        ),
        const SizedBox(height: 12),
        vista,
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.permitirDibujar)
              FilledButton.tonalIcon(
                onPressed: _procesando ? null : _dibujar,
                icon: const Icon(Icons.gesture),
                label: Text(tieneImagen ? 'Dibujar de nuevo' : 'Dibujar firma'),
              ),
            OutlinedButton.icon(
              onPressed: _procesando ? null : _subir,
              icon: const Icon(Icons.upload_outlined),
              label: Text(
                tieneImagen ? 'Reemplazar con imagen' : 'Subir imagen',
              ),
            ),
            if (tieneImagen)
              TextButton.icon(
                onPressed: _procesando ? null : () => widget.alCambiar(null),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Quitar'),
              ),
          ],
        ),
        CheckboxListTile(
          value: _quitarFondo,
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Al subir, quitar el fondo claro (papel)'),
          onChanged: (v) => setState(() => _quitarFondo = v ?? false),
        ),
      ],
    );
  }
}

/// Fondo a cuadros para ver la transparencia.
class _Ajedrez extends CustomPainter {
  const _Ajedrez();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final gris = Paint()..color = const Color(0xFFF0F2F4);
    const lado = 12.0;
    for (var y = 0.0; y < size.height; y += lado) {
      for (var x = 0.0; x < size.width; x += lado) {
        if (((x + y) / lado).round().isOdd) {
          canvas.drawRect(Rect.fromLTWH(x, y, lado, lado), gris);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_Ajedrez old) => false;
}

/// Diálogo para dibujar la firma. Devuelve el PNG (fondo transparente).
class DialogoFirma extends StatefulWidget {
  const DialogoFirma({super.key});

  @override
  State<DialogoFirma> createState() => _DialogoFirmaState();
}

class _DialogoFirmaState extends State<DialogoFirma> {
  final _controlador = ControladorFirma();

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dibuja tu firma'),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Usa el ratón, el dedo o un lápiz digital. Se guarda con fondo '
              'transparente y recortada.',
              style: TextStyle(color: ColoresMarca.textoSuave),
            ),
            const SizedBox(height: 12),
            LienzoFirma(controlador: _controlador),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _controlador.deshacer,
          icon: const Icon(Icons.undo),
          label: const Text('Deshacer'),
        ),
        TextButton(
          onPressed: _controlador.limpiar,
          child: const Text('Borrar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ListenableBuilder(
          listenable: _controlador,
          builder: (context, _) => FilledButton(
            onPressed: _controlador.vacio
                ? null
                : () async {
                    final png = await _controlador.exportarPng();
                    if (context.mounted) Navigator.pop(context, png);
                  },
            child: const Text('Usar esta firma'),
          ),
        ),
      ],
    );
  }
}

/// Cómo se verán el encabezado y la firma en los documentos.
class VistaPreviaMedico extends StatelessWidget {
  const VistaPreviaMedico({
    super.key,
    required this.medico,
    required this.pais,
  });

  final Medico medico;
  final Pais pais;

  @override
  Widget build(BuildContext context) {
    final m = medico;
    String o(String v, String alt) => v.trim().isEmpty ? alt : v.trim();
    final secundario = [
      m.especialidad.trim(),
      if (m.registro.trim().isNotEmpty)
        '${etiquetaRegistro(pais)} ${m.registro.trim()}',
    ].where((t) => t.isNotEmpty).join(' · ');
    final contacto = [
      m.consultorio,
      m.direccion,
      m.ciudad,
      if (m.telefono.trim().isNotEmpty) 'Tel. ${m.telefono.trim()}',
      m.correo,
    ].map((t) => t.trim()).where((t) => t.isNotEmpty).join(' · ');
    const suave = TextStyle(fontSize: 12, color: ColoresMarca.textoSuave);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ColoresMarca.borde),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (m.logo != null) ...[
                SizedBox(
                  height: 44,
                  child: Image.memory(
                    m.logo!,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o(m.nombre, 'Tu nombre'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: m.nombre.trim().isEmpty
                            ? ColoresMarca.textoSuave
                            : null,
                      ),
                    ),
                    Text(
                      o(secundario, 'Especialidad · ${etiquetaRegistro(pais)}'),
                      style: suave,
                    ),
                    if (contacto.isNotEmpty) Text(contacto, style: suave),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1.2, color: Colors.black87),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 260,
              child: Column(
                children: [
                  SizedBox(
                    height: 70,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (m.sello != null)
                          SizedBox(
                            height: 70,
                            width: 80,
                            child: Image.memory(
                              m.sello!,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        if (m.firma != null)
                          SizedBox(
                            height: 56,
                            width: 160,
                            child: Image.memory(
                              m.firma!,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        if (m.firma == null && m.sello == null)
                          const Text('(firma y sello)', style: suave),
                      ],
                    ),
                  ),
                  const Divider(height: 8, color: Colors.black87),
                  Text(
                    o(m.nombre, 'Tu nombre'),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (m.registro.trim().isNotEmpty)
                    Text(
                      '${etiquetaRegistro(pais)} ${m.registro.trim()}',
                      style: suave,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
