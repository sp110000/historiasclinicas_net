// Campos y botones mínimos del RDA (regla 10). Cada widget no muestra nada
// con IHCE_ENABLED=false. Usan los componentes de la app (CampoTexto,
// CampoDesplegable, FilaCampos, Aviso) sin temas ni estilos nuevos. La
// lógica vive en la capa de servicios: aquí solo se llama a los providers.
// Inventario en docs/ihce/CAMBIOS_UI.md.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema.dart';
import '../../core/ihce/perfiles/perfiles_rda.g.dart';
import '../../core/ihce/terminologia/catalogo_terminologia.dart';
import '../../core/models/antecedentes.dart';
import '../../core/pais/perfil_pais.dart';
import '../../core/widgets/campos.dart';
import '../historia/estado/historia_controller.dart';
import '../historia/secciones/edicion.dart';
import '../historia/widgets/avisos.dart';
import '../medico/medico_provider.dart';
import 'ihce_provider.dart';

const _espacio = SizedBox(height: 14);

/// Opciones de un ValueSet de la guía para un desplegable («código · nombre»).
List<Opcion> _opciones(CatalogoTerminologia? c, String valueSet) => [
  for (final (codigo, nombre)
      in c?.opciones(valueSet) ?? const <(String, String)>[])
    Opcion(codigo, nombre),
];

/// Validación de un código escrito contra el catálogo cargado.
FormFieldValidator<String> _codigoEn(
  CatalogoTerminologia? c,
  String valueSet,
  String sistema,
) => (v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty || c == null) return null;
  return c.enValueSet(valueSet, sistema, t) ? null : 'Código no encontrado';
};

String? _nombre(CatalogoTerminologia? c, String sistema, String codigo) =>
    codigo.trim().isEmpty ? null : c?.display(sistema, codigo.trim());

// ───────────────────────── Datos del médico ─────────────────────────

/// «Datos profesionales»: tipo de documento, apellidos y nombres separados y
/// profesión RETHUS (PractitionerRDA). El número de documento ya existe.
class CamposIhceProfesional extends ConsumerWidget {
  const CamposIhceProfesional({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(ihceHabilitadoProvider)) return const SizedBox.shrink();
    final m = ref.watch(medicoProvider);
    final ctrl = ref.read(medicoProvider.notifier);
    final c = ref.watch(catalogoGuiaProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _espacio,
        FilaCampos(
          children: [
            CampoDesplegable(
              etiqueta: 'Tipo de documento',
              opciones: perfilColombia.tiposDocumento,
              valor: m.tipoDocumento.isEmpty ? null : m.tipoDocumento,
              mostrarCodigo: true,
              alCambiar: (v) =>
                  ctrl.actualizar((m) => m.copyWith(tipoDocumento: v)),
            ),
            CampoTexto(
              etiqueta: 'Primer apellido',
              valorInicial: m.primerApellido,
              mayusculas: TextCapitalization.words,
              alCambiar: (v) =>
                  ctrl.actualizar((m) => m.copyWith(primerApellido: v)),
            ),
          ],
        ),
        _espacio,
        FilaCampos(
          children: [
            CampoTexto(
              etiqueta: 'Segundo apellido',
              valorInicial: m.segundoApellido,
              mayusculas: TextCapitalization.words,
              alCambiar: (v) =>
                  ctrl.actualizar((m) => m.copyWith(segundoApellido: v)),
            ),
            CampoTexto(
              etiqueta: 'Nombres',
              valorInicial: m.nombres,
              mayusculas: TextCapitalization.words,
              alCambiar: (v) => ctrl.actualizar((m) => m.copyWith(nombres: v)),
            ),
          ],
        ),
        _espacio,
        CampoTexto(
          etiqueta: 'Profesión (código RETHUS)',
          valorInicial: m.codigoRethus,
          ayuda: _nombre(c, SistemaRda.rethuSqualification, m.codigoRethus),
          validador: _codigoEn(
            c,
            ConjuntoRda.rethuSqualificationCodes,
            SistemaRda.rethuSqualification,
          ),
          alCambiar: (v) =>
              ctrl.actualizar((m) => m.copyWith(codigoRethus: v.trim())),
        ),
      ],
    );
  }
}

/// «Consultorio»: configuración del prestador para el RDA y credenciales.
class CamposIhcePrestador extends ConsumerWidget {
  const CamposIhcePrestador({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(ihceHabilitadoProvider)) return const SizedBox.shrink();
    final p = ref.watch(prestadorIhceProvider);
    final ctrl = ref.read(prestadorIhceProvider.notifier);
    final c = ref.watch(catalogoGuiaProvider).value;
    final validarCups = _codigoEn(
      c,
      ConjuntoRda.cupsConsultationCodes,
      SistemaRda.cups,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _espacio,
        CampoTexto(
          etiqueta: 'Código de habilitación (REPS)',
          valorInicial: p.codigoHabilitacion,
          teclado: TextInputType.number,
          alCambiar: (v) =>
              ctrl.actualizar((p) => p.copyWith(codigoHabilitacion: v.trim())),
        ),
        _espacio,
        FilaCampos(
          children: [
            CampoDesplegable(
              etiqueta: 'Modalidad de la atención',
              opciones: _opciones(c, ConjuntoRda.colombianTechModalityCodes),
              valor: p.modalidad.isEmpty ? null : p.modalidad,
              mostrarCodigo: true,
              alCambiar: (v) =>
                  ctrl.actualizar((p) => p.copyWith(modalidad: v)),
            ),
            CampoDesplegable(
              etiqueta: 'Entorno de la atención',
              opciones: _opciones(c, ConjuntoRda.entornoAtencionCodigos),
              valor: p.entorno.isEmpty ? null : p.entorno,
              mostrarCodigo: true,
              alCambiar: (v) => ctrl.actualizar((p) => p.copyWith(entorno: v)),
            ),
          ],
        ),
        _espacio,
        FilaCampos(
          children: [
            CampoTexto(
              etiqueta: 'CUPS consulta de primera vez',
              valorInicial: p.cupsPrimeraVez,
              teclado: TextInputType.number,
              ayuda: _nombre(c, SistemaRda.cups, p.cupsPrimeraVez),
              validador: validarCups,
              alCambiar: (v) =>
                  ctrl.actualizar((p) => p.copyWith(cupsPrimeraVez: v.trim())),
            ),
            CampoTexto(
              etiqueta: 'CUPS consulta de control',
              valorInicial: p.cupsControl,
              teclado: TextInputType.number,
              ayuda: _nombre(c, SistemaRda.cups, p.cupsControl),
              validador: validarCups,
              alCambiar: (v) =>
                  ctrl.actualizar((p) => p.copyWith(cupsControl: v.trim())),
            ),
            CampoTexto(
              etiqueta: 'CUPS interconsulta',
              valorInicial: p.cupsInterconsulta,
              teclado: TextInputType.number,
              ayuda: _nombre(c, SistemaRda.cups, p.cupsInterconsulta),
              validador: validarCups,
              alCambiar: (v) => ctrl.actualizar(
                (p) => p.copyWith(cupsInterconsulta: v.trim()),
              ),
            ),
          ],
        ),
        _espacio,
        const CredencialesMinSalud(),
      ],
    );
  }
}

/// «ClientID de MinSalud» y «ClientSecret de MinSalud»: van al
/// AlmacenSecretos (flutter_secure_storage) y a nada más. El secreto se
/// escribe oculto y nunca se vuelve a mostrar.
class CredencialesMinSalud extends ConsumerStatefulWidget {
  const CredencialesMinSalud({super.key});

  @override
  ConsumerState<CredencialesMinSalud> createState() =>
      _CredencialesMinSaludState();
}

class _CredencialesMinSaludState extends ConsumerState<CredencialesMinSalud> {
  // Solo en memoria mientras se escribe; se borran al guardar.
  final _clientId = TextEditingController();
  final _secreto = TextEditingController();
  final _clave = TextEditingController();
  var _guardando = false;

  @override
  void dispose() {
    _clientId.dispose();
    _secreto.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await ref
          .read(credencialesIhceProvider)
          .guardar(
            clientId: _clientId.text.trim().isEmpty ? null : _clientId.text,
            clientSecret: _secreto.text.trim().isEmpty ? null : _secreto.text,
            subscriptionKey: _clave.text.trim().isEmpty ? null : _clave.text,
          );
      _clientId.clear();
      _secreto.clear();
      _clave.clear();
      ref.invalidate(credencialesGuardadasProvider);
      unawaited(ref.read(servicioIhceProvider)?.procesarPendientes());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(ihceHabilitadoProvider)) return const SizedBox.shrink();
    final guardadas = ref.watch(credencialesGuardadasProvider).value ?? false;
    ref.watch(cambiosIhceProvider);
    final errorAuth = ref.watch(servicioIhceProvider)?.hayErrorAuth ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilaCampos(
          children: [
            CampoTexto(
              etiqueta: 'ClientID de MinSalud',
              controller: _clientId,
              mayusculas: TextCapitalization.none,
              ayuda: guardadas
                  ? 'Guardado; escribe uno nuevo para reemplazarlo'
                  : null,
              alCambiar: (_) {},
            ),
            CampoTexto(
              etiqueta: 'ClientSecret de MinSalud',
              controller: _secreto,
              oculto: true,
              mayusculas: TextCapitalization.none,
              ayuda: guardadas ? 'Configurado' : null,
              alCambiar: (_) {},
            ),
            // La colección Postman v1.5 envía `Ocp-Apim-Subscription-Key`
            // en todas las peticiones al API (CAMBIOS_UI.md).
            CampoTexto(
              etiqueta: 'Clave de suscripción de MinSalud',
              controller: _clave,
              oculto: true,
              mayusculas: TextCapitalization.none,
              alCambiar: (_) {},
            ),
          ],
        ),
        if (errorAuth) ...[
          const SizedBox(height: 6),
          const Text(
            'MinSalud rechazó las credenciales: revisa el ClientID y el ClientSecret.',
            style: TextStyle(color: ColoresMarca.error),
          ),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: const Text('Guardar credenciales'),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Historia ─────────────────────────

/// Datos del paciente que exige `PatientRDA`: nacionalidad, país de
/// residencia, pertenencia étnica, discapacidad y zona de residencia.
class CamposIhcePaciente extends ConsumerWidget {
  const CamposIhcePaciente({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(ihceHabilitadoProvider)) return const SizedBox.shrink();
    final p = ref.watch(historiaProvider.select((e) => e.historia.paciente));
    final c = ref.watch(catalogoGuiaProvider).value;
    final validarPais = _codigoEn(
      c,
      ConjuntoRda.iso31661N,
      SistemaRda.iso31661,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        FilaCampos(
          children: [
            CampoTexto(
              etiqueta: 'Nacionalidad (código país)',
              valorInicial: p.nacionalidad,
              teclado: TextInputType.number,
              ayuda: _nombre(c, SistemaRda.iso31661, p.nacionalidad),
              validador: validarPais,
              alCambiar: (v) =>
                  ref.editarPaciente((p) => p.copyWith(nacionalidad: v.trim())),
            ),
            CampoTexto(
              etiqueta: 'País de residencia (código)',
              valorInicial: p.paisResidencia,
              teclado: TextInputType.number,
              ayuda: _nombre(c, SistemaRda.iso31661, p.paisResidencia),
              validador: validarPais,
              alCambiar: (v) => ref.editarPaciente(
                (p) => p.copyWith(paisResidencia: v.trim()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilaCampos(
          children: [
            CampoDesplegable(
              etiqueta: 'Pertenencia étnica',
              opciones: _opciones(c, ConjuntoRda.colombianEthnicGroupCodes),
              valor: p.etnia.isEmpty ? null : p.etnia,
              mostrarCodigo: true,
              alCambiar: (v) => ref.editarPaciente((p) => p.copyWith(etnia: v)),
            ),
            CampoDesplegable(
              etiqueta: 'Discapacidad',
              opciones: _opciones(
                c,
                ConjuntoRda.colombianDisabilityClassificationCodes,
              ),
              valor: p.discapacidad.isEmpty ? null : p.discapacidad,
              mostrarCodigo: true,
              alCambiar: (v) =>
                  ref.editarPaciente((p) => p.copyWith(discapacidad: v)),
            ),
            CampoDesplegable(
              etiqueta: 'Zona de residencia',
              opciones: _opciones(c, ConjuntoRda.colombianResidenceZoneCodes),
              valor: p.zonaResidencia.isEmpty ? null : p.zonaResidencia,
              mostrarCodigo: true,
              alCambiar: (v) =>
                  ref.editarPaciente((p) => p.copyWith(zonaResidencia: v)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Causa externa de la atención (`Encounter.reasonCode`, 1..1).
class CampoCausaExterna extends ConsumerWidget {
  const CampoCausaExterna({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(ihceHabilitadoProvider)) return const SizedBox.shrink();
    final causa = ref.watch(
      historiaProvider.select((e) => e.historia.causaExterna),
    );
    final c = ref.watch(catalogoGuiaProvider).value;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: CampoDesplegable(
        etiqueta: 'Causa externa',
        opciones: _opciones(c, ConjuntoRda.ripsCausaExternaVersion2Codigos),
        valor: causa,
        mostrarCodigo: true,
        alCambiar: (v) => ref.editar((h) => h.copyWith(causaExterna: v)),
      ),
    );
  }
}

/// Tipo de cada alergia registrada (`AllergyIntoleranceRDA`): sin él, el
/// perfil solo admite «nada conocido» para la sección, que sería falso.
class TiposAlergiaIhce extends ConsumerWidget {
  const TiposAlergiaIhce({super.key, required this.antecedentes});

  final Antecedentes antecedentes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = antecedentes;
    if (!ref.watch(ihceHabilitadoProvider) ||
        a.niegaAlergias ||
        a.alergias.isEmpty) {
      return const SizedBox.shrink();
    }
    final c = ref.watch(catalogoGuiaProvider).value;
    final opciones = _opciones(c, ConjuntoRda.tipoAlergiaCodigos);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final alergia in a.alergias)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: CampoDesplegable(
              etiqueta: 'Tipo: $alergia',
              opciones: opciones,
              valor: a.tiposAlergia[alergia],
              alCambiar: (v) => ref.editarAntecedentes(
                (a) => a.copyWith(
                  tiposAlergia: {
                    for (final x in a.alergias)
                      if (x == alergia)
                        x: v
                      else if (a.tiposAlergia[x] != null)
                        x: a.tiposAlergia[x]!,
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Una línea con el motivo en lenguaje llano y «Reintentar», solo si el RDA
/// de la atención quedó en un rechazo que el médico puede corregir.
/// Aceptado, en curso o en cola: nada a la vista.
class AvisoRdaAtencion extends ConsumerWidget {
  const AvisoRdaAtencion({super.key, required this.atencionId});

  final String atencionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(ihceHabilitadoProvider)) return const SizedBox.shrink();
    final e = ref.watch(estadoRdaProvider(atencionId));
    if (e == null || !e.corregible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Aviso(
        icono: Icons.warning_amber_rounded,
        color: ColoresMarca.aviso,
        titulo: 'El resumen (RDA) no se envió a MinSalud',
        texto: Text(e.motivo ?? 'Revisa los datos de la atención.'),
        acciones: [
          TextButton(
            onPressed: () => ref
                .read(servicioIhceProvider)
                ?.reintentar(
                  e.documentoId,
                  medico: ref.read(medicoProvider),
                  prestador: ref.read(prestadorIhceProvider),
                ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
