import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/pais/perfil_pais.dart';
import '../../../core/widgets/campos.dart';
import '../estado/historia_controller.dart';
import 'edicion.dart';

class FormularioPaciente extends ConsumerStatefulWidget {
  const FormularioPaciente({super.key});

  @override
  ConsumerState<FormularioPaciente> createState() => _FormularioPacienteState();
}

class _FormularioPacienteState extends ConsumerState<FormularioPaciente> {
  late bool _fechaDesconocida;

  @override
  void initState() {
    super.initState();
    final p = ref.read(historiaProvider).historia.paciente;
    _fechaDesconocida = p.fechaNacimiento == null && p.edadAproximada != null;
  }

  @override
  Widget build(BuildContext context) {
    final h = ref.watch(historiaProvider.select((e) => e.historia));
    final p = h.paciente;
    final perfil = h.perfil;
    final hoy = DateTime.now();
    final atencion = h.fechaAtencion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilaCampos(
          flex: const [3, 2, 5],
          children: [
            CampoFecha(
              etiqueta: 'Fecha de la atención',
              valor: atencion,
              requerido: true,
              ultima: DateTime(hoy.year, hoy.month, hoy.day + 1),
              alCambiar: (f) {
                if (f == null) return;
                ref.editar(
                  (h) => h.copyWith(
                    fechaAtencion: DateTime(
                      f.year,
                      f.month,
                      f.day,
                      h.fechaAtencion.hour,
                      h.fechaAtencion.minute,
                    ),
                  ),
                );
              },
            ),
            CampoHora(
              etiqueta: 'Hora',
              hora: atencion.hour,
              minuto: atencion.minute,
              alCambiar: (hh, mm) => ref.editar(
                (h) => h.copyWith(
                  fechaAtencion: DateTime(
                    h.fechaAtencion.year,
                    h.fechaAtencion.month,
                    h.fechaAtencion.day,
                    hh,
                    mm,
                  ),
                ),
              ),
            ),
            SelectorOpciones(
              etiqueta: 'Tipo de consulta',
              opciones: opcionesTipoConsulta,
              valor: h.tipoConsulta,
              permitirNinguna: true,
              alCambiar: (v) => ref.editar((h) => h.copyWith(tipoConsulta: v)),
            ),
          ],
        ),
        const _Separador('Identificación'),
        FilaCampos(
          flex: const [4, 4, 5],
          children: [
            CampoTexto(
              etiqueta: 'Primer apellido',
              requerido: true,
              valorInicial: p.primerApellido,
              mayusculas: TextCapitalization.words,
              alCambiar: (v) =>
                  ref.editarPaciente((p) => p.copyWith(primerApellido: v)),
            ),
            CampoTexto(
              etiqueta: 'Segundo apellido',
              valorInicial: p.segundoApellido,
              mayusculas: TextCapitalization.words,
              alCambiar: (v) =>
                  ref.editarPaciente((p) => p.copyWith(segundoApellido: v)),
            ),
            CampoTexto(
              etiqueta: 'Nombres',
              requerido: true,
              valorInicial: p.nombres,
              mayusculas: TextCapitalization.words,
              alCambiar: (v) =>
                  ref.editarPaciente((p) => p.copyWith(nombres: v)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilaCampos(
          flex: const [5, 4],
          children: [
            CampoDesplegable(
              etiqueta: 'Tipo de documento',
              requerido: true,
              mostrarCodigo: true,
              opciones: perfil.tiposDocumento,
              valor: p.tipoDocumento,
              alCambiar: (v) =>
                  ref.editarPaciente((p) => p.copyWith(tipoDocumento: v)),
            ),
            CampoTexto(
              etiqueta: 'Número de documento',
              requerido: true,
              valorInicial: p.numeroDocumento,
              mayusculas: TextCapitalization.characters,
              alCambiar: (v) =>
                  ref.editarPaciente((p) => p.copyWith(numeroDocumento: v)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilaCampos(
          flex: const [5, 4],
          children: [
            if (_fechaDesconocida)
              CampoEntero(
                etiqueta: 'Edad aproximada',
                requerido: true,
                sufijo: 'años',
                valor: p.edadAproximada,
                alCambiar: (v) =>
                    ref.editarPaciente((p) => p.copyWith(edadAproximada: v)),
              )
            else
              CampoFecha(
                etiqueta: 'Fecha de nacimiento',
                requerido: true,
                valor: p.fechaNacimiento,
                ultima: hoy,
                alCambiar: (f) =>
                    ref.editarPaciente((p) => p.copyWith(fechaNacimiento: f)),
              ),
            ValorCalculado(
              etiqueta: 'Edad a la fecha de la atención',
              valor: h.edadTexto,
              destacado: true,
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() => _fechaDesconocida = !_fechaDesconocida);
              ref.editarPaciente(
                (p) => _fechaDesconocida
                    ? p.copyWith(fechaNacimiento: null)
                    : p.copyWith(edadAproximada: null),
              );
            },
            icon: Icon(
              _fechaDesconocida ? Icons.event_outlined : Icons.help_outline,
              size: 18,
            ),
            label: Text(
              _fechaDesconocida
                  ? 'Escribir la fecha de nacimiento'
                  : 'No se conoce la fecha de nacimiento',
            ),
          ),
        ),
        const SizedBox(height: 4),
        SelectorOpciones(
          etiqueta: 'Sexo',
          requerido: true,
          opciones: opcionesSexo,
          valor: p.sexo,
          alCambiar: (v) => ref.editarPaciente((p) => p.copyWith(sexo: v)),
        ),
        const _Separador('Contacto'),
        FilaCampos(
          flex: const [3, 5, 3],
          children: [
            CampoTexto(
              etiqueta: 'Teléfono',
              valorInicial: p.telefono,
              teclado: TextInputType.phone,
              alCambiar: (v) =>
                  ref.editarPaciente((p) => p.copyWith(telefono: v)),
            ),
            CampoTexto(
              etiqueta: 'Dirección',
              valorInicial: p.direccion,
              alCambiar: (v) =>
                  ref.editarPaciente((p) => p.copyWith(direccion: v)),
            ),
            CampoTexto(
              etiqueta: perfil.etiquetaCiudad,
              valorInicial: p.ciudad,
              mayusculas: TextCapitalization.words,
              alCambiar: (v) =>
                  ref.editarPaciente((p) => p.copyWith(ciudad: v)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: p.tieneComplementarios,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 4, bottom: 4),
            title: const Text(
              'Datos complementarios',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
            ),
            subtitle: const Text(
              'Estado civil, ocupación, aseguradora y acompañante (VERIFICAR '
              'cuáles exige la norma)',
              style: TextStyle(fontSize: 12.5, color: ColoresMarca.textoSuave),
            ),
            children: [
              FilaCampos(
                children: [
                  CampoTexto(
                    etiqueta: 'Estado civil',
                    valorInicial: p.estadoCivil,
                    alCambiar: (v) =>
                        ref.editarPaciente((p) => p.copyWith(estadoCivil: v)),
                  ),
                  CampoTexto(
                    etiqueta: 'Ocupación',
                    valorInicial: p.ocupacion,
                    alCambiar: (v) =>
                        ref.editarPaciente((p) => p.copyWith(ocupacion: v)),
                  ),
                  CampoTexto(
                    etiqueta: perfil.etiquetaAseguradora,
                    valorInicial: p.aseguradora,
                    alCambiar: (v) =>
                        ref.editarPaciente((p) => p.copyWith(aseguradora: v)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilaCampos(
                flex: const [5, 3, 3],
                children: [
                  CampoTexto(
                    etiqueta: 'Acompañante o responsable',
                    valorInicial: p.acompananteNombre,
                    mayusculas: TextCapitalization.words,
                    alCambiar: (v) => ref.editarPaciente(
                      (p) => p.copyWith(acompananteNombre: v),
                    ),
                  ),
                  CampoTexto(
                    etiqueta: 'Parentesco',
                    valorInicial: p.acompananteParentesco,
                    alCambiar: (v) => ref.editarPaciente(
                      (p) => p.copyWith(acompananteParentesco: v),
                    ),
                  ),
                  CampoTexto(
                    etiqueta: 'Teléfono',
                    valorInicial: p.acompananteTelefono,
                    teclado: TextInputType.phone,
                    alCambiar: (v) => ref.editarPaciente(
                      (p) => p.copyWith(acompananteTelefono: v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Separador extends StatelessWidget {
  const _Separador(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Row(
        children: [
          Text(
            texto.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
              color: ColoresMarca.textoSuave,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: ColoresMarca.borde)),
        ],
      ),
    );
  }
}
