/// Textos de cada sección de la historia, compartidos por la vista de solo
/// lectura y el PDF (lo que se ve en pantalla es lo que se imprime).
library;

import '../clinica/gestacion.dart';
import '../clinica/imc.dart';
import '../models/historia.dart';
import '../models/secciones.dart';
import '../pais/perfil_pais.dart';
import '../utils/fechas.dart';
import '../utils/numeros.dart';

enum AnchoDato { corto, medio, completo }

class DatoMostrado {
  const DatoMostrado(this.etiqueta, this.valor, {this.ancho = AnchoDato.corto});

  final String etiqueta;
  final String valor;
  final AnchoDato ancho;
}

String _etiquetaOpcion(List<Opcion> opciones, String? codigo) => codigo == null
    ? ''
    : opciones
          .firstWhere(
            (o) => o.codigo == codigo,
            orElse: () => Opcion(codigo, codigo),
          )
          .etiqueta;

String _unidad(double? v, String unidad, {int? decimales}) =>
    v == null ? '' : '${formatoNumero(v, decimales: decimales)} $unidad';

/// "24,6 kg/m² · Normal", o vacío si falta peso o talla.
String textoImc(HistoriaClinica h, {SignosVitales? signos}) {
  final s = signos ?? h.signos;
  final imc = calcularImc(pesoKg: s.peso, tallaCm: s.talla);
  if (imc == null) return '';
  final interpretacion = interpretarImc(
    imc,
    edadAnios: h.edadAnios,
    gestante: h.antecedentes.gineco.gestante,
  );
  return '${formatoNumero(imc, decimales: 1)} kg/m² · ${interpretacion.texto}';
}

/// "EG 24 semanas + 3 días · FPP 06/12/2026", si es gestante y hay FUM.
String textoGestacion(HistoriaClinica h) {
  final g = h.antecedentes.gineco;
  if (!g.gestante || g.fum == null) return '';
  final eg = edadGestacional(g.fum!, h.fechaAtencion);
  return [
    if (eg != null) 'EG ${eg.texto}',
    'FPP ${formatoFecha(fechaProbableParto(g.fum!))}',
  ].join(' · ');
}

/// Signos vitales en una línea: "PA 118/76 mmHg · FC 92 lpm · …".
String resumenSignos(SignosVitales s) {
  String pa() {
    if (s.paSistolica == null && s.paDiastolica == null) return '';
    String v(double? x) => x == null ? '—' : formatoNumero(x);
    return 'PA ${v(s.paSistolica)}/${v(s.paDiastolica)} mmHg';
  }

  return [
    pa(),
    if (s.fc != null) 'FC ${_unidad(s.fc, 'lpm')}',
    if (s.fr != null) 'FR ${_unidad(s.fr, 'rpm')}',
    if (s.temperatura != null) 'T ${_unidad(s.temperatura, '°C')}',
    if (s.spo2 != null) 'SpO₂ ${_unidad(s.spo2, '%')}',
    if (s.peso != null) 'Peso ${_unidad(s.peso, 'kg')}',
    if (s.talla != null) 'Talla ${_unidad(s.talla, 'cm')}',
    if (s.glucemia != null) 'Glucemia ${_unidad(s.glucemia, 'mg/dL')}',
    if (s.perimetroAbdominal != null)
      'P. abdominal ${_unidad(s.perimetroAbdominal, 'cm')}',
  ].where((t) => t.isNotEmpty).join(' · ');
}

String textoAlergias(Antecedentes a) {
  if (a.niegaAlergias) return 'Niega alergias conocidas';
  return a.alergias.isEmpty ? 'No registradas' : a.alergias.join(', ');
}

/// Título de una sección según el país (p. ej. "Constantes vitales").
String tituloSeccion(SeccionHistoria s, PerfilPais perfil) =>
    s == SeccionHistoria.signos ? perfil.etiquetaSignosVitales : s.titulo;

/// Datos de la sección [s] para mostrar o imprimir; omite lo vacío.
List<DatoMostrado> datosDeSeccion(SeccionHistoria s, HistoriaClinica h) {
  final perfil = h.perfil;
  final datos = <DatoMostrado>[];
  void dato(
    String etiqueta,
    String valor, {
    AnchoDato ancho = AnchoDato.corto,
  }) {
    if (valor.trim().isNotEmpty) {
      datos.add(DatoMostrado(etiqueta, valor.trim(), ancho: ancho));
    }
  }

  switch (s) {
    case SeccionHistoria.paciente:
      final p = h.paciente;
      dato('Apellidos', p.apellidos.toUpperCase(), ancho: AnchoDato.medio);
      dato('Nombres', p.nombres, ancho: AnchoDato.medio);
      dato(
        'Documento',
        p.numeroDocumento.trim().isEmpty
            ? ''
            : '${p.tipoDocumento} ${p.numeroDocumento}',
      );
      dato(
        'Fecha de nacimiento',
        p.fechaNacimiento == null ? '' : formatoFecha(p.fechaNacimiento!),
      );
      dato('Edad', h.edadTexto);
      dato('Sexo', _etiquetaOpcion(opcionesSexo, p.sexo));
      dato('Fecha de la atención', formatoFechaHora(h.fechaAtencion));
      dato(
        'Tipo de consulta',
        _etiquetaOpcion(opcionesTipoConsulta, h.tipoConsulta),
      );
      dato('Teléfono', p.telefono);
      dato('Dirección', p.direccion, ancho: AnchoDato.medio);
      dato(perfil.etiquetaCiudad, p.ciudad);
      dato('Estado civil', p.estadoCivil);
      dato('Ocupación', p.ocupacion);
      dato(perfil.etiquetaAseguradora, p.aseguradora);
      final acompanante = [
        p.acompananteNombre.trim(),
        if (p.acompananteParentesco.trim().isNotEmpty)
          '(${p.acompananteParentesco.trim()})',
        if (p.acompananteTelefono.trim().isNotEmpty)
          '· ${p.acompananteTelefono.trim()}',
      ].where((t) => t.isNotEmpty).join(' ');
      dato('Acompañante / responsable', acompanante, ancho: AnchoDato.medio);
    case SeccionHistoria.motivo:
      dato('Motivo de consulta', h.motivoConsulta, ancho: AnchoDato.completo);
      dato('Enfermedad actual', h.enfermedadActual, ancho: AnchoDato.completo);
    case SeccionHistoria.antecedentes:
      final a = h.antecedentes;
      dato('Alergias', textoAlergias(a), ancho: AnchoDato.completo);
      dato('Personales', a.personales, ancho: AnchoDato.completo);
      dato('Medicación actual', a.medicacionActual, ancho: AnchoDato.completo);
      dato('Quirúrgicos', a.quirurgicos, ancho: AnchoDato.completo);
      dato('Familiares', a.familiares, ancho: AnchoDato.completo);
      dato('Hábitos', a.habitos, ancho: AnchoDato.completo);
      final g = a.gineco;
      if (h.esFemenino && !g.vacio) {
        dato(
          'Gineco-obstétricos',
          [
            g.formula,
            if (g.fum != null) 'FUM ${formatoFecha(g.fum!)}',
            if (g.anticoncepcion.trim().isNotEmpty)
              'Anticoncepción: ${g.anticoncepcion.trim()}',
            if (g.gestante) 'Gestante',
            textoGestacion(h),
          ].where((t) => t.isNotEmpty).join(' · '),
          ancho: AnchoDato.completo,
        );
      }
      dato('Otros', a.otros, ancho: AnchoDato.completo);
    case SeccionHistoria.revision:
      final r = h.revisionSistemas;
      for (final sistema in r.conEstado(EstadoSistema.refiere)) {
        dato(
          'Refiere · ${sistema.nombre}',
          r.de(sistema.codigo).detalle.trim().isEmpty
              ? 'Refiere síntomas'
              : r.de(sistema.codigo).detalle,
          ancho: AnchoDato.completo,
        );
      }
      final niega = r.conEstado(EstadoSistema.niega);
      dato(
        'Niega síntomas en',
        niega.length == sistemasRevision.length
            ? 'Todos los sistemas'
            : niega.map((s) => s.nombre).join(', '),
        ancho: AnchoDato.completo,
      );
      dato('Observaciones', r.observaciones, ancho: AnchoDato.completo);
    case SeccionHistoria.signos:
      final v = h.signos;
      if (v.paSistolica != null || v.paDiastolica != null) {
        String n(double? x) => x == null ? '—' : formatoNumero(x);
        dato('PA', '${n(v.paSistolica)}/${n(v.paDiastolica)} mmHg');
      }
      dato('FC', _unidad(v.fc, 'lpm'));
      dato('FR', _unidad(v.fr, 'rpm'));
      dato('Temperatura', _unidad(v.temperatura, '°C'));
      dato('SpO₂', _unidad(v.spo2, '%'));
      dato('Peso', _unidad(v.peso, 'kg'));
      dato('Talla', _unidad(v.talla, 'cm'));
      dato('IMC', textoImc(h), ancho: AnchoDato.medio);
      dato('Glucemia capilar', _unidad(v.glucemia, 'mg/dL'));
      dato('Perímetro abdominal', _unidad(v.perimetroAbdominal, 'cm'));
    case SeccionHistoria.examen:
      dato('Estado general', h.examen.estadoGeneral, ancho: AnchoDato.completo);
      dato('Hallazgos', h.examen.hallazgos, ancho: AnchoDato.completo);
    case SeccionHistoria.analisis:
      dato('Análisis', h.analisis, ancho: AnchoDato.completo);
    case SeccionHistoria.diagnosticos:
      for (final (i, d) in h.diagnosticos.indexed) {
        dato(
          '${i + 1}. ${_etiquetaOpcion(opcionesTipoDiagnostico, d.tipo)} · '
          '${perfil.etiquetaCaracter(d.caracter)}',
          d.textoCorto,
          ancho: AnchoDato.completo,
        );
      }
    case SeccionHistoria.plan:
      final p = h.plan;
      dato('Plan terapéutico', p.planTerapeutico, ancho: AnchoDato.completo);
      dato(
        'Exámenes solicitados',
        p.examenesSolicitados,
        ancho: AnchoDato.completo,
      );
      dato('Interconsultas', p.interconsultas, ancho: AnchoDato.completo);
      dato(
        'Indicaciones y signos de alarma',
        p.indicaciones,
        ancho: AnchoDato.completo,
      );
      dato(
        'Próximo control',
        p.proximoControl == null ? '' : formatoFecha(p.proximoControl!),
      );
    case SeccionHistoria.firma:
      dato('Firma', h.firma.incluirFirma ? 'Se incluye' : 'No se incluye');
      dato('Sello', h.firma.incluirSello ? 'Se incluye' : 'No se incluye');
    case SeccionHistoria.evoluciones:
      break;
  }
  return datos;
}

/// Una línea para la sección plegada en modo "historia abierta".
String resumenSeccion(SeccionHistoria s, HistoriaClinica h) {
  String corta(String t) {
    final una = t.trim().replaceAll(RegExp(r'\s+'), ' ');
    return una.length > 110 ? '${una.substring(0, 110)}…' : una;
  }

  final p = h.paciente;
  return switch (s) {
    SeccionHistoria.paciente => [
      p.nombreCompleto,
      if (p.numeroDocumento.isNotEmpty)
        '${p.tipoDocumento} ${p.numeroDocumento}',
      h.edadTexto,
      _etiquetaOpcion(opcionesSexo, p.sexo),
    ].where((t) => t.isNotEmpty).join(' · '),
    SeccionHistoria.motivo => corta(h.motivoConsulta),
    SeccionHistoria.antecedentes =>
      'Alergias: ${textoAlergias(h.antecedentes)}',
    SeccionHistoria.revision => _resumenRevision(h.revisionSistemas),
    SeccionHistoria.signos => resumenSignos(h.signos),
    SeccionHistoria.examen => corta(
      h.examen.estadoGeneral.isNotEmpty
          ? h.examen.estadoGeneral
          : h.examen.hallazgos,
    ),
    SeccionHistoria.analisis => corta(h.analisis),
    SeccionHistoria.diagnosticos => corta(
      h.diagnosticos.map((d) => d.textoCorto).join('; '),
    ),
    SeccionHistoria.plan => corta(
      h.plan.planTerapeutico.isNotEmpty
          ? h.plan.planTerapeutico
          : h.plan.indicaciones,
    ),
    SeccionHistoria.firma =>
      'Firma ${h.firma.incluirFirma ? 'sí' : 'no'} · Sello ${h.firma.incluirSello ? 'sí' : 'no'}',
    SeccionHistoria.evoluciones => '',
  };
}

/// "Refiere: Respiratorio, Generales · Niega: 10 sistemas"
String _resumenRevision(RevisionSistemas r) {
  final refiere = r.conEstado(EstadoSistema.refiere);
  final niega = r.conEstado(EstadoSistema.niega);
  return [
    if (refiere.isNotEmpty)
      'Refiere: ${refiere.map((s) => s.nombre).join(', ')}',
    if (niega.isNotEmpty)
      'Niega: ${niega.length == sistemasRevision.length ? 'todos los sistemas' : '${niega.length} ${niega.length == 1 ? 'sistema' : 'sistemas'}'}',
  ].join(' · ');
}
