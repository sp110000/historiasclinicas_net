// T19: validador de identidad del paciente (Fase 4.3), casos por tabla.
import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/ihce/identidad/validador_identidad.dart';
import 'package:historiasclinicas_net/core/ihce/modelo/dto.dart';

import 'ayudas_ihce.dart';

PacienteDto _paciente({
  String tipo = 'CC',
  String numero = '9900000001',
  String primerApellido = 'SINTETICO',
  String segundoApellido = 'FICTICIO',
  String primerNombre = 'PACIENTE',
  String? sexo = 'F',
  bool conNacimiento = true,
}) => PacienteDto(
  origen: const Origen('datos.paciente', 'sintetico'),
  tipoDocumento: tipo,
  numeroDocumento: numero,
  primerApellido: primerApellido,
  segundoApellido: segundoApellido,
  primerNombre: primerNombre,
  segundoNombre: '',
  fechaNacimiento: conNacimiento ? DateTime(1990, 3, 15) : null,
  sexo: sexo,
  ciudad: '',
  nacionalidad: '170',
  paisResidencia: '170',
  etnia: '99',
  discapacidad: '08',
  zonaResidencia: '01',
);

typedef _Caso = ({
  String nombre,
  PacienteDto paciente,
  NivelIdentidad nivel,
  CasoIdentidad caso,
  List<String> campos,
});

final _casos = <_Caso>[
  (
    nombre: 'nacional completo',
    paciente: _paciente(),
    nivel: NivelIdentidad.ok,
    caso: CasoIdentidad.nacional,
    campos: [],
  ),
  (
    nombre: 'tarjeta de identidad',
    paciente: _paciente(tipo: 'TI', numero: '1099000001'),
    nivel: NivelIdentidad.ok,
    caso: CasoIdentidad.nacional,
    campos: [],
  ),
  (
    nombre: 'nacional sin segundo apellido',
    paciente: _paciente(segundoApellido: ''),
    nivel: NivelIdentidad.advertencia,
    caso: CasoIdentidad.nacional,
    campos: ['segundoApellido'],
  ),
  (
    nombre: 'sin fecha de nacimiento',
    paciente: _paciente(conNacimiento: false),
    nivel: NivelIdentidad.advertencia,
    caso: CasoIdentidad.nacional,
    campos: ['fechaNacimiento'],
  ),
  (
    nombre: 'sin tipo de documento',
    paciente: _paciente(tipo: ''),
    nivel: NivelIdentidad.bloqueo,
    caso: CasoIdentidad.nacional,
    campos: ['tipoDocumento'],
  ),
  (
    nombre: 'tipo fuera de ColombianPersonIdentifierCodes',
    paciente: _paciente(tipo: 'XX'),
    nivel: NivelIdentidad.bloqueo,
    caso: CasoIdentidad.nacional,
    campos: ['tipoDocumento'],
  ),
  (
    nombre: 'número vacío',
    paciente: _paciente(numero: ''),
    nivel: NivelIdentidad.bloqueo,
    caso: CasoIdentidad.nacional,
    campos: ['numeroDocumento'],
  ),
  (
    nombre: 'número con separadores',
    paciente: _paciente(numero: '99.000.001'),
    nivel: NivelIdentidad.bloqueo,
    caso: CasoIdentidad.nacional,
    campos: ['numeroDocumento'],
  ),
  (
    nombre: 'número con espacios',
    paciente: _paciente(numero: '99 000 001'),
    nivel: NivelIdentidad.bloqueo,
    caso: CasoIdentidad.nacional,
    campos: ['numeroDocumento'],
  ),
  (
    nombre: 'sin primer apellido',
    paciente: _paciente(primerApellido: ''),
    nivel: NivelIdentidad.bloqueo,
    caso: CasoIdentidad.nacional,
    campos: ['primerApellido'],
  ),
  (
    nombre: 'sin primer nombre',
    paciente: _paciente(primerNombre: ''),
    nivel: NivelIdentidad.bloqueo,
    caso: CasoIdentidad.nacional,
    campos: ['primerNombre'],
  ),
  (
    nombre: 'sin sexo biológico',
    paciente: _paciente(sexo: null),
    nivel: NivelIdentidad.bloqueo,
    caso: CasoIdentidad.nacional,
    campos: ['sexo'],
  ),
  (
    nombre: 'sexo fuera de la tabla',
    paciente: _paciente(sexo: 'X'),
    nivel: NivelIdentidad.bloqueo,
    caso: CasoIdentidad.nacional,
    campos: ['sexo'],
  ),
  (
    nombre: 'extranjero con pasaporte alfanumérico, sin segundo apellido',
    paciente: _paciente(tipo: 'PA', numero: 'AB123456', segundoApellido: ''),
    nivel: NivelIdentidad.ok,
    caso: CasoIdentidad.extranjero,
    campos: [],
  ),
  (
    nombre: 'extranjero con cédula de extranjería',
    paciente: _paciente(tipo: 'CE', numero: '990001'),
    nivel: NivelIdentidad.ok,
    caso: CasoIdentidad.extranjero,
    campos: [],
  ),
  (
    nombre: 'extranjero con PPT sin primer nombre',
    paciente: _paciente(tipo: 'PPT', numero: '9900001', primerNombre: ''),
    nivel: NivelIdentidad.bloqueo,
    caso: CasoIdentidad.extranjero,
    campos: ['primerNombre'],
  ),
  (
    nombre: 'adulto sin identificar',
    paciente: _paciente(tipo: 'AS', numero: 'AS990001', segundoApellido: ''),
    nivel: NivelIdentidad.ok,
    caso: CasoIdentidad.sinIdentificacion,
    campos: [],
  ),
  (
    nombre: 'menor sin identificar sin fecha de nacimiento',
    paciente: _paciente(tipo: 'MS', numero: 'MS990001', conNacimiento: false),
    nivel: NivelIdentidad.advertencia,
    caso: CasoIdentidad.sinIdentificacion,
    campos: ['fechaNacimiento'],
  ),
];

void main() {
  final validador = ValidadorIdentidad(catalogoDePrueba());

  group('T19 validador de identidad', () {
    for (final c in _casos) {
      test(c.nombre, () {
        final r = validador.validar(c.paciente);
        expect(r.nivel, c.nivel, reason: '${r.hallazgos}');
        expect(r.caso, c.caso);
        expect(r.hallazgos.map((h) => h.campo).toSet(), c.campos.toSet());
      });
    }

    test('los hallazgos no llevan el valor del dato', () {
      final r = validador.validar(
        _paciente(numero: '99.000.001', primerNombre: ''),
      );
      for (final h in r.hallazgos) {
        expect('$h', isNot(contains('99.000.001')));
        expect('$h', isNot(contains('SINTETICO')));
      }
    });
  });
}
