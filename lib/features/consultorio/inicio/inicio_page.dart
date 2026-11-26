import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/agenda/cita.dart';
import '../../../core/consultorio/agenda/horario.dart';
import '../../../core/consultorio/agenda/recordatorio.dart' show diaLargo;
import '../../../core/consultorio/caja/catalogo.dart' show formatoPesos;
import '../../../core/widgets/ilustraciones.dart';
import '../../../core/widgets/tarjeta_seccion.dart' show sombraTarjeta;
import '../../medico/medico_provider.dart';
import '../agenda/acciones_cita.dart';
import '../buscador/buscador.dart' show inicialesFicha;
import '../agenda/dialogo_cita.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../estado/presentacion_provider.dart';

/// Inicio del consultorio (docs/REDISENO.md, R2): responde «¿qué sigue?».
/// Arriba, el siguiente paciente con «Empezar consulta»; debajo, las citas
/// que siguen, lo pendiente y el día en números. Todo sale de la agenda, la
/// caja y el inventario; en modo presentación no muestra montos.
class InicioPage extends ConsumerWidget {
  const InicioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(versionIndiceProvider);
    final s = ref.read(servicioConsultorioProvider);
    final medico = ref.watch(medicoProvider);
    final ahora = s.reloj.ahora();
    final hoy = s.agenda.citasDelDia(ahora);
    final abiertas = [
      for (final c in hoy)
        if (!c.estado.cerrada && c.fin.isAfter(ahora)) c,
    ];
    final ancho = MediaQuery.sizeOf(context).width;
    final movil = ancho < 700;
    final dosColumnas = ancho >= 1000;

    final saludo = switch (ahora.hour) {
      < 12 => 'Buenos días',
      < 19 => 'Buenas tardes',
      _ => 'Buenas noches',
    };
    final nombre = medico.nombre.trim();
    final fecha = diaLargo(ahora);

    final despues = _Despues(citas: abiertas.skip(1).toList());
    final lateral = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Pendientes(),
        const SizedBox(height: 24),
        _DiaEnNumeros(citas: hoy),
      ],
    );

    // Un Scaffold propio, como las demás pantallas: los avisos (SnackBar)
    // también se ven aquí.
    return Scaffold(
      backgroundColor: ColoresMarca.fondo,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          movil ? 16 : 36,
          movil ? 16 : 28,
          movil ? 16 : 36,
          40,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${fecha[0].toUpperCase()}${fecha.substring(1)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ColoresMarca.textoSuave,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    header: true,
                    child: Text(
                      nombre.isEmpty ? saludo : '$saludo, $nombre',
                      style: TextStyle(
                        fontSize: movil ? 24 : 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.15,
                        color: ColoresMarca.tinta,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (abiertas.isEmpty)
                    _SinMasCitas(habiaCitas: hoy.isNotEmpty)
                  else
                    _SiguientePaciente(cita: abiertas.first),
                  const SizedBox(height: 28),
                  if (dosColumnas)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: despues),
                        const SizedBox(width: 28),
                        Expanded(flex: 2, child: lateral),
                      ],
                    )
                  else ...[
                    despues,
                    const SizedBox(height: 24),
                    lateral,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta blanca con la sombra cálida de la marca.
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child, this.relleno});

  final Widget child;
  final EdgeInsets? relleno;

  @override
  Widget build(BuildContext context) => Container(
    padding: relleno ?? const EdgeInsets.fromLTRB(20, 6, 20, 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: RadiosMarca.tarjeta,
      border: Border.all(color: ColoresMarca.separador),
      boxShadow: sombraTarjeta,
    ),
    child: child,
  );
}

class _TituloBloque extends StatelessWidget {
  const _TituloBloque(this.texto, {this.accion});

  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: ColoresMarca.tinta,
              ),
            ),
          ),
        ),
        ?accion,
      ],
    ),
  );
}

/// «en 12 minutos», «ahora», «en 2 h».
String _cuando(Cita c, DateTime ahora) {
  if (!c.inicio.isAfter(ahora)) return 'ahora';
  final m = c.inicio.difference(ahora).inMinutes;
  if (m < 1) return 'ahora';
  if (m < 60) return m == 1 ? 'en 1 minuto' : 'en $m minutos';
  final h = (m / 60).round();
  return h == 1 ? 'en 1 hora' : 'en $h horas';
}

String _hora(DateTime f) => horaTexto(f.hour * 60 + f.minute);

class _SiguientePaciente extends ConsumerWidget {
  const _SiguientePaciente({required this.cita});

  final Cita cita;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.read(servicioConsultorioProvider);
    final ahora = s.reloj.ahora();
    final ficha = s.agenda.fichaDe(cita);
    final ancho = MediaQuery.sizeOf(context).width;
    final conDibujo = ancho >= 900;
    if (ficha == null) return const SizedBox.shrink();
    final edad = ficha.edadAnios(ahora);
    final alergias = s.indice.alergiasDe(ficha.id);
    // En el modo presentación, como en la agenda, sin el motivo de la cita.
    final presentacion = ref.watch(modoPresentacionProvider);
    final detalle = [
      if (edad != null) '$edad años',
      cita.tipo.etiqueta,
      if (!presentacion && cita.motivo.trim().isNotEmpty) cita.motivo.trim(),
    ].join(' · ');

    final datos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Chip(
          texto:
              'Tu siguiente paciente · ${_hora(cita.inicio)}, '
              '${_cuando(cita, ahora)}',
          fondo: ColoresMarca.tinte,
          color: ColoresMarca.tinteTexto,
          punto: ColoresMarca.marca,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: ColoresMarca.neutroFondo,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  inicialesFicha(ficha),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: ColoresMarca.tinta,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ficha.nombreCompleto,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.2,
                      color: ColoresMarca.tinta,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    style: const TextStyle(
                      fontSize: 15.5,
                      color: ColoresMarca.tintaSuave,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (alergias != null && alergias.alergias.isNotEmpty)
              _Chip(
                texto: 'Alergia: ${alergias.alergias.join(', ')}',
                fondo: ColoresMarca.errorFondo,
                color: ColoresMarca.error,
                icono: Icons.warning_amber_rounded,
              )
            else if (alergias != null && alergias.niega)
              const _Chip(
                texto: 'Niega alergias',
                fondo: ColoresMarca.neutroFondo,
                color: ColoresMarca.tintaSuave,
              ),
            _Chip(
              texto: cita.estado.etiqueta,
              fondo: cita.estado == EstadoCita.confirmada
                  ? ColoresMarca.estadoOkFondo
                  : ColoresMarca.neutroFondo,
              color: cita.estado == EstadoCita.confirmada
                  ? ColoresMarca.estadoOk
                  : ColoresMarca.tintaSuave,
              icono: cita.estado == EstadoCita.confirmada
                  ? Icons.check_rounded
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => atenderCita(context, ref, cita),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 50),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text(
                'Empezar consulta',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            OutlinedButton(
              onPressed: () => context.go('/pacientes/${ficha.id}'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
              child: const Text('Ver ficha'),
            ),
          ],
        ),
      ],
    );
    return _Tarjeta(
      relleno: EdgeInsets.all(ancho < 700 ? 18 : 30),
      child: Row(
        children: [
          Expanded(child: datos),
          if (conDibujo) ...[
            const SizedBox(width: 24),
            const IlustracionMarca(Ilustracion.consulta, alto: 190),
          ],
        ],
      ),
    );
  }
}

class _SinMasCitas extends ConsumerWidget {
  const _SinMasCitas({required this.habiaCitas});

  final bool habiaCitas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Tarjeta(
      relleno: const EdgeInsets.all(28),
      child: Center(
        child: EstadoVacio(
          ilustracion: Ilustracion.agendaLibre,
          titulo: habiaCitas
              ? 'Ya no quedan citas por atender hoy'
              : 'No tienes citas hoy',
          texto: 'La historia clínica y la receta funcionan igual sin cita.',
          acciones: [
            FilledButton.icon(
              onPressed: () async {
                final ahora = ref
                    .read(servicioConsultorioProvider)
                    .reloj
                    .ahora();
                final c = await editarCita(context, dia: ahora);
                if (c != null) {
                  ref.read(versionIndiceProvider.notifier).cambio();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Nueva cita'),
            ),
            OutlinedButton(
              onPressed: () => context.go('/agenda'),
              child: const Text('Ver la agenda'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Despues extends ConsumerWidget {
  const _Despues({required this.citas});

  final List<Cita> citas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.read(servicioConsultorioProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TituloBloque(
          'Después',
          accion: TextButton(
            onPressed: () => context.go('/agenda'),
            child: const Text('Ver la agenda'),
          ),
        ),
        _Tarjeta(
          child: citas.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No hay más citas hoy.',
                    style: TextStyle(color: ColoresMarca.textoSuave),
                  ),
                )
              : Column(
                  children: [
                    for (final (i, c) in citas.indexed)
                      _FilaCita(
                        cita: c,
                        nombre: s.agenda.fichaDe(c)?.nombreCompleto ?? '—',
                        primera: i == 0,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _FilaCita extends StatelessWidget {
  const _FilaCita({
    required this.cita,
    required this.nombre,
    required this.primera,
  });

  final Cita cita;
  final String nombre;
  final bool primera;

  @override
  Widget build(BuildContext context) {
    final estrecho = MediaQuery.sizeOf(context).width < 560;
    return InkWell(
      onTap: () => context.go('/pacientes/${cita.pacienteId}'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: primera
              ? null
              : const Border(top: BorderSide(color: ColoresMarca.separador)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(
                _hora(cita.inicio),
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
              child: estrecho
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          cita.tipo.etiqueta,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: ColoresMarca.textoSuave,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Text(
                            nombre,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            cita.tipo.etiqueta,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ColoresMarca.textoSuave,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            Text(
              '${cita.duracionMin} min',
              style: const TextStyle(fontSize: 13.5, color: ColoresMarca.pista),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pendientes extends ConsumerWidget {
  const _Pendientes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.read(servicioConsultorioProvider);
    final vencidos = s.indice.controlesVencidos;
    final recordatorios = s.agenda.pendientesRecordatorio().length;
    final inv = s.inventario.alertas();
    String n(int x, String uno, String varios) => '$x ${x == 1 ? uno : varios}';
    final filas = <Widget>[
      if (vencidos > 0)
        _FilaPendiente(
          color: ColoresMarca.error,
          titulo: n(vencidos, 'control vencido', 'controles vencidos'),
          texto: 'Recordarles por WhatsApp, sin datos de salud',
          alPulsar: () => context.go('/pacientes?vencidos=1'),
        ),
      if (inv.vencidos.isNotEmpty)
        _FilaPendiente(
          color: ColoresMarca.error,
          titulo: n(inv.vencidos.length, 'lote vencido', 'lotes vencidos'),
          texto: 'Retíralo del uso y dalo de baja',
          alPulsar: () => context.go('/inventario'),
        ),
      if (recordatorios > 0)
        _FilaPendiente(
          color: ColoresMarca.aviso,
          titulo: n(
            recordatorios,
            'cita de mañana sin recordatorio',
            'citas de mañana sin recordatorio',
          ),
          texto: 'Envíalo desde la agenda',
          alPulsar: () => context.go('/agenda'),
        ),
      if (inv.bajoMinimo.isNotEmpty)
        _FilaPendiente(
          color: ColoresMarca.aviso,
          titulo: n(
            inv.bajoMinimo.length,
            'insumo bajo el mínimo',
            'insumos bajo el mínimo',
          ),
          texto: inv.bajoMinimo.map((i) => i.nombre).take(3).join(', '),
          alPulsar: () => context.go('/inventario'),
        ),
      if (inv.porVencer.isNotEmpty)
        _FilaPendiente(
          color: ColoresMarca.aviso,
          titulo: n(
            inv.porVencer.length,
            'lote por vencer',
            'lotes por vencer',
          ),
          texto: 'Úsalos primero',
          alPulsar: () => context.go('/inventario'),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TituloBloque('Pendientes'),
        _Tarjeta(
          child: filas.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: EstadoVacio(
                    ilustracion: Ilustracion.listo,
                    titulo: 'Todo al día',
                    alto: 72,
                  ),
                )
              : Column(
                  children: [
                    for (final (i, f) in filas.indexed) ...[
                      if (i > 0)
                        const Divider(height: 1, color: ColoresMarca.separador),
                      f,
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _FilaPendiente extends StatelessWidget {
  const _FilaPendiente({
    required this.color,
    required this.titulo,
    required this.texto,
    required this.alPulsar,
  });

  final Color color;
  final String titulo;
  final String texto;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: alPulsar,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (texto.isNotEmpty)
                  Text(
                    texto,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: ColoresMarca.textoSuave,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: ColoresMarca.pista),
        ],
      ),
    ),
  );
}

class _DiaEnNumeros extends ConsumerWidget {
  const _DiaEnNumeros({required this.citas});

  final List<Cita> citas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.read(servicioConsultorioProvider);
    final presentacion = ref.watch(modoPresentacionProvider);
    final ahora = s.reloj.ahora();
    final atendidas = citas
        .where((c) => c.estado == EstadoCita.atendida)
        .length;
    final caja = s.caja.totales(ahora).values.fold(0, (a, b) => a + b);
    final porCobrar = s.caja.cobrosConSaldo().fold(
      0,
      (a, c) => a + s.caja.saldo(c),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TituloBloque('Tu día en números'),
        _Tarjeta(
          child: Column(
            children: [
              _FilaNumero(
                etiqueta: 'Citas',
                valor: '${citas.length}',
                detalle: atendidas == 1 ? '1 atendida' : '$atendidas atendidas',
                alPulsar: () => context.go('/agenda'),
                primera: true,
              ),
              // En modo presentación no se muestran montos de la caja.
              if (!presentacion) ...[
                _FilaNumero(
                  etiqueta: 'Caja de hoy',
                  valor: formatoPesos(caja),
                  alPulsar: () => context.go('/caja'),
                ),
                _FilaNumero(
                  etiqueta: 'Por cobrar',
                  valor: formatoPesos(porCobrar),
                  alPulsar: () => context.go('/caja'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilaNumero extends StatelessWidget {
  const _FilaNumero({
    required this.etiqueta,
    required this.valor,
    required this.alPulsar,
    this.detalle,
    this.primera = false,
  });

  final String etiqueta;
  final String valor;
  final String? detalle;
  final VoidCallback alPulsar;
  final bool primera;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: alPulsar,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: primera
            ? null
            : const Border(top: BorderSide(color: ColoresMarca.separador)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: const TextStyle(color: ColoresMarca.tintaSuave),
            ),
          ),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (detalle != null) ...[
            const SizedBox(width: 6),
            Text(
              '· $detalle',
              style: const TextStyle(fontSize: 13.5, color: ColoresMarca.pista),
            ),
          ],
        ],
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.texto,
    required this.fondo,
    required this.color,
    this.icono,
    this.punto,
  });

  final String texto;
  final Color fondo;
  final Color color;
  final IconData? icono;
  final Color? punto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: fondo, borderRadius: RadiosMarca.pildora),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (punto != null) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: punto, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
        ],
        if (icono != null) ...[
          Icon(icono, size: 15, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}
