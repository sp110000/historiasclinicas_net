import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../app/tema.dart';
import '../../core/archivos/archivos.dart' as archivos;
import '../../core/pais/pais_provider.dart';
import '../../core/pais/perfil_pais.dart';
import '../../core/pdf/historia_pdf.dart';
import '../../core/pdf/lector_adjunto.dart';
import '../../core/presentacion/datos_historia.dart';
import '../../core/utils/nombres_archivo.dart';
import '../../core/widgets/tarjeta_seccion.dart';
import '../medico/medico_provider.dart';
import 'estado/archivo_provider.dart';
import 'estado/borrador_provider.dart';
import 'estado/estado_historia.dart';
import 'estado/historia_controller.dart';
import 'estado/validacion.dart';
import 'secciones/formulario_diagnosticos.dart';
import 'secciones/formulario_paciente.dart';
import 'secciones/formulario_revision.dart';
import 'secciones/formularios_clinicos.dart';
import 'secciones/seccion_evoluciones.dart';
import 'widgets/avisos.dart';
import 'widgets/dialogos.dart';
import 'widgets/iconos.dart';
import 'widgets/indice_secciones.dart';

/// Ancho a partir del cual se muestra el índice lateral.
const _anchoEscritorio = 1180.0;

/// Por debajo de este ancho las acciones van en una barra inferior.
const _anchoMovil = 700.0;

class HistoriaPage extends ConsumerStatefulWidget {
  const HistoriaPage({super.key});

  @override
  ConsumerState<HistoriaPage> createState() => _HistoriaPageState();
}

class _HistoriaPageState extends ConsumerState<HistoriaPage> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _claves = {for (final s in SeccionHistoria.values) s: GlobalKey()};
  final _desplegadas = <SeccionHistoria>{};
  var _activa = SeccionHistoria.paciente;
  var _mostrarErrores = false;
  var _ocupado = false;
  var _alteracionAceptada = false;
  var _arrastrando = false;
  late final void Function() _dejarDeEscucharSoltar;

  HistoriaController get _ctrl => ref.read(historiaProvider.notifier);
  EstadoHistoria get _estado => ref.read(historiaProvider);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_actualizarSeccionActiva);
    _dejarDeEscucharSoltar = archivos.escucharArchivosSoltados(
      alSoltar: (a) => _cargarArchivo(a, confirmarReemplazo: true),
      alArrastrar: (v) => setState(() => _arrastrando = v),
    );
  }

  @override
  void dispose() {
    _dejarDeEscucharSoltar();
    _scroll.dispose();
    super.dispose();
  }

  // ───────────────────────── Navegación ─────────────────────────

  void _actualizarSeccionActiva() {
    SeccionHistoria? nueva;
    for (final s in SeccionHistoria.values) {
      final caja = _claves[s]!.currentContext?.findRenderObject() as RenderBox?;
      if (caja == null || !caja.attached) continue;
      if (caja.localToGlobal(Offset.zero).dy <= 190) nueva = s;
    }
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 4) {
      nueva = SeccionHistoria.evoluciones;
    }
    nueva ??= SeccionHistoria.paciente;
    if (nueva != _activa) setState(() => _activa = nueva!);
  }

  Future<void> _irA(SeccionHistoria s) async {
    if (_estado.abierta && !_desplegadas.contains(s)) {
      setState(() => _desplegadas.add(s));
      await WidgetsBinding.instance.endOfFrame;
    }
    final contexto = _claves[s]!.currentContext;
    if (contexto == null || !contexto.mounted) return;
    setState(() => _activa = s);
    await Scrollable.ensureVisible(
      contexto,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  void _subir() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _mensaje(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          backgroundColor: error ? ColoresMarca.error : null,
          behavior: SnackBarBehavior.floating,
          width: MediaQuery.sizeOf(context).width > 640 ? 560 : null,
        ),
      );
  }

  // ───────────────────────── Acciones ─────────────────────────

  Future<void> _abrirExistente() async {
    if (_estado.hayCambiosSinGuardar &&
        !await confirmar(
          context,
          titulo: '¿Abrir otra historia?',
          texto:
              'Se reemplazará lo que estás escribiendo. Lo que no hayas '
              'guardado en PDF se perderá.',
          aceptar: 'Elegir PDF',
          icono: Icons.folder_open,
        )) {
      return;
    }
    final archivo = await archivos.elegirPdf();
    if (archivo != null) await _cargarArchivo(archivo);
  }

  Future<void> _cargarArchivo(
    archivos.ArchivoAbierto archivo, {
    bool confirmarReemplazo = false,
  }) async {
    if (confirmarReemplazo &&
        _estado.hayCambiosSinGuardar &&
        !await confirmar(
          context,
          titulo: '¿Abrir ${archivo.nombre}?',
          texto:
              'Se reemplazará lo que estás escribiendo. Lo que no hayas '
              'guardado en PDF se perderá.',
          aceptar: 'Abrir',
          icono: Icons.folder_open,
        )) {
      return;
    }
    String? error;
    try {
      final paquete = leerHistoriaDePdf(archivo.bytes);
      _ctrl.abrir(
        paquete.datos,
        revision: paquete.revision,
        nombreArchivo: archivo.nombre,
      );
    } on LecturaHistoriaException catch (e) {
      error = e.mensaje;
    } on FormatException {
      error =
          'Este PDF contiene datos de historiasclinicas.net, pero no una '
          'historia clínica compatible (por ejemplo, un PDF de la prueba de '
          'concepto). Solo se pueden reabrir historias guardadas con esta versión.';
    }
    if (!mounted) return;
    if (error != null) {
      final accion = await mostrarErrorApertura(context, error);
      if (accion == 'otro') {
        await _abrirExistente();
      } else if (accion == 'nueva') {
        await _empezarDeCero(preguntar: false);
      }
      return;
    }
    ref.read(archivoActualProvider.notifier).cambiar(archivo);
    await ref.read(borradorProvider.notifier).borrar();
    setState(() {
      _desplegadas.clear();
      _mostrarErrores = false;
      _alteracionAceptada = false;
    });
    _subir();
    final integridad = _estado.integridad!;
    _mensaje(
      integridad.correcta
          ? 'Historia abierta · ${integridad.descripcion}'
          : 'Atención: ${integridad.descripcion}',
      error: !integridad.correcta,
    );
  }

  Future<void> _empezarDeCero({required bool preguntar}) async {
    if (preguntar &&
        _estado.hayCambiosSinGuardar &&
        !await confirmar(
          context,
          titulo: _estado.abierta
              ? '¿Cerrar la historia?'
              : '¿Limpiar el formulario?',
          texto: _estado.abierta
              ? 'Las evoluciones que no hayas guardado en PDF se perderán.'
              : 'Se borrará todo lo escrito y el borrador guardado en este navegador.',
          aceptar: _estado.abierta ? 'Cerrar' : 'Limpiar',
          icono: Icons.delete_sweep_outlined,
          peligro: true,
        )) {
      return;
    }
    _ctrl.limpiar();
    ref.read(archivoActualProvider.notifier).cambiar(null);
    await ref.read(borradorProvider.notifier).borrar();
    setState(() {
      _mostrarErrores = false;
      _desplegadas.clear();
      _alteracionAceptada = false;
    });
    _subir();
  }

  Future<void> _vistaPrevia() async {
    final h = _estado.historia;
    final bytes = await generarPdfHistoria(
      datos: _ctrl.datosConMedico(ref.read(medicoProvider)),
      borrador: true,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name:
          'Borrador_${nombreArchivoHistoria(primerApellido: h.paciente.primerApellido, documento: h.paciente.numeroDocumento)}',
    );
  }

  Future<void> _finalizar() async {
    setState(() => _mostrarErrores = true);
    _form.currentState?.validate();
    final pendientes = pendientesParaFinalizar(_estado.historia);
    if (pendientes.isNotEmpty) {
      final ir = await mostrarPendientes(context, pendientes);
      if (ir != null) await _irA(ir);
      return;
    }
    if (!mounted) return;
    final medico = await _comprobarMedico(
      'La historia se guardará sin tu nombre, registro, firma ni sello.',
    );
    if (medico == null || !mounted) return;
    if (!medico) {
      // Ya confirmó en el aviso del médico: se guarda sin más preguntas.
      await _guardar(sobrescribir: false);
      return;
    }
    final si = await confirmar(
      context,
      titulo: 'Finalizar y guardar la historia',
      texto:
          'Se generará el PDF con los datos incrustados y la historia quedará '
          'sellada: después solo podrás agregar evoluciones al final.',
      aceptar: 'Finalizar y guardar PDF',
      icono: Icons.lock_outline,
    );
    if (si) await _guardar(sobrescribir: false);
  }

  Future<void> _descargarActualizada({required bool sobrescribir}) async {
    final e = _estado;
    if (e.evolucionesNuevas.isEmpty) {
      _mensaje('Agrega al menos una evolución antes de descargar.');
      await _irA(SeccionHistoria.evoluciones);
      return;
    }
    if (e.evolucionesNuevas.any((x) => x.texto.trim().isEmpty)) {
      setState(() => _mostrarErrores = true);
      _form.currentState?.validate();
      _mensaje(
        'Hay una evolución sin texto: escríbela o descártala.',
        error: true,
      );
      await _irA(SeccionHistoria.evoluciones);
      return;
    }
    final medico = await _comprobarMedico(
      'Las evoluciones se guardarán sin tu nombre, registro, firma ni sello.',
    );
    if (medico == null) return;
    await _guardar(sobrescribir: sobrescribir);
  }

  /// Si faltan los datos del médico, ofrece configurarlos. Devuelve `true`
  /// si están configurados, `false` si se decide seguir sin ellos y `null`
  /// si se cancela (o se va a configurarlos).
  Future<bool?> _comprobarMedico(String consecuencia) async {
    if (ref.read(medicoProvider).configurado) return true;
    final accion = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.badge_outlined, color: ColoresMarca.aviso),
        title: const Text('Aún no configuraste tus datos de médico'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            '$consecuencia Puedes configurarlos ahora (solo una vez) y volver.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'sin'),
            child: const Text('Guardar sin mis datos'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'configurar'),
            child: const Text('Configurar ahora'),
          ),
        ],
      ),
    );
    if (accion == 'configurar' && mounted) {
      await context.push('/medico');
      return null;
    }
    return accion == 'sin' ? false : null;
  }

  /// Pide el destino (antes que nada: el navegador exige que el selector
  /// se abra justo tras el clic), genera el PDF y lo escribe.
  Future<void> _guardar({required bool sobrescribir}) async {
    final e = _estado;
    final p = e.historia.paciente;
    final nombre = nombreArchivoHistoria(
      primerApellido: p.primerApellido,
      documento: p.numeroDocumento,
      revision: e.abierta ? e.revision + 1 : 1,
    );
    final destino = await archivos.prepararGuardado(
      nombreSugerido: nombre,
      sobrescribir: sobrescribir ? ref.read(archivoActualProvider) : null,
    );
    if (destino == null) return;
    setState(() => _ocupado = true);
    try {
      final datos = _ctrl.prepararGuardado(medico: ref.read(medicoProvider));
      final bytes = await generarPdfHistoria(
        datos: datos.datos,
        revision: datos.revision,
      );
      await archivos.escribirArchivo(destino, bytes);
      _ctrl.guardado(datos, nombreArchivo: destino.nombre);
      if (!destino.esDescarga) {
        ref
            .read(archivoActualProvider.notifier)
            .cambiar(
              archivos.ArchivoAbierto(
                nombre: destino.nombre,
                bytes: bytes,
                manejador: destino.manejador,
              ),
            );
      }
      await ref.read(borradorProvider.notifier).borrar();
      setState(() {
        _mostrarErrores = false;
        _desplegadas.clear();
      });
      _mensaje(
        destino.esDescarga
            ? 'Historia guardada: ${destino.nombre} (revisa tus descargas)'
            : 'Historia guardada en ${destino.nombre}',
      );
    } catch (error) {
      _mensaje('No se pudo guardar el PDF: $error', error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _imprimirGuardada() async {
    final e = _estado;
    if (e.evolucionesNuevas.isNotEmpty) {
      _mensaje(
        'Se imprime la última versión guardada. Descarga la historia para '
        'incluir las evoluciones nuevas.',
      );
    }
    final bytes = await generarPdfHistoria(
      datos: e.datosSellados!,
      revision: e.revision,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: e.nombreArchivo ?? 'Historia.pdf',
    );
  }

  Future<void> _agregarEvolucion() async {
    if (_estado.integridadComprometida && !_alteracionAceptada) {
      final si = await confirmar(
        context,
        titulo: 'La historia presenta alteraciones',
        texto:
            '${_estado.integridad!.descripcion}. Puedes agregar la evolución '
            'igualmente: quedará registrado en ella que se agregó sobre una '
            'historia con alteraciones.',
        aceptar: 'Agregar de todos modos',
        icono: Icons.gpp_bad_outlined,
        peligro: true,
      );
      if (!si) return;
      _alteracionAceptada = true;
    }
    _ctrl.agregarEvolucion();
    await WidgetsBinding.instance.endOfFrame;
    if (_scroll.hasClients) {
      await _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _formularReceta() => context.push('/receta');

  Future<void> _cambiarPais(Pais pais) async {
    await ref.read(paisProvider.notifier).cambiar(pais);
    _ctrl.cambiarPais(pais);
  }

  // ───────────────────────── Interfaz ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(historiaProvider);
    final ancho = MediaQuery.sizeOf(context).width;
    final escritorio = ancho >= _anchoEscritorio;
    final movil = ancho < _anchoMovil;

    final contenido = Scrollbar(
      controller: _scroll,
      child: SingleChildScrollView(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(movil ? 12 : 24, 20, movil ? 12 : 24, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Form(
              key: _form,
              autovalidateMode: _mostrarErrores
                  ? AutovalidateMode.always
                  : AutovalidateMode.disabled,
              child: KeyedSubtree(
                key: ValueKey(estado.versionFormulario),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (estado.borradorRestauradoEn != null)
                      AvisoBorradorRecuperado(
                        guardadoEn: estado.borradorRestauradoEn!,
                        alContinuar: _ctrl.aceptarBorradorRestaurado,
                        alDescartar: () => _empezarDeCero(preguntar: true),
                      ),
                    const AvisoPrivacidad(),
                    if (!estado.abierta) const AvisoMedicoSinConfigurar(),
                    if (estado.abierta) AvisoHistoriaAbierta(estado: estado),
                    for (final s in SeccionHistoria.values)
                      Padding(
                        key: _claves[s],
                        padding: const EdgeInsets.only(bottom: 16),
                        // La GlobalKey conserva el estado al cambiar la
                        // versión: los campos se recrean aquí dentro para
                        // que muestren los datos nuevos.
                        child: KeyedSubtree(
                          key: ValueKey(estado.versionFormulario),
                          child: _tarjeta(s, estado),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: _barraSuperior(estado, ancho),
      body: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (escritorio) IndiceLateral(activa: _activa, alElegir: _irA),
              Expanded(
                child: Column(
                  children: [
                    if (!escritorio && !movil)
                      IndiceHorizontal(activa: _activa, alElegir: _irA),
                    Expanded(child: contenido),
                  ],
                ),
              ),
            ],
          ),
          if (_arrastrando) const _CapaSoltar(),
        ],
      ),
      bottomNavigationBar: movil ? _barraInferior(estado) : null,
    );
  }

  Widget _tarjeta(SeccionHistoria s, EstadoHistoria estado) {
    final h = estado.historia;
    final titulo = tituloSeccion(s, h.perfil);
    if (s == SeccionHistoria.evoluciones) {
      return TarjetaSeccion(
        numero: s.numero,
        titulo: titulo,
        icono: iconoSeccion(s),
        activa: estado.abierta,
        insignia: estado.abierta
            ? InsigniaSeccion.activa
            : InsigniaSeccion.ninguna,
        child: SeccionEvoluciones(alAgregar: _agregarEvolucion),
      );
    }
    if (estado.abierta) {
      final plegada = !_desplegadas.contains(s);
      return TarjetaSeccion(
        numero: s.numero,
        titulo: titulo,
        icono: iconoSeccion(s),
        bloqueada: true,
        plegada: plegada,
        resumen: resumenSeccion(s, h, medico: estado.medicoDeLaHistoria),
        insignia: InsigniaSeccion.soloLectura,
        alAlternar: () => setState(
          () => plegada ? _desplegadas.add(s) : _desplegadas.remove(s),
        ),
        child: DatosLectura(
          datosDeSeccion(s, h, medico: estado.medicoDeLaHistoria),
        ),
      );
    }
    final avance = avanceSeccion(s, h);
    return TarjetaSeccion(
      numero: s.numero,
      titulo: titulo,
      icono: iconoSeccion(s),
      insignia: s == SeccionHistoria.firma
          ? InsigniaSeccion.ninguna
          : switch (avance) {
              Avance.completa => InsigniaSeccion.completa,
              Avance.parcial => InsigniaSeccion.incompleta,
              Avance.vacia => InsigniaSeccion.ninguna,
            },
      child: switch (s) {
        SeccionHistoria.paciente => const FormularioPaciente(),
        SeccionHistoria.motivo => const FormularioMotivo(),
        SeccionHistoria.antecedentes => const FormularioAntecedentes(),
        SeccionHistoria.revision => const FormularioRevisionSistemas(),
        SeccionHistoria.signos => const FormularioSignos(),
        SeccionHistoria.examen => const FormularioExamen(),
        SeccionHistoria.analisis => const FormularioAnalisis(),
        SeccionHistoria.diagnosticos => const FormularioDiagnosticos(),
        SeccionHistoria.plan => const FormularioPlan(),
        SeccionHistoria.firma => const FormularioFirma(),
        SeccionHistoria.evoluciones => const SizedBox.shrink(),
      },
    );
  }

  PreferredSizeWidget _barraSuperior(EstadoHistoria estado, double ancho) {
    final completa = ancho >= 1240;
    final movil = ancho < _anchoMovil;
    final abierta = estado.abierta;
    final puedeSobrescribir =
        ref.watch(archivoActualProvider)?.sePuedeSobrescribir ?? false;

    Widget accionTexto(IconData icono, String texto, VoidCallback? accion) =>
        completa
        ? TextButton.icon(
            onPressed: accion,
            icon: Icon(icono),
            label: Text(texto),
          )
        : IconButton(onPressed: accion, icon: Icon(icono), tooltip: texto);

    final guardarPdf = abierta
        ? MenuAnchor(
            builder: (context, menu, _) => OutlinedButton.icon(
              onPressed: _ocupado
                  ? null
                  : () => menu.isOpen ? menu.close() : menu.open(),
              icon: const Icon(Icons.download),
              label: Text(
                completa ? 'Descargar historia actualizada' : 'Descargar',
              ),
            ),
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.file_download_outlined),
                onPressed: () => _descargarActualizada(sobrescribir: false),
                child: Text(
                  'Guardar como nueva versión (_v${estado.revision + 1})',
                ),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.save_outlined),
                onPressed: puedeSobrescribir
                    ? () => _descargarActualizada(sobrescribir: true)
                    : null,
                child: Text(
                  puedeSobrescribir
                      ? 'Sobrescribir ${ref.read(archivoActualProvider)!.nombre}'
                      : 'Sobrescribir (solo Chrome y Edge, abriendo el PDF desde aquí)',
                ),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.print_outlined),
                onPressed: _imprimirGuardada,
                child: const Text('Imprimir la versión guardada'),
              ),
            ],
          )
        : MenuAnchor(
            builder: (context, menu, _) => OutlinedButton.icon(
              onPressed: _ocupado
                  ? null
                  : () => menu.isOpen ? menu.close() : menu.open(),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(
                completa || ancho >= 900 ? 'Imprimir / Guardar PDF' : 'PDF',
              ),
            ),
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.print_outlined),
                onPressed: _vistaPrevia,
                child: const Text('Vista previa e impresión (borrador)'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.lock_outline),
                onPressed: _finalizar,
                child: const Text('Finalizar y guardar PDF'),
              ),
            ],
          );

    return AppBar(
      titleSpacing: movil ? 12 : 20,
      toolbarHeight: 64,
      title: Row(
        children: [
          const Icon(
            Icons.health_and_safety_outlined,
            color: ColoresMarca.primario,
            size: 26,
          ),
          const SizedBox(width: 10),
          const Flexible(
            child: Text(
              'historiasclinicas.net',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ),
          if (ancho >= 1000) ...[
            const SizedBox(width: 12),
            _SelectorPais(
              pais: estado.historia.pais,
              habilitado: !abierta,
              alCambiar: _cambiarPais,
            ),
          ],
        ],
      ),
      bottom: _ocupado
          ? const PreferredSize(
              preferredSize: Size.fromHeight(3),
              child: LinearProgressIndicator(minHeight: 3),
            )
          : null,
      actions: [
        if (!movil) ...[
          accionTexto(
            Icons.folder_open_outlined,
            'Abrir historia existente',
            _ocupado ? null : _abrirExistente,
          ),
          abierta
              ? accionTexto(
                  Icons.close,
                  'Cerrar historia',
                  () => _empezarDeCero(preguntar: true),
                )
              : accionTexto(
                  Icons.delete_sweep_outlined,
                  'Limpiar formulario',
                  () => _empezarDeCero(preguntar: true),
                ),
          const SizedBox(width: 8),
          guardarPdf,
          const SizedBox(width: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ColoresMarca.secundario,
            ),
            onPressed: _formularReceta,
            icon: const Text(
              '℞',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            label: const Text('Formular receta'),
          ),
        ],
        _MenuMas(
          movil: movil,
          conPais: ancho < 1000,
          estado: estado,
          alAbrir: _abrirExistente,
          alLimpiar: () => _empezarDeCero(preguntar: true),
          alCambiarPais: _cambiarPais,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _barraInferior(EstadoHistoria estado) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColoresMarca.borde)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _ocupado
                    ? null
                    : estado.abierta
                    ? () => _descargarActualizada(sobrescribir: false)
                    : _finalizar,
                icon: Icon(
                  estado.abierta ? Icons.download : Icons.lock_outline,
                ),
                label: Text(estado.abierta ? 'Descargar' : 'Guardar PDF'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresMarca.secundario,
                ),
                onPressed: _formularReceta,
                icon: const Text(
                  '℞',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                label: const Text('Receta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectorPais extends StatelessWidget {
  const _SelectorPais({
    required this.pais,
    required this.habilitado,
    required this.alCambiar,
  });

  final Pais pais;
  final bool habilitado;
  final ValueChanged<Pais> alCambiar;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Pais>(
      enabled: habilitado,
      tooltip: habilitado
          ? 'País de ejercicio'
          : 'País con el que se creó esta historia',
      initialValue: pais,
      onSelected: alCambiar,
      itemBuilder: (context) => [
        for (final p in Pais.values)
          PopupMenuItem(value: p, child: Text(p.nombre)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: ColoresMarca.primario.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.public, size: 16, color: ColoresMarca.primario),
            const SizedBox(width: 6),
            Text(
              pais.nombre,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ColoresMarca.primario,
              ),
            ),
            if (habilitado)
              const Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: ColoresMarca.primario,
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuMas extends ConsumerWidget {
  const _MenuMas({
    required this.movil,
    required this.conPais,
    required this.estado,
    required this.alAbrir,
    required this.alLimpiar,
    required this.alCambiarPais,
  });

  final bool movil;

  /// Incluye el selector de país (cuando no cabe en la barra).
  final bool conPais;
  final EstadoHistoria estado;
  final VoidCallback alAbrir;
  final VoidCallback alLimpiar;
  final ValueChanged<Pais> alCambiarPais;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borrador = ref.watch(borradorProvider);
    return MenuAnchor(
      builder: (context, menu, _) => IconButton(
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        icon: const Icon(Icons.more_vert),
        tooltip: 'Más opciones',
      ),
      menuChildren: [
        if (movil) ...[
          MenuItemButton(
            leadingIcon: const Icon(Icons.folder_open_outlined),
            onPressed: alAbrir,
            child: const Text('Abrir historia existente'),
          ),
          MenuItemButton(
            leadingIcon: Icon(
              estado.abierta ? Icons.close : Icons.delete_sweep_outlined,
            ),
            onPressed: alLimpiar,
            child: Text(
              estado.abierta ? 'Cerrar historia' : 'Limpiar formulario',
            ),
          ),
          const Divider(),
        ],
        if (conPais && !estado.abierta) ...[
          SubmenuButton(
            leadingIcon: const Icon(Icons.public),
            menuChildren: [
              for (final p in Pais.values)
                MenuItemButton(
                  onPressed: () => alCambiarPais(p),
                  child: Text(p.nombre),
                ),
            ],
            child: Text('País: ${estado.historia.pais.nombre}'),
          ),
          const Divider(),
        ],
        MenuItemButton(
          leadingIcon: const Icon(Icons.badge_outlined),
          onPressed: () => context.push('/medico'),
          child: const Text('Datos del médico'),
        ),
        const Divider(),
        MenuItemButton(
          leadingIcon: const Icon(Icons.delete_outline),
          onPressed: borrador.guardadoEn == null
              ? null
              : () => ref.read(borradorProvider.notifier).borrar(),
          child: Text(
            borrador.guardadoEn == null
                ? 'Sin borrador guardado'
                : 'Borrar el borrador (${horaCorta(borrador.guardadoEn!)})',
          ),
        ),
        CheckboxMenuButton(
          value: borrador.desactivado,
          onChanged: (v) => ref
              .read(borradorProvider.notifier)
              .cambiarDesactivado(v ?? false),
          child: const Text('No guardar borrador en este equipo'),
        ),
        const Divider(),
        MenuItemButton(
          leadingIcon: const Icon(Icons.info_outline),
          onPressed: () => mostrarAcercaDe(context),
          child: const Text('Acerca de y limitaciones'),
        ),
      ],
    );
  }
}

class _CapaSoltar extends StatelessWidget {
  const _CapaSoltar();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: ColoresMarca.primario.withValues(alpha: 0.10),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ColoresMarca.primario, width: 2),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.upload_file, color: ColoresMarca.primario, size: 32),
                SizedBox(width: 12),
                Text(
                  'Suelta aquí el PDF de la historia',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
