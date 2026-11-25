import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/caja/catalogo.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/pais/perfil_pais.dart' show Opcion;
import '../../../core/widgets/campos.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';
import 'campo_pesos.dart';

/// Ajustes → Caja: servicios y tarifas (pregunta 44).
class TarjetaCaja extends ConsumerStatefulWidget {
  const TarjetaCaja({super.key});

  @override
  ConsumerState<TarjetaCaja> createState() => _TarjetaCajaState();
}

class _TarjetaCajaState extends ConsumerState<TarjetaCaja> {
  late var _servicios = [
    ...ref.read(servicioConsultorioProvider).caja.servicios,
  ];
  var _cambios = false;
  var _guardando = false;

  void _poner(int i, Servicio s) => setState(() {
    _servicios[i] = s;
    _cambios = true;
  });

  Future<void> _agregar() async {
    final caja = ref.read(servicioConsultorioProvider).caja;
    final s = await showDialog<Servicio>(
      context: context,
      builder: (_) => _DialogoServicio(base: caja.nuevoServicio()),
    );
    if (s == null || !mounted) return;
    setState(() {
      _servicios = [..._servicios, s];
      _cambios = true;
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await ref
          .read(servicioConsultorioProvider)
          .caja
          .guardarCatalogo(_servicios);
      ref.read(versionIndiceProvider.notifier).cambio();
      if (mounted) {
        setState(() => _cambios = false);
        mostrarMensaje(context, 'Catálogo de la caja guardado.');
      }
    } catch (e) {
      if (mounted) mostrarMensaje(context, mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TarjetaConsultorio(
      icono: Icons.point_of_sale_outlined,
      titulo: 'Caja',
      subtitulo: 'Servicios y tarifas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cambiar una tarifa no cambia lo ya cobrado. La valoración '
            'abonable deja su valor como crédito por 30 días para el '
            'tratamiento. Los recibos dicen que no son factura electrónica: '
            'si te corresponde facturar electrónicamente, hazlo en tu sistema '
            'de facturación (DIAN, VERIFICAR con tu contador).',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
          const SizedBox(height: 8),
          for (final (i, s) in _servicios.indexed)
            Container(
              key: ValueKey('servicio-${s.id}'),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: ColoresMarca.borde)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.nombre,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: s.activo
                                    ? null
                                    : ColoresMarca.textoSuave,
                              ),
                            ),
                            Text(
                              [
                                s.linea.etiqueta,
                                if (s.abonable) 'abonable',
                                if (s.esPaquete)
                                  'paquete de ${s.sesionesPaquete} sesiones',
                                if (!s.activo) 'inactivo',
                              ].join(' · '),
                              style: const TextStyle(
                                color: ColoresMarca.textoSuave,
                              ),
                            ),
                          ],
                        ),
                      ),
                      MergeSemantics(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Activo'),
                            Switch(
                              value: s.activo,
                              onChanged: (v) =>
                                  _poner(i, s.copyWith(activo: v)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: CampoPesos(
                      etiqueta: 'Tarifa de ${s.nombre}',
                      valorInicial: s.tarifa,
                      alCambiar: (v) => _poner(i, s.copyWith(tarifa: v ?? 0)),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: _agregar,
                icon: const Icon(Icons.add),
                label: const Text('Agregar un servicio'),
              ),
              FilledButton(
                onPressed: _guardando || !_cambios ? null : _guardar,
                child: const Text('Guardar el catálogo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _TipoServicio { servicio, abonable, paquete }

class _DialogoServicio extends ConsumerStatefulWidget {
  const _DialogoServicio({required this.base});

  final Servicio base;

  @override
  ConsumerState<_DialogoServicio> createState() => _DialogoServicioState();
}

class _DialogoServicioState extends ConsumerState<_DialogoServicio> {
  late var _s = widget.base;
  var _tipo = _TipoServicio.servicio;
  var _sesiones = 4;

  Servicio get _resultado => switch (_tipo) {
    _TipoServicio.servicio => _s.copyWith(abonable: false, sesionesPaquete: 0),
    _TipoServicio.abonable => _s.copyWith(abonable: true, sesionesPaquete: 0),
    _TipoServicio.paquete => _s.copyWith(
      abonable: false,
      sesionesPaquete: _sesiones,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final plantillas = ref
        .read(servicioConsultorioProvider)
        .procedimientos
        .plantillas;
    final valido =
        _s.nombre.trim().isNotEmpty &&
        (_tipo != _TipoServicio.paquete || _sesiones >= 2);
    return AlertDialog(
      title: const TituloDialogo('Servicio nuevo', icono: Icons.add_card),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampoTexto(
                etiqueta: 'Nombre',
                requerido: true,
                alCambiar: (v) => setState(() => _s = _s.copyWith(nombre: v)),
              ),
              const SizedBox(height: 12),
              RejillaCampos(
                anchoMinimo: 180,
                children: [
                  CampoDesplegable(
                    etiqueta: 'Línea',
                    opciones: [
                      for (final l in LineaAtencion.values)
                        Opcion(l.name, l.etiqueta),
                    ],
                    valor: _s.linea.name,
                    alCambiar: (v) => setState(
                      () => _s = _s.copyWith(
                        linea: LineaAtencion.values.byName(v),
                      ),
                    ),
                  ),
                  CampoPesos(
                    etiqueta: 'Tarifa',
                    requerido: true,
                    alCambiar: (v) =>
                        setState(() => _s = _s.copyWith(tarifa: v ?? 0)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CampoDesplegable(
                etiqueta: 'Tipo',
                opciones: const [
                  Opcion('servicio', 'Servicio'),
                  Opcion('abonable', 'Valoración abonable (crédito 30 días)'),
                  Opcion('paquete', 'Paquete de sesiones'),
                ],
                valor: _tipo.name,
                alCambiar: (v) =>
                    setState(() => _tipo = _TipoServicio.values.byName(v)),
              ),
              if (_tipo == _TipoServicio.paquete) ...[
                const SizedBox(height: 12),
                RejillaCampos(
                  anchoMinimo: 180,
                  children: [
                    CampoEntero(
                      etiqueta: 'Sesiones',
                      valor: _sesiones,
                      alCambiar: (v) => setState(() => _sesiones = v ?? 0),
                    ),
                    CampoDesplegable(
                      etiqueta: 'Procedimiento',
                      opciones: [
                        for (final p in plantillas) Opcion(p.id, p.nombre),
                      ],
                      valor: _s.plantillaId,
                      alCambiar: (v) =>
                          setState(() => _s = _s.copyWith(plantillaId: v)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: valido ? () => Navigator.pop(context, _resultado) : null,
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}
