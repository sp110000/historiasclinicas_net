import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../app/tema.dart';
import '../../core/archivos/archivos.dart' as archivos;
import '../../core/pdf/receta_pdf.dart';
import '../../core/receta/alertas.dart';
import '../../core/utils/nombres_archivo.dart';
import '../../core/widgets/campos.dart';
import '../../core/widgets/titulo_dialogo.dart';
import '../historia/estado/historia_controller.dart';
import '../historia/widgets/dialogos.dart';
import '../medico/medico_provider.dart';
import 'estado/receta_controller.dart';
import 'widgets/editor_items.dart';
import 'widgets/mis_medicamentos.dart';
import 'widgets/paciente_y_alertas.dart';
import 'widgets/vista_previa.dart';

/// Receta de media hoja (A5 vertical): editor y vista previa real.
class RecetaPage extends ConsumerStatefulWidget {
  const RecetaPage({super.key});

  @override
  ConsumerState<RecetaPage> createState() => _RecetaPageState();
}

class _RecetaPageState extends ConsumerState<RecetaPage> {
  var _mostrarErrores = false;
  var _ocupado = false;

  RecetaController get _ctrl => ref.read(recetaProvider.notifier);

  void _volver() => context.canPop() ? context.pop() : context.go('/');

  void _mensaje(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          backgroundColor: error ? ColoresMarca.error : null,
        ),
      );
  }

  /// Comprueba la receta antes de imprimir o guardar. `false` si el médico
  /// prefiere revisarla.
  Future<bool> _comprobar() async {
    final r = ref.read(recetaProvider);
    // Puede llevar solo indicaciones (recomendaciones sin medicamentos), pero
    // no salir en blanco.
    if (r.sinContenido) {
      _mensaje(
        'Escribe al menos un medicamento o unas indicaciones.',
        error: true,
      );
      return false;
    }
    final faltan = [
      for (final (i, item) in r.items.indexed)
        if (!item.vacio && item.faltantes.isNotEmpty)
          'Medicamento ${i + 1}: ${item.faltantes.join(', ')}',
    ];
    if (faltan.isNotEmpty) {
      setState(() => _mostrarErrores = true);
      final seguir = await _preguntar(
        titulo: 'Faltan datos en la receta',
        icono: Icons.playlist_add_check,
        contenido: [
          const Text('Revisa lo que falta:'),
          const SizedBox(height: 8),
          for (final f in faltan) Text('• $f'),
        ],
        cancelar: 'Revisar',
        aceptar: 'Continuar igualmente',
      );
      if (!seguir) return false;
    }
    final pendientes = ref
        .read(alertasAlergiaProvider)
        .where(
          (a) =>
              a.gravedad == GravedadAlerta.alta &&
              !r.alertasVistas.contains(a.clave),
        )
        .toList();
    if (pendientes.isNotEmpty) {
      final seguir = await _preguntar(
        titulo: 'Hay alertas de alergia sin revisar',
        icono: Icons.warning_amber_rounded,
        peligro: true,
        contenido: [for (final a in pendientes) Text('• ${a.texto}')],
        cancelar: 'Revisar',
        aceptar: 'Continuar igualmente',
      );
      if (!seguir) return false;
      for (final a in pendientes) {
        _ctrl.marcarAlertaVista(a.clave);
      }
    }
    if (!ref.read(medicoProvider).configurado && mounted) {
      final accion = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const TituloDialogo(
            'Aún no configuraste tus datos de médico',
            icono: Icons.badge_outlined,
            color: ColoresMarca.aviso,
          ),
          actionsOverflowDirection: VerticalDirection.up,
          actionsOverflowButtonSpacing: 8,
          content: const Text(
            'La receta saldrá sin tu nombre, registro, firma ni sello.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'sin'),
              child: const Text('Continuar sin mis datos'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'configurar'),
              child: const Text('Configurar ahora'),
            ),
          ],
        ),
      );
      if (accion == 'configurar' && mounted) await context.push('/medico');
      if (accion != 'sin') return false;
    }
    return true;
  }

  Future<bool> _preguntar({
    required String titulo,
    required IconData icono,
    required List<Widget> contenido,
    required String cancelar,
    required String aceptar,
    bool peligro = false,
  }) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: TituloDialogo(
          titulo,
          icono: icono,
          color: peligro ? ColoresMarca.error : ColoresMarca.aviso,
        ),
        actionsOverflowDirection: VerticalDirection.up,
        actionsOverflowButtonSpacing: 8,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: contenido,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(aceptar),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelar),
          ),
        ],
      ),
    );
    return si ?? false;
  }

  String get _nombreArchivo => nombreArchivoReceta(
    primerApellido: ref.read(historiaProvider).historia.paciente.primerApellido,
    fecha: ref.read(recetaProvider).fecha,
  );

  Future<Uint8List> _generar() async {
    await _ctrl.prepararParaImprimir();
    return generarPdfReceta(ref.read(documentoRecetaProvider));
  }

  Future<void> _imprimir() async {
    if (_ocupado || !await _comprobar()) return;
    setState(() => _ocupado = true);
    final Uint8List bytes;
    try {
      bytes = await _generar();
    } catch (e) {
      _mensaje('No se pudo generar la receta: $e', error: true);
      return;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
    // No se espera al diálogo de impresión: en navegadores sin visor de PDF
    // nunca avisa de que terminó y la pantalla quedaría bloqueada.
    unawaited(
      Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: _nombreArchivo,
        format: PdfPageFormat.a5,
      ).catchError((Object e) {
        if (mounted) _mensaje('No se pudo imprimir: $e', error: true);
        return false;
      }),
    );
    await _ofrecerRegistro();
  }

  Future<void> _guardarPdf() async {
    if (_ocupado || !await _comprobar()) return;
    final destino = await archivos.prepararGuardado(
      nombreSugerido: _nombreArchivo,
      descripcion: 'Receta (PDF)',
    );
    if (destino == null) return;
    setState(() => _ocupado = true);
    try {
      await archivos.escribirArchivo(destino, await _generar());
      _mensaje(
        destino.esDescarga
            ? 'Receta guardada: ${destino.nombre} (revisa tus descargas)'
            : 'Receta guardada en ${destino.nombre}',
      );
    } catch (e) {
      _mensaje('No se pudo guardar el PDF: $e', error: true);
      return;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
    await _ofrecerRegistro();
  }

  /// Ofrece agregar "Se formuló: …" al plan (historia nueva) o a la
  /// evolución en curso (historia abierta).
  Future<void> _ofrecerRegistro() async {
    final r = ref.read(recetaProvider);
    if (r.registradaEnHistoria || !mounted) return;
    final abierta = ref.read(historiaProvider).abierta;
    final texto = r.textoParaHistoria();
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TituloDialogo(
          '¿Registrar la receta en la historia?',
          icono: Icons.note_add_outlined,
        ),
        actionsOverflowDirection: VerticalDirection.up,
        actionsOverflowButtonSpacing: 8,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                abierta
                    ? 'Se agregará al final de la evolución en curso (o en '
                          'una evolución nueva):'
                    : 'Se agregará al final del plan de tratamiento:',
              ),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ColoresMarca.fondo,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ColoresMarca.borde),
                ),
                child: SingleChildScrollView(
                  child: Text(texto, style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Registrar en la historia'),
          ),
        ],
      ),
    );
    if (si != true) return;
    final lugar = ref.read(historiaProvider.notifier).registrarReceta(texto);
    _ctrl.marcarRegistrada();
    _mensaje('Receta registrada en $lugar.');
  }

  Future<void> _nuevaReceta() async {
    final r = ref.read(recetaProvider);
    if (!r.sinContenido &&
        !await confirmar(
          context,
          titulo: '¿Empezar otra receta?',
          texto:
              'Se vaciará esta receta. Si ya la imprimiste o guardaste, el PDF '
              'no cambia.',
          aceptar: 'Empezar otra',
          icono: Icons.note_add_outlined,
        )) {
      return;
    }
    _ctrl.nueva();
    setState(() => _mostrarErrores = false);
  }

  Future<void> _continuarNumeracion() async {
    final ultimo = ref.read(recetaStoreProvider).ultimoNumero;
    final control = TextEditingController(text: '$ultimo');
    final valor = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Continuar la numeración'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Último número usado (por ejemplo, el de tu talonario o el de '
              'otro equipo). La próxima receta tendrá el siguiente.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: control,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Último número'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(control.text)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    control.dispose();
    if (valor == null) return;
    await ref.read(opcionesRecetaProvider.notifier).continuarDesde(valor);
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final dosColumnas = ancho >= 1100;
    final movil = ancho < 700;

    final acciones = <Widget>[
      if (!movil) ...[
        TextButton.icon(
          onPressed: () => mostrarMisMedicamentos(context),
          icon: const Icon(Icons.bookmarks_outlined),
          label: const Text('Mis medicamentos'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _ocupado ? null : _guardarPdf,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Guardar PDF'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _ocupado ? null : _imprimir,
          icon: const Icon(Icons.print_outlined),
          label: const Text('Imprimir'),
        ),
      ],
      MenuAnchor(
        builder: (context, menu, _) => IconButton(
          tooltip: 'Más opciones de la receta',
          onPressed: () => menu.isOpen ? menu.close() : menu.open(),
          icon: const Icon(Icons.more_vert),
        ),
        menuChildren: [
          MenuItemButton(
            leadingIcon: const Icon(Icons.note_add_outlined),
            onPressed: _nuevaReceta,
            child: const Text('Nueva receta'),
          ),
          if (movil)
            MenuItemButton(
              leadingIcon: const Icon(Icons.bookmarks_outlined),
              onPressed: () => mostrarMisMedicamentos(context),
              child: const Text('Mis medicamentos'),
            ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.pin_outlined),
            onPressed: _continuarNumeracion,
            child: const Text('Continuar numeración desde…'),
          ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.badge_outlined),
            onPressed: () => context.push('/medico'),
            child: const Text('Datos del médico'),
          ),
        ],
      ),
      const SizedBox(width: 8),
    ];

    final editor = _Editor(mostrarErrores: _mostrarErrores);
    final vistaPrevia = Container(
      color: const Color(0xFFE6EBEF),
      child: const VistaPreviaReceta(),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _volver,
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver a la historia',
        ),
        titleSpacing: 0,
        title: const Text(
          'Receta',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: acciones,
      ),
      body: Stack(
        children: [
          if (dosColumnas)
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: editor),
                SizedBox(width: ancho >= 1400 ? 600 : 500, child: vistaPrevia),
              ],
            )
          else
            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const Material(
                    color: Colors.white,
                    child: TabBar(
                      tabs: [
                        Tab(text: 'Editar'),
                        Tab(text: 'Vista previa'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [editor, vistaPrevia],
                    ),
                  ),
                ],
              ),
            ),
          if (_ocupado)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
      bottomNavigationBar: movil
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _ocupado ? null : _guardarPdf,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Guardar PDF'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _ocupado ? null : _imprimir,
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Imprimir'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

/// Columna de edición: paciente, alertas, medicamentos, indicaciones y
/// opciones de impresión.
class _Editor extends ConsumerWidget {
  const _Editor({required this.mostrarErrores});

  final bool mostrarErrores;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recetaId = ref.watch(recetaProvider.select((r) => r.id));
    final movil = MediaQuery.sizeOf(context).width < 700;
    return ListView(
      padding: EdgeInsets.fromLTRB(movil ? 12 : 24, 16, movil ? 12 : 24, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Seccion(
                  icono: Icons.person_outline,
                  titulo: 'Paciente',
                  child: DatosPacienteReceta(),
                ),
                const AlertasReceta(),
                _Seccion(
                  icono: Icons.medication_outlined,
                  titulo: 'Medicamentos',
                  child: ListaItemsReceta(mostrarErrores: mostrarErrores),
                ),
                _Seccion(
                  icono: Icons.notes_outlined,
                  titulo: 'Indicaciones y recomendaciones',
                  child: CampoTexto(
                    key: ValueKey('indicaciones-$recetaId'),
                    etiqueta: 'Indicaciones y recomendaciones para el paciente',
                    pista: 'Líquidos abundantes, signos de alarma, control…',
                    lineas: 3,
                    valorInicial: ref.read(recetaProvider).indicaciones,
                    alCambiar: (v) => ref
                        .read(recetaProvider.notifier)
                        .actualizar((r) => r.copyWith(indicaciones: v)),
                  ),
                ),
                const _Seccion(
                  icono: Icons.tune,
                  titulo: 'Opciones de la hoja',
                  child: _OpcionesHoja(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OpcionesHoja extends ConsumerWidget {
  const _OpcionesHoja();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(recetaProvider);
    final opciones = ref.watch(opcionesRecetaProvider);
    final medico = ref.watch(medicoProvider);
    final ctrl = ref.read(recetaProvider.notifier);
    final hoy = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!medico.configurado)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(Icons.badge_outlined, color: ColoresMarca.aviso),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Configura tus datos de médico para que aparezcan tu '
                    'nombre, registro, firma y sello.',
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/medico'),
                  child: const Text('Configurar'),
                ),
              ],
            ),
          ),
        FilaCampos(
          children: [
            CampoFecha(
              key: ValueKey('fecha-${r.id}'),
              etiqueta: 'Fecha de la receta',
              valor: r.fecha,
              primera: DateTime(hoy.year - 1),
              ultima: DateTime(hoy.year + 1, 12, 31),
              alCambiar: (f) {
                if (f != null) ctrl.actualizar((r) => r.copyWith(fecha: f));
              },
            ),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: titulosReceta.contains(opciones.titulo)
                  ? opciones.titulo
                  : titulosReceta.first,
              decoration: const InputDecoration(
                labelText: 'Título de la hoja',
                helperText:
                    'En España, VERIFICAR si debe ser "Hoja de '
                    'tratamiento"',
              ),
              items: [
                for (final t in titulosReceta)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (t) {
                if (t != null) {
                  ref.read(opcionesRecetaProvider.notifier).cambiarTitulo(t);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 24,
          children: [
            _Interruptor(
              texto: 'Incluir firma',
              valor: r.incluirFirma,
              alCambiar: (v) =>
                  ctrl.actualizar((r) => r.copyWith(incluirFirma: v)),
            ),
            _Interruptor(
              texto: 'Incluir sello',
              valor: r.incluirSello,
              alCambiar: (v) =>
                  ctrl.actualizar((r) => r.copyWith(incluirSello: v)),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: opciones.numerar,
          title: const Text('Numerar las recetas'),
          subtitle: Text(
            r.numero != null
                ? 'Esta receta tiene el número ${r.numero}.'
                : opciones.numerar
                ? 'Recibirá el ${opciones.proximoNumero} al imprimir o '
                      'guardar. El contador es de este navegador.'
                : 'Formato R-000001. El contador es de este navegador.',
          ),
          onChanged: (v) =>
              ref.read(opcionesRecetaProvider.notifier).cambiarNumerar(v),
        ),
        const Text(
          'La firma y el sello son imágenes, no una firma digital certificada. '
          'Los medicamentos de control especial pueden requerir recetario '
          'oficial (VERIFICAR).',
          style: TextStyle(fontSize: 12.5, color: ColoresMarca.textoSuave),
        ),
      ],
    );
  }
}

class _Interruptor extends StatelessWidget {
  const _Interruptor({
    required this.texto,
    required this.valor,
    required this.alCambiar,
  });

  final String texto;
  final bool valor;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(value: valor, onChanged: alCambiar),
        const SizedBox(width: 6),
        Text(texto),
      ],
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.icono,
    required this.titulo,
    required this.child,
  });

  final IconData icono;
  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final movil = MediaQuery.sizeOf(context).width < 600;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(movil ? 16 : 20),
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
                child: Icon(icono, size: 20, color: ColoresMarca.primario),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
