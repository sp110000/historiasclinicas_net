import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/modelos/ficha_paciente.dart';
import '../../../core/pais/pais_provider.dart';
import '../../../core/pais/perfil_pais.dart';
import '../../../core/widgets/campos.dart';
import '../../../core/widgets/titulo_dialogo.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';

/// Crea una ficha a mano ([ficha] `null`) o edita sus datos
/// administrativos. Devuelve la ficha guardada, o `null` si se cancela.
/// Nunca toca lo sellado en las historias.
Future<FichaPaciente?> editarFicha(
  BuildContext context, {
  FichaPaciente? ficha,
}) => showDialog<FichaPaciente>(
  context: context,
  builder: (_) => _DialogoFicha(ficha: ficha),
);

class _DialogoFicha extends ConsumerStatefulWidget {
  const _DialogoFicha({this.ficha});

  final FichaPaciente? ficha;

  @override
  ConsumerState<_DialogoFicha> createState() => _DialogoFichaState();
}

class _DialogoFichaState extends ConsumerState<_DialogoFicha> {
  late FichaPaciente _f;
  String? _error;
  var _guardando = false;

  bool get _nueva => widget.ficha == null;

  @override
  void initState() {
    super.initState();
    final ahora = ref.read(servicioConsultorioProvider).reloj.ahora();
    _f =
        widget.ficha ??
        FichaPaciente(
          id: '',
          clave: '',
          creado: ahora,
          actualizado: ahora,
          tipoDocumento: ref
              .read(paisProvider)
              .perfil
              .tiposDocumento
              .first
              .codigo,
        );
  }

  void _cambiar(FichaPaciente Function(FichaPaciente f) cambio) =>
      setState(() => _f = cambio(_f));

  Future<void> _guardar() async {
    if (_f.primerApellido.trim().isEmpty && _f.nombres.trim().isEmpty) {
      setState(() => _error = 'Escribe al menos el nombre o un apellido.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    final indice = ref.read(servicioConsultorioProvider).indice;
    try {
      final limpia = _f.copyWith(
        numeroDocumento: _f.numeroDocumento.trim(),
        primerApellido: _f.primerApellido.trim(),
        segundoApellido: _f.segundoApellido.trim(),
        nombres: _f.nombres.trim(),
      );
      final FichaPaciente guardada;
      if (_nueva) {
        guardada = await indice.crearFicha(limpia);
      } else {
        await indice.guardarFicha(limpia);
        guardada = indice.ficha(limpia.id)!;
      }
      ref.read(versionIndiceProvider.notifier).cambio();
      if (mounted) Navigator.pop(context, guardada);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = mensajeDeError(e);
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _f;
    final tipos = ref.watch(paisProvider).perfil.tiposDocumento;
    final sugeridas = ref
        .read(servicioConsultorioProvider)
        .indice
        .etiquetasUsadas
        .where((e) => !f.etiquetas.contains(e))
        .toList();
    final movil = MediaQuery.sizeOf(context).width < 600;
    return AlertDialog(
      title: TituloDialogo(
        _nueva ? 'Paciente nuevo' : 'Datos del paciente',
        icono: Icons.person_outline,
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: movil ? 12 : 40,
        vertical: 24,
      ),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_nueva)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Estos datos son de la ficha. Lo sellado en las historias '
                    'no cambia.',
                    style: TextStyle(color: ColoresMarca.textoSuave),
                  ),
                ),
              FilaCampos(
                anchoMinimo: 420,
                children: [
                  CampoDesplegable(
                    etiqueta: 'Tipo de documento',
                    opciones: tipos,
                    valor: f.tipoDocumento,
                    mostrarCodigo: true,
                    alCambiar: (v) =>
                        _cambiar((f) => f.copyWith(tipoDocumento: v)),
                  ),
                  CampoTexto(
                    etiqueta: 'Número de documento',
                    valorInicial: f.numeroDocumento,
                    alCambiar: (v) =>
                        _cambiar((f) => f.copyWith(numeroDocumento: v)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilaCampos(
                anchoMinimo: 420,
                children: [
                  CampoTexto(
                    etiqueta: 'Primer apellido',
                    valorInicial: f.primerApellido,
                    mayusculas: TextCapitalization.words,
                    alCambiar: (v) =>
                        _cambiar((f) => f.copyWith(primerApellido: v)),
                  ),
                  CampoTexto(
                    etiqueta: 'Segundo apellido',
                    valorInicial: f.segundoApellido,
                    mayusculas: TextCapitalization.words,
                    alCambiar: (v) =>
                        _cambiar((f) => f.copyWith(segundoApellido: v)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              CampoTexto(
                etiqueta: 'Nombres',
                valorInicial: f.nombres,
                mayusculas: TextCapitalization.words,
                alCambiar: (v) => _cambiar((f) => f.copyWith(nombres: v)),
              ),
              const SizedBox(height: 14),
              FilaCampos(
                anchoMinimo: 420,
                children: [
                  CampoFecha(
                    etiqueta: 'Fecha de nacimiento',
                    valor: f.fechaNacimiento,
                    primera: DateTime(1900),
                    ultima: DateTime.now(),
                    alCambiar: (v) =>
                        _cambiar((f) => f.copyWith(fechaNacimiento: v)),
                  ),
                  CampoDesplegable(
                    etiqueta: 'Sexo',
                    opciones: opcionesSexo,
                    valor: f.sexo,
                    alCambiar: (v) => _cambiar((f) => f.copyWith(sexo: v)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilaCampos(
                anchoMinimo: 420,
                children: [
                  CampoTexto(
                    etiqueta: 'Teléfono',
                    valorInicial: f.telefono,
                    teclado: TextInputType.phone,
                    alCambiar: (v) => _cambiar((f) => f.copyWith(telefono: v)),
                  ),
                  CampoTexto(
                    etiqueta: 'Correo',
                    valorInicial: f.correo,
                    teclado: TextInputType.emailAddress,
                    mayusculas: TextCapitalization.none,
                    alCambiar: (v) => _cambiar((f) => f.copyWith(correo: v)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilaCampos(
                anchoMinimo: 420,
                children: [
                  CampoTexto(
                    etiqueta: 'Dirección',
                    valorInicial: f.direccion,
                    alCambiar: (v) => _cambiar((f) => f.copyWith(direccion: v)),
                  ),
                  CampoTexto(
                    etiqueta: 'Ciudad',
                    valorInicial: f.ciudad,
                    mayusculas: TextCapitalization.words,
                    alCambiar: (v) => _cambiar((f) => f.copyWith(ciudad: v)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilaCampos(
                anchoMinimo: 420,
                children: [
                  CampoTexto(
                    etiqueta: 'Aseguradora',
                    valorInicial: f.aseguradora,
                    alCambiar: (v) =>
                        _cambiar((f) => f.copyWith(aseguradora: v)),
                  ),
                  CampoTexto(
                    etiqueta: 'Contacto de emergencia',
                    valorInicial: f.contactoEmergencia,
                    alCambiar: (v) =>
                        _cambiar((f) => f.copyWith(contactoEmergencia: v)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text('LÍNEAS DE ATENCIÓN', style: EstilosMarca.rotulo),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final l in LineaAtencion.values)
                    FilterChip(
                      label: Text(l.etiqueta),
                      selected: f.lineas.contains(l),
                      onSelected: (si) => _cambiar(
                        (f) => f.copyWith(
                          lineas: si
                              ? {...f.lineas, l}
                              : ({...f.lineas}..remove(l)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              CampoEtiquetas(
                etiqueta: 'Etiquetas',
                pista: 'Escribe y presiona Enter',
                valores: f.etiquetas,
                alCambiar: (v) => _cambiar((f) => f.copyWith(etiquetas: v)),
              ),
              if (sugeridas.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Usadas:',
                      style: TextStyle(
                        fontSize: 13,
                        color: ColoresMarca.textoSuave,
                      ),
                    ),
                    for (final e in sugeridas.take(12))
                      ActionChip(
                        label: Text(e),
                        onPressed: () => _cambiar(
                          (f) => f.copyWith(etiquetas: [...f.etiquetas, e]),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              CampoTexto(
                etiqueta: 'Notas internas',
                ayuda: 'Solo para ti: no salen en ningún documento.',
                valorInicial: f.notas,
                lineas: 3,
                alCambiar: (v) => _cambiar((f) => f.copyWith(notas: v)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: ColoresMarca.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_nueva ? 'Crear ficha' : 'Guardar'),
        ),
      ],
    );
  }
}
