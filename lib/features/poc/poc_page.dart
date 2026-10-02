import 'dart:async';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../app/tema.dart';
import '../../core/archivos/archivos.dart' as archivos;
import '../../core/pdf/adjunto_historia.dart';
import '../../core/pdf/lector_adjunto.dart';
import '../../core/utils/fechas.dart';
import '../../core/utils/ids.dart';
import '../../core/utils/nombres_archivo.dart';
import 'historia_poc.dart';
import 'pdf_historia_poc.dart';

/// Fase 0: crear → guardar PDF con JSON incrustado → reabrir → agregar
/// evolución → descargar versión actualizada. Todo en el navegador.
class PocPage extends StatefulWidget {
  const PocPage({super.key});

  @override
  State<PocPage> createState() => _PocPageState();
}

class _PocPageState extends State<PocPage> {
  static const _tiposDocumento = [
    'CC', 'TI', 'CE', 'PA', 'RC', 'PPT', 'DNI', 'NIE', 'Pasaporte', //
  ];

  final _form = GlobalKey<FormState>();
  final _primerApellido = TextEditingController(text: 'Peña');
  final _segundoApellido = TextEditingController(text: 'Muñoz');
  final _nombres = TextEditingController(text: 'José Ángel');
  final _documento = TextEditingController(text: '1032456789');
  final _motivo = TextEditingController(
    text:
        'Odinofagia y fiebre de 2 días de evolución. Prueba de caracteres: '
        'ñ Ñ á é í ó ú ü, «comillas», 38,5 °C, SpO₂ 97 %, “citas” — guion.',
  );
  final _evolucion = TextEditingController();
  String _tipoDocumento = 'CC';

  /// Datos ya guardados en un PDF (bloqueados).
  HistoriaPoc? _historia;

  /// Evoluciones aún no guardadas: editables hasta la próxima descarga.
  final _nuevas = <EvolucionPoc>[];
  int _revision = 0;
  String? _nombreArchivo;

  /// Archivo con el que se puede sobrescribir (Chrome y Edge).
  archivos.ArchivoAbierto? _archivo;

  bool _arrastrando = false;
  bool _ocupado = false;
  final _registro = <_Linea>[];
  late final void Function() _dejarDeEscuchar;

  @override
  void initState() {
    super.initState();
    _dejarDeEscuchar = archivos.escucharArchivosSoltados(
      alSoltar: _cargar,
      alArrastrar: (v) {
        if (mounted) setState(() => _arrastrando = v);
      },
    );
  }

  @override
  void dispose() {
    _dejarDeEscuchar();
    for (final c in [
      _primerApellido,
      _segundoApellido,
      _nombres,
      _documento,
      _motivo,
      _evolucion,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _anotar(String texto, {bool error = false}) {
    if (!mounted) return;
    setState(() => _registro.insert(0, _Linea(DateTime.now(), texto, error)));
  }

  static String _kb(int bytes) =>
      '${(bytes / 1024).toStringAsFixed(1).replaceAll('.', ',')} KB';

  // ───────────────────────── Acciones ─────────────────────────

  Future<void> _finalizarYGuardar() async {
    if (!_form.currentState!.validate()) return;
    final historia = HistoriaPoc(
      id: nuevoUuid(),
      creadaEn: DateTime.now(),
      primerApellido: _primerApellido.text.trim(),
      segundoApellido: _segundoApellido.text.trim(),
      nombres: _nombres.text.trim(),
      tipoDocumento: _tipoDocumento,
      numeroDocumento: _documento.text.trim(),
      motivoConsulta: _motivo.text.trim(),
    );
    await _guardar(historia, revision: 1, sobrescribir: false);
  }

  Future<void> _descargarActualizada({required bool sobrescribir}) async {
    final historia = _historia!;
    if (_nuevas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos una evolución antes de descargar.'),
        ),
      );
      return;
    }
    await _guardar(
      historia.conEvoluciones([...historia.evoluciones, ..._nuevas]),
      revision: _revision + 1,
      sobrescribir: sobrescribir,
    );
  }

  /// Pide el destino, genera el PDF y lo escribe. Si todo va bien, lo
  /// guardado queda sellado.
  Future<void> _guardar(
    HistoriaPoc historia, {
    required int revision,
    required bool sobrescribir,
  }) async {
    final nombre = nombreArchivoHistoria(
      primerApellido: historia.primerApellido,
      documento: historia.numeroDocumento,
      revision: revision,
    );
    // El selector se abre antes de generar: el navegador lo exige justo
    // después del clic.
    final destino = await archivos.prepararGuardado(
      nombreSugerido: nombre,
      sobrescribir: sobrescribir ? _archivo : null,
    );
    if (destino == null) {
      _anotar('Guardado cancelado.');
      return;
    }
    setState(() => _ocupado = true);
    try {
      final reloj = Stopwatch()..start();
      final bytes = await generarPdfHistoriaPoc(
        historia,
        revision: revision,
        guardadoEn: DateTime.now(),
      );
      await archivos.escribirArchivo(destino, bytes);
      setState(() {
        _historia = historia;
        _nuevas.clear();
        _revision = revision;
        _nombreArchivo = destino.nombre;
        if (!destino.esDescarga) {
          _archivo = archivos.ArchivoAbierto(
            nombre: destino.nombre,
            bytes: bytes,
            manejador: destino.manejador,
          );
        }
      });
      _anotar(
        '✓ ${destino.esDescarga ? 'Descargado' : 'Guardado'} '
        '${destino.nombre} · ${_kb(bytes.length)} · revisión $revision · '
        '${historia.evoluciones.length} evoluciones · '
        '${reloj.elapsedMilliseconds} ms',
      );
    } catch (e) {
      _anotar('✗ No se pudo guardar: $e', error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _abrir() async {
    final archivo = await archivos.elegirPdf();
    if (archivo != null) await _cargar(archivo);
  }

  Future<void> _cargar(archivos.ArchivoAbierto archivo) async {
    if (_nuevas.isNotEmpty &&
        !await _confirmar(
          'Hay evoluciones sin guardar',
          'Si abres otro archivo se perderán. ¿Continuar?',
        )) {
      return;
    }
    final reloj = Stopwatch()..start();
    try {
      final paquete = leerHistoriaDePdf(archivo.bytes);
      final HistoriaPoc historia;
      try {
        historia = HistoriaPoc.desdeMapa(paquete.datos);
      } on Object catch (e) {
        throw LecturaHistoriaException(FalloLectura.danado, 'modelo: $e');
      }
      setState(() {
        _historia = historia;
        _nuevas.clear();
        _revision = paquete.revision;
        _nombreArchivo = archivo.nombre;
        _archivo = archivo;
      });
      _anotar(
        '✓ Abierto ${archivo.nombre} · ${_kb(archivo.bytes.length)} · '
        '$nombreAdjuntoHistoria revisión ${paquete.revision} · hash de datos '
        '${paquete.hashDatos.substring(0, 12)}… verificado · '
        '${historia.evoluciones.length} evoluciones · '
        '${reloj.elapsedMilliseconds} ms'
        '${archivo.sePuedeSobrescribir ? ' · se puede sobrescribir' : ''}',
      );
    } on LecturaHistoriaException catch (e) {
      _anotar(
        '✗ ${archivo.nombre}: ${e.fallo.name} (${e.detalle ?? '—'})',
        error: true,
      );
      await _mostrarErrorApertura(e);
    }
  }

  Future<void> _mostrarErrorApertura(LecturaHistoriaException e) async {
    final accion = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: ColoresMarca.error),
        title: const Text('No se pudo abrir la historia'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(e.mensaje),
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
    if (accion == 'otro') {
      await _abrir();
    } else if (accion == 'nueva') {
      _limpiar();
    }
  }

  void _agregarEvolucion() {
    final texto = _evolucion.text.trim();
    if (texto.isEmpty) return;
    setState(() {
      _nuevas.add(EvolucionPoc(fechaHora: DateTime.now(), texto: texto));
      _evolucion.clear();
    });
  }

  Future<void> _imprimir() async {
    final historia = _historia;
    if (historia == null) return;
    final bytes = await generarPdfHistoriaPoc(
      historia,
      revision: _revision,
      guardadoEn: DateTime.now(),
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: _nombreArchivo ?? 'Historia.pdf',
    );
  }

  Future<void> _nuevaHistoria() async {
    if (_historia == null && _nuevas.isEmpty) return;
    if (await _confirmar(
      '¿Empezar una historia nueva?',
      'Se cerrará la historia actual. Lo que no hayas guardado se perderá.',
    )) {
      _limpiar();
    }
  }

  void _limpiar() => setState(() {
    _historia = null;
    _nuevas.clear();
    _revision = 0;
    _nombreArchivo = null;
    _archivo = null;
  });

  Future<bool> _confirmar(String titulo, String texto) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    return si ?? false;
  }

  // ───────────────────────── Interfaz ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final estrecho = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            const Icon(
              Icons.health_and_safety_outlined,
              color: ColoresMarca.primario,
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'historiasclinicas.net',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            if (!estrecho) ...[
              const SizedBox(width: 12),
              const Flexible(child: _Etiqueta('Fase 0 · prueba de concepto')),
            ],
          ],
        ),
        actions: [
          _AccionBarra(
            estrecho: estrecho,
            icono: Icons.folder_open_outlined,
            texto: 'Abrir historia existente',
            onPressed: _ocupado ? null : _abrir,
          ),
          _AccionBarra(
            estrecho: estrecho,
            icono: Icons.note_add_outlined,
            texto: 'Nueva historia',
            onPressed: _ocupado ? null : _nuevaHistoria,
          ),
          const SizedBox(width: 12),
        ],
        bottom: _ocupado
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_historia == null)
                      _tarjetaNueva()
                    else ...[
                      _bannerAbierta(),
                      const SizedBox(height: 16),
                      _tarjetaBloqueada(_historia!),
                      const SizedBox(height: 16),
                      _tarjetaEvoluciones(_historia!),
                    ],
                    const SizedBox(height: 16),
                    const _TarjetaLimitaciones(),
                    const SizedBox(height: 16),
                    _tarjetaRegistro(),
                  ],
                ),
              ),
            ),
          ),
          if (_arrastrando) const _CapaSoltar(),
        ],
      ),
    );
  }

  Widget _tarjetaNueva() {
    String? requerido(String? v) =>
        (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;
    return _Tarjeta(
      icono: Icons.person_outline,
      titulo: 'Historia nueva',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Fila([
              TextFormField(
                controller: _primerApellido,
                decoration: const InputDecoration(
                  labelText: 'Primer apellido *',
                ),
                validator: requerido,
              ),
              TextFormField(
                controller: _segundoApellido,
                decoration: const InputDecoration(
                  labelText: 'Segundo apellido',
                ),
              ),
              TextFormField(
                controller: _nombres,
                decoration: const InputDecoration(labelText: 'Nombres *'),
                validator: requerido,
              ),
            ]),
            const SizedBox(height: 12),
            _Fila([
              DropdownButtonFormField<String>(
                initialValue: _tipoDocumento,
                decoration: const InputDecoration(
                  labelText: 'Tipo de documento *',
                ),
                items: [
                  for (final t in _tiposDocumento)
                    DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) => setState(() => _tipoDocumento = v!),
              ),
              TextFormField(
                controller: _documento,
                decoration: const InputDecoration(
                  labelText: 'Número de documento *',
                ),
                validator: requerido,
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _motivo,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Motivo de consulta *',
                alignLabelWithHint: true,
              ),
              validator: requerido,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _ocupado ? null : _finalizarYGuardar,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Finalizar y guardar PDF'),
                ),
                const Text(
                  'Al guardar, la historia queda sellada: después solo se '
                  'podrán agregar evoluciones.',
                  style: TextStyle(
                    color: ColoresMarca.textoSuave,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerAbierta() {
    final selladas = _historia!.evoluciones.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4F0),
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: ColoresMarca.secundario, width: 5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.folder_open, color: ColoresMarca.secundario),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Historia abierta · ${_nombreArchivo ?? ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Revisión $_revision · creada '
                  '${formatoFecha(_historia!.creadaEn)} · '
                  '$selladas ${selladas == 1 ? 'evolución sellada' : 'evoluciones selladas'}'
                  ' · datos verificados ✓',
                ),
                const SizedBox(height: 4),
                const Text(
                  'Solo puedes agregar evoluciones. El bloqueo de lo anterior lo '
                  'aplica esta aplicación, no el PDF.',
                  style: TextStyle(
                    color: ColoresMarca.textoSuave,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaBloqueada(HistoriaPoc h) {
    return _Tarjeta(
      icono: Icons.person_outline,
      titulo: 'Datos de la historia',
      bloqueada: true,
      accion: const _Etiqueta('Solo lectura', icono: Icons.lock_outline),
      child: Wrap(
        spacing: 32,
        runSpacing: 14,
        children: [
          _Dato('Apellidos', h.apellidos.toUpperCase()),
          _Dato('Nombres', h.nombres),
          _Dato('Documento', '${h.tipoDocumento} ${h.numeroDocumento}'),
          _Dato('Fecha de la atención', formatoFechaHora(h.creadaEn)),
          _Dato('Motivo de consulta', h.motivoConsulta, ancho: 760),
        ],
      ),
    );
  }

  Widget _tarjetaEvoluciones(HistoriaPoc h) {
    final puedeSobrescribir = _archivo?.sePuedeSobrescribir ?? false;
    return _Tarjeta(
      icono: Icons.timeline,
      titulo: 'Evoluciones',
      activa: true,
      accion: const _Etiqueta('Zona activa', icono: Icons.edit_outlined),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (h.evoluciones.isEmpty && _nuevas.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Aún no hay evoluciones.',
                style: TextStyle(color: ColoresMarca.textoSuave),
              ),
            ),
          for (final (i, e) in h.evoluciones.indexed)
            _EntradaEvolucion(numero: i + 1, evolucion: e, sellada: true),
          for (final (i, e) in _nuevas.indexed)
            _EntradaEvolucion(
              numero: h.evoluciones.length + i + 1,
              evolucion: e,
              sellada: false,
              alEliminar: () => setState(() => _nuevas.removeAt(i)),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _evolucion,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Nueva evolución',
              hintText: 'Escribe la evolución del paciente…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: _agregarEvolucion,
              icon: const Icon(Icons.add),
              label: const Text('Agregar evolución'),
            ),
          ),
          const Divider(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _ocupado
                    ? null
                    : () => _descargarActualizada(sobrescribir: false),
                icon: const Icon(Icons.download),
                label: const Text('Descargar historia actualizada'),
              ),
              if (puedeSobrescribir)
                OutlinedButton.icon(
                  onPressed: _ocupado
                      ? null
                      : () => _descargarActualizada(sobrescribir: true),
                  icon: const Icon(Icons.save_outlined),
                  label: Text('Sobrescribir ${_archivo!.nombre}'),
                ),
              OutlinedButton.icon(
                onPressed: _ocupado ? null : _imprimir,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Imprimir'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tarjetaRegistro() {
    return _Tarjeta(
      icono: Icons.receipt_long_outlined,
      titulo: 'Registro de la prueba',
      child: _registro.isEmpty
          ? const Text(
              'Aquí aparecerá cada operación (guardar, abrir, verificar).',
              style: TextStyle(color: ColoresMarca.textoSuave),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final l in _registro)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${formatoFechaHora(l.hora).substring(11)}  ${l.texto}',
                      style: TextStyle(
                        fontSize: 13,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: l.error ? ColoresMarca.error : null,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Linea {
  _Linea(this.hora, this.texto, this.error);
  final DateTime hora;
  final String texto;
  final bool error;
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.icono,
    required this.titulo,
    required this.child,
    this.accion,
    this.bloqueada = false,
    this.activa = false,
  });

  final IconData icono;
  final String titulo;
  final Widget child;
  final Widget? accion;
  final bool bloqueada;
  final bool activa;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bloqueada ? ColoresMarca.bloqueado : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activa ? ColoresMarca.primario : ColoresMarca.borde,
          width: activa ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: ColoresMarca.primario.withValues(alpha: 0.1),
                child: Icon(icono, size: 18, color: ColoresMarca.primario),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              ?accion,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto, {this.icono});

  final String texto;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ColoresMarca.primario.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 14, color: ColoresMarca.primario),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: ColoresMarca.primario,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccionBarra extends StatelessWidget {
  const _AccionBarra({
    required this.estrecho,
    required this.icono,
    required this.texto,
    required this.onPressed,
  });

  final bool estrecho;
  final IconData icono;
  final String texto;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => estrecho
      ? IconButton(onPressed: onPressed, icon: Icon(icono), tooltip: texto)
      : TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icono),
          label: Text(texto),
        );
}

/// Coloca los campos en columnas en pantallas anchas y apilados en móvil.
class _Fila extends StatelessWidget {
  const _Fila(this.campos);

  final List<Widget> campos;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 560) {
          return Column(
            children: [
              for (final (i, campo) in campos.indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                campo,
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, campo) in campos.indexed) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: campo),
            ],
          ],
        );
      },
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor, {this.ancho = 220});

  final String etiqueta;
  final String valor;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: ancho),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w500,
              color: ColoresMarca.textoSuave,
            ),
          ),
          const SizedBox(height: 3),
          Text(valor, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

class _EntradaEvolucion extends StatelessWidget {
  const _EntradaEvolucion({
    required this.numero,
    required this.evolucion,
    required this.sellada,
    this.alEliminar,
  });

  final int numero;
  final EvolucionPoc evolucion;
  final bool sellada;
  final VoidCallback? alEliminar;

  @override
  Widget build(BuildContext context) {
    final color = sellada ? ColoresMarca.textoSuave : ColoresMarca.primario;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
      decoration: BoxDecoration(
        color: sellada ? ColoresMarca.bloqueado : const Color(0xFFF2F8FB),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      sellada ? Icons.lock_outline : Icons.edit_note,
                      size: 16,
                      color: color,
                    ),
                    Text(
                      'Evolución $numero · ${formatoFechaHora(evolucion.fechaHora)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      sellada ? 'sellada' : 'nueva · se sellará al descargar',
                      style: TextStyle(fontSize: 12, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(evolucion.texto),
              ],
            ),
          ),
          if (alEliminar != null)
            IconButton(
              onPressed: alEliminar,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Descartar evolución',
            ),
        ],
      ),
    );
  }
}

class _TarjetaLimitaciones extends StatelessWidget {
  const _TarjetaLimitaciones();

  @override
  Widget build(BuildContext context) {
    const puntos = [
      'Todo se procesa en este navegador: ningún dato se envía a un servidor.',
      'El único registro es el PDF que descargas, con los datos incrustados. '
          'Si lo pierdes o se daña, se pierde la historia: guarda copias de respaldo.',
      'Solo se pueden reabrir PDF generados por historiasclinicas.net.',
      'Si otro programa modifica o vuelve a guardar el PDF (incluido '
          '"imprimir a PDF"), los datos incrustados pueden perderse.',
      'El bloqueo de lo anterior lo aplica esta aplicación, no el PDF.',
    ];
    return _Tarjeta(
      icono: Icons.info_outline,
      titulo: 'Antes de usarla',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in puntos)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '•  ',
                    style: TextStyle(color: ColoresMarca.primario),
                  ),
                  Expanded(
                    child: Text(p, style: const TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ),
        ],
      ),
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
