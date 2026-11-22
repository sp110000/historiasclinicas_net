import 'package:flutter_test/flutter_test.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/documento.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/documento_clinico.dart';
import 'package:historiasclinicas_net/core/consultorio/documentos/plantillas.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/configuracion.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/ficha_paciente.dart';
import 'package:historiasclinicas_net/core/consultorio/modelos/registro_historia.dart';
import 'package:historiasclinicas_net/core/consultorio/reglas/documentos.dart';
import 'package:historiasclinicas_net/core/consultorio/repositorio/bitacora.dart';
import 'package:historiasclinicas_net/core/consultorio/servicio.dart';
import 'package:historiasclinicas_net/core/models/medico.dart';
import 'package:historiasclinicas_net/core/pais/perfil_pais.dart';
import 'package:historiasclinicas_net/core/pdf/fuentes_pdf.dart';
import 'package:historiasclinicas_net/core/pdf/lector_adjunto.dart';

import 'ayudas_consultorio.dart';
import 'ayudas_historias.dart';
import 'documentos_test.dart' show textoPdf;

final _hoy = DateTime(2026, 11, 21, 9, 30);

const _prestador = ConfiguracionConsultorio(
  nit: '900123456-7',
  codigoReps: '1969800001',
);

Plantilla _aprobada(String id) =>
    plantillasDeFabrica[id]!.aprobada(DateTime(2026, 11, 1));

/// Un borrador que pasa todas las reglas de su tipo.
BorradorDocumento _valido(TipoPlantilla tipo) {
  final base = BorradorDocumento(
    tipo: tipo,
    plantillaId: '',
    versionPlantilla: 1,
    titulo: tipo.etiqueta,
    texto: 'Texto completo del documento.',
    desde: DateTime(2026, 11, 21),
  );
  return switch (tipo) {
    TipoPlantilla.certificado => base.copyWith(finalidad: 'la empresa'),
    TipoPlantilla.incapacidad => base.copyWith(
      diagnostico: const DiagnosticoDocumento(
        codigo: 'A09X',
        descripcion: 'Diarrea y gastroenteritis de presunto origen infeccioso',
      ),
      dias: 3,
    ),
    TipoPlantilla.orden => base.copyWith(
      diagnostico: const DiagnosticoDocumento(
        codigo: 'E669',
        descripcion: 'Obesidad, no especificada',
      ),
    ),
    TipoPlantilla.remision => base.copyWith(
      destino: 'Endocrinología',
      diagnostico: const DiagnosticoDocumento(descripcion: 'Hipotiroidismo'),
    ),
    _ => base,
  };
}

const _plantillaDe = {
  TipoPlantilla.certificado: 'certificado_general',
  TipoPlantilla.incapacidad: 'incapacidad',
  TipoPlantilla.orden: 'orden_tsh',
  TipoPlantilla.remision: 'remision',
};

EvaluacionDocumento _evaluar(
  BorradorDocumento b, {
  Plantilla? plantilla,
  ConfiguracionConsultorio configuracion = _prestador,
  bool medicoListo = true,
}) => evaluarDocumento(
  b,
  plantilla: plantilla ?? _aprobada(_plantillaDe[b.tipo]!),
  configuracion: configuracion,
  medicoListo: medicoListo,
  ahora: _hoy,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Reglas de los documentos (por tabla)', () {
    test('los válidos de cada tipo se emiten sin avisos', () {
      for (final tipo in TipoPlantilla.clinicos) {
        final e = _evaluar(_valido(tipo));
        expect(e.permiteEmitir, isTrue, reason: '$tipo: ${e.bloqueos}');
        expect(e.avisos, isEmpty, reason: '$tipo');
      }
    });

    final bloqueos =
        <
          ({
            String caso,
            BorradorDocumento b,
            Plantilla? plantilla,
            bool medicoListo,
            String bloqueo,
          })
        >[
          (
            caso: 'plantilla en borrador',
            b: _valido(TipoPlantilla.orden),
            plantilla: plantillasDeFabrica['orden_tsh'],
            medicoListo: true,
            bloqueo: 'está en borrador',
          ),
          (
            caso: 'datos del médico incompletos',
            b: _valido(TipoPlantilla.certificado),
            plantilla: null,
            medicoListo: false,
            bloqueo: 'Completa tus datos de médico',
          ),
          (
            caso: 'texto vacío',
            b: _valido(TipoPlantilla.remision).copyWith(texto: '  '),
            plantilla: null,
            medicoListo: true,
            bloqueo: 'Escribe el texto',
          ),
          (
            caso: 'certificado sin finalidad',
            b: _valido(TipoPlantilla.certificado).copyWith(finalidad: ''),
            plantilla: null,
            medicoListo: true,
            bloqueo: 'con qué destino',
          ),
          (
            caso: 'certificado con diagnóstico pedido y vacío',
            b: _valido(
              TipoPlantilla.certificado,
            ).copyWith(incluirDiagnostico: true),
            plantilla: null,
            medicoListo: true,
            bloqueo: 'Escribe el diagnóstico o no lo incluyas',
          ),
          (
            caso: 'incapacidad sin diagnóstico',
            b: _valido(
              TipoPlantilla.incapacidad,
            ).copyWith(diagnostico: const DiagnosticoDocumento()),
            plantilla: null,
            medicoListo: true,
            bloqueo: 'diagnóstico de la incapacidad',
          ),
          (
            caso: 'incapacidad sin días',
            b: _valido(TipoPlantilla.incapacidad).copyWith(dias: null),
            plantilla: null,
            medicoListo: true,
            bloqueo: 'días de incapacidad',
          ),
          (
            caso: 'incapacidad de 0 días',
            b: _valido(TipoPlantilla.incapacidad).copyWith(dias: 0),
            plantilla: null,
            medicoListo: true,
            bloqueo: 'días de incapacidad',
          ),
          (
            caso: 'remisión sin especialidad',
            b: _valido(TipoPlantilla.remision).copyWith(destino: ''),
            plantilla: null,
            medicoListo: true,
            bloqueo: 'especialidad o el servicio',
          ),
        ];
    for (final c in bloqueos) {
      test('bloquea: ${c.caso}', () {
        final e = _evaluar(
          c.b,
          plantilla: c.plantilla,
          medicoListo: c.medicoListo,
        );
        expect(e.permiteEmitir, isFalse);
        expect(e.bloqueos.join(' | '), contains(c.bloqueo));
      });
    }

    final avisos =
        <
          ({
            String caso,
            BorradorDocumento b,
            ConfiguracionConsultorio configuracion,
            String aviso,
          })
        >[
          (
            caso: 'incapacidad sin código CIE-10',
            b: _valido(TipoPlantilla.incapacidad).copyWith(
              diagnostico: const DiagnosticoDocumento(descripcion: 'Diarrea'),
            ),
            configuracion: _prestador,
            aviso: 'no tiene código CIE-10',
          ),
          (
            caso: 'incapacidad sin NIT',
            b: _valido(TipoPlantilla.incapacidad),
            configuracion: _prestador.copyWith(nit: ''),
            aviso: 'Falta tu NIT',
          ),
          (
            caso: 'incapacidad sin código REPS',
            b: _valido(TipoPlantilla.incapacidad),
            configuracion: _prestador.copyWith(codigoReps: ''),
            aviso: 'código de prestador del REPS',
          ),
          (
            caso: 'incapacidad retroactiva',
            b: _valido(
              TipoPlantilla.incapacidad,
            ).copyWith(desde: DateTime(2026, 11, 19)),
            configuracion: _prestador,
            aviso: 'Empieza antes de hoy (19/11/2026): es retroactiva.',
          ),
          (
            caso: 'retroactiva más allá del límite escrito',
            b: _valido(
              TipoPlantilla.incapacidad,
            ).copyWith(desde: DateTime(2026, 11, 16)),
            configuracion: _prestador.copyWith(maxDiasRetroactivos: 3),
            aviso: 'hace 5 días: más que el límite de retroactividad de 3',
          ),
          (
            caso: 'más días que el límite escrito',
            b: _valido(TipoPlantilla.incapacidad).copyWith(dias: 31),
            configuracion: _prestador.copyWith(maxDiasIncapacidad: 30),
            aviso: 'Son 31 días: más que el límite de 30',
          ),
          (
            caso: 'orden sin impresión diagnóstica',
            b: _valido(
              TipoPlantilla.orden,
            ).copyWith(diagnostico: const DiagnosticoDocumento()),
            configuracion: _prestador,
            aviso: 'Sin impresión diagnóstica',
          ),
          (
            caso: 'remisión sin diagnóstico',
            b: _valido(
              TipoPlantilla.remision,
            ).copyWith(diagnostico: const DiagnosticoDocumento()),
            configuracion: _prestador,
            aviso: 'Sin diagnóstico',
          ),
          (
            caso: 'espacios sin completar',
            b: _valido(
              TipoPlantilla.certificado,
            ).copyWith(texto: 'Concepto: ______'),
            configuracion: _prestador,
            aviso: 'Quedan espacios «______»',
          ),
        ];
    for (final c in avisos) {
      test('avisa sin bloquear: ${c.caso}', () {
        final e = _evaluar(c.b, configuracion: c.configuracion);
        expect(e.permiteEmitir, isTrue, reason: '${e.bloqueos}');
        expect(e.avisos.join(' | '), contains(c.aviso));
      });
    }

    test('sin límites escritos no avisa por los días (VERIFICAR)', () {
      final e = _evaluar(
        _valido(TipoPlantilla.incapacidad).copyWith(dias: 400),
      );
      expect(e.avisos, isEmpty);
    });
  });

  group('Datos del documento', () {
    test('la incapacidad termina el último día contado', () {
      final b = _valido(TipoPlantilla.incapacidad);
      expect(b.hasta, DateTime(2026, 11, 23));
      expect(
        b.copyWith(desde: DateTime(2026, 11, 30)).hasta,
        DateTime(2026, 12, 2),
      );
      expect(b.copyWith(dias: null).hasta, isNull);
    });

    test('los días también en letras', () {
      const casos = {
        1: 'uno',
        3: 'tres',
        16: 'dieciséis',
        21: 'veintiuno',
        30: 'treinta',
        45: 'cuarenta y cinco',
        100: 'cien',
        101: 'ciento uno',
        180: 'ciento ochenta',
        999: 'novecientos noventa y nueve',
      };
      casos.forEach((n, letras) => expect(numeroEnLetras(n), letras));
    });

    test('el diagnóstico de un certificado solo va si se pide', () {
      final b = _valido(
        TipoPlantilla.certificado,
      ).copyWith(diagnostico: const DiagnosticoDocumento(descripcion: 'Sano'));
      expect(filasDocumento(b).map((f) => f.$1), ['Se expide con destino a']);
      expect(
        filasDocumento(b.copyWith(incluirDiagnostico: true)).map((f) => f.$1),
        ['Diagnóstico', 'Se expide con destino a'],
      );
    });

    test('las filas de la incapacidad, también desde lo sellado', () {
      final b = _valido(
        TipoPlantilla.incapacidad,
      ).copyWith(prorroga: true, prorrogaDe: 'IN-000004');
      const prestador = PrestadorDocumento(
        nombre: 'Consultorio',
        nit: '900',
        codigoReps: '196',
      );
      final filas = filasDocumento(b, prestador: prestador);
      expect(filas, [
        (
          'Diagnóstico',
          'A09X Diarrea y gastroenteritis de presunto origen infeccioso',
        ),
        ('Origen', 'Enfermedad general'),
        ('Días', '3 (tres)'),
        ('Desde', '21/11/2026'),
        ('Hasta', '23/11/2026'),
        ('Prórroga', 'Sí, de IN-000004'),
        ('Prestador', 'Consultorio · NIT 900 · código REPS 196'),
      ]);
      expect(
        filasDeCampos(
          TipoPlantilla.incapacidad,
          b.campos(),
          prestador: prestador,
        ),
        filas,
      );
    });
  });

  group('Plantillas de los documentos clínicos', () {
    late BancoConsultorio b;

    setUp(() async {
      b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
    });

    test('las de fábrica son borradores, varias por tipo', () {
      final docs = b.servicio.documentos;
      expect(
        docs.plantillasDe(TipoPlantilla.certificado).map((p) => p.nombre),
        ['General', 'Laboral', 'Deportivo', 'De asistencia'],
      );
      expect(docs.plantillasDe(TipoPlantilla.orden).map((p) => p.nombre), [
        'Perfil metabólico',
        'TSH',
        'HbA1c',
        'Perfil lipídico',
        'Función hepática',
        'Imágenes diagnósticas',
      ]);
      expect(
        docs.plantillasDe(TipoPlantilla.incapacidad).single.id,
        'incapacidad',
      );
      expect(docs.plantillasDe(TipoPlantilla.remision), hasLength(1));
      for (final tipo in TipoPlantilla.clinicos) {
        for (final p in docs.plantillasDe(tipo)) {
          expect(p.usable, isFalse, reason: p.id);
          expect(p.ultima.cuerpo, isNotEmpty, reason: p.id);
          expect(p.tipo, tipo);
        }
      }
    });

    test(
      'una propia se agrega en borrador, se edita, se aprueba y vuelve',
      () async {
        final docs = b.servicio.documentos;
        final p = await docs.crearPlantilla(
          TipoPlantilla.orden,
          'Control prenatal',
        );
        expect(p.propia, isTrue);
        expect(p.usable, isFalse);
        await expectLater(
          docs.crearPlantilla(TipoPlantilla.orden, 'control prenatal'),
          throwsStateError,
        );
        await expectLater(
          docs.crearPlantilla(TipoPlantilla.incapacidad, 'Otra'),
          throwsStateError,
        );
        await docs.guardarBorradorDe(
          p.id,
          titulo: 'Orden de laboratorio clínico',
          cuerpo: 'Solicito:\n- Hemograma',
        );
        await docs.aprobarDe(p.id);
        await docs.aprobarDe('orden_tsh');
        await b.servicio.bloquear();
        await b.servicio.desbloquear(fraseDePrueba);
        final otra = b.servicio.documentos.plantillaPorId(p.id)!;
        expect(otra.nombre, 'Control prenatal');
        expect(otra.vigente!.cuerpo, contains('Hemograma'));
        expect(
          b.servicio.documentos.plantillasDe(TipoPlantilla.orden).last.id,
          p.id,
        );
        expect(
          b.servicio.documentos.plantillaPorId('orden_tsh')!.usable,
          isTrue,
        );
        expect(contieneTexto(b.todosLosBytes, 'Hemograma'), isFalse);
      },
    );
  });

  group('Emitir', () {
    late BancoConsultorio b;
    late FichaPaciente ficha;
    late FuentesPdf fuentes;

    setUpAll(() async => fuentes = await FuentesPdf.cargar());

    setUp(() async {
      b = BancoConsultorio();
      await b.servicio.crear(fraseDePrueba);
      final r = await b.servicio.registrarHistoria(
        HistoriaPendiente(
          datos: historiaSintetica(),
          revision: 1,
          origen: OrigenArchivo.importado,
        ),
      );
      ficha = b.servicio.indice.ficha(r!.pacienteId)!;
    });

    Future<DocumentoConsultorio> emitir(
      BorradorDocumento borrador, {
      Medico? medico,
      ConfiguracionConsultorio configuracion = _prestador,
    }) async => (await b.servicio.documentos.emitirDocumento(
      borrador,
      ficha: ficha,
      medico: medico ?? medicoCompleto(),
      pais: Pais.colombia,
      configuracion: configuracion,
      fuentes: fuentes,
    )).documento;

    test('certificado: número, documento.json sellado y PDF sin firma del '
        'paciente', () async {
      final docs = b.servicio.documentos;
      var borrador = docs.nuevoBorrador(
        TipoPlantilla.certificado,
        ficha: ficha,
        medico: medicoCompleto(),
      );
      expect(borrador.plantillaId, 'certificado_general');
      expect(borrador.texto, contains(ficha.nombreCompleto));
      expect(borrador.texto, contains('Dra. Ana Pérez Gómez'));
      expect(borrador.texto, contains('registro profesional RM 54321'));
      expect(borrador.texto, isNot(contains('{{')));

      // Sin aprobar no se emite.
      borrador = borrador.copyWith(finalidad: 'Empresa de prueba S. A. S.');
      await expectLater(emitir(borrador), throwsStateError);

      await docs.aprobarDe('certificado_general');
      borrador = docs.conPlantilla(
        borrador,
        'certificado_general',
        ficha: ficha,
        medico: medicoCompleto(),
      );
      borrador = borrador.copyWith(
        texto: borrador.texto
            .replaceFirst('Hallazgos: ______', 'Hallazgos: examen normal.')
            .replaceFirst('Concepto: ______', 'Concepto: sano.'),
      );
      expect(await docs.proximoNumero(TipoPlantilla.certificado), 'CE-000001');
      final r = await docs.emitirDocumento(
        borrador,
        ficha: ficha,
        medico: medicoCompleto(),
        pais: Pais.colombia,
        configuracion: _prestador,
        fuentes: fuentes,
      );
      final d = r.documento;
      expect(d.numero, 'CE-000001');
      expect(d.plantillaId, 'certificado_general');
      expect(d.versionPlantilla, 1);
      expect(d.campos['finalidad'], 'Empresa de prueba S. A. S.');
      expect(d.campos.containsKey('diagnostico'), isFalse);
      final adjuntos = adjuntosConMarca(r.pdf, marcaAdjuntoConsultorio);
      expect(leerDocumentoJson(adjuntos.single), d.datos);
      final texto = textoPdf(r.pdf);
      if (texto != null) {
        final t = texto.replaceAll(RegExp(r'\s+'), ' ');
        expect(t, contains('CERTIFICADO MÉDICO'));
        expect(t, contains('CE-000001'));
        expect(t, contains('Se expide con destino a'));
        expect(t, contains('Empresa de prueba S. A. S.'));
        expect(t, contains('Concepto: sano.'));
        expect(t, isNot(contains('Firma del paciente')));
      }
      expect(await docs.proximoNumero(TipoPlantilla.certificado), 'CE-000002');
      expect(
        (await b.servicio.bitacora()).map((e) => e.accion),
        contains(AccionBitacora.emitirDocumento),
      );
      expect(contieneTexto(b.todosLosBytes, 'Empresa de prueba'), isFalse);
      expect(docs.documentosDe(ficha.id).single.id, d.id);
    });

    test('incapacidad: filas del Decreto 1427 y número propio', () async {
      final docs = b.servicio.documentos;
      await docs.aprobarDe('incapacidad');
      final borrador = docs
          .nuevoBorrador(
            TipoPlantilla.incapacidad,
            ficha: ficha,
            medico: medicoCompleto(),
          )
          .copyWith(
            diagnostico: const DiagnosticoDocumento(
              codigo: 'A09X',
              descripcion: 'Diarrea y gastroenteritis',
            ),
            dias: 3,
          );
      final r = await b.servicio.documentos.emitirDocumento(
        borrador,
        ficha: ficha,
        medico: medicoCompleto(),
        pais: Pais.colombia,
        configuracion: _prestador,
        fuentes: fuentes,
      );
      expect(r.documento.numero, 'IN-000001');
      expect(r.documento.campos['dias'], 3);
      expect(r.documento.campos['hasta'], '2026-11-23');
      expect(
        (r.documento.campos['prestador']! as Map)['codigoReps'],
        '1969800001',
      );
      final texto = textoPdf(r.pdf);
      if (texto != null) {
        final t = texto.replaceAll(RegExp(r'\s+'), ' ');
        expect(t, contains('3 (tres)'));
        expect(t, contains('23/11/2026'));
        expect(t, contains('A09X Diarrea y gastroenteritis'));
        expect(t, contains('NIT 900123456-7'));
      }
    });

    test(
      'se anula con motivo, sin «revocar», y el número no se reutiliza',
      () async {
        final docs = b.servicio.documentos;
        await docs.aprobarDe('orden_tsh');
        final borrador = docs.nuevoBorrador(
          TipoPlantilla.orden,
          ficha: ficha,
          medico: medicoCompleto(),
          plantillaId: 'orden_tsh',
        );
        expect(borrador.texto, contains('TSH'));
        final d = await emitir(borrador);
        expect(d.numero, 'OR-000001');
        await docs.cambiarEstado(
          d.id,
          EstadoDocumento.anulado,
          motivo: 'Paciente equivocado',
        );
        expect(docs.documento(d.id)!.estado, EstadoDocumento.anulado);
        expect((await emitir(borrador)).numero, 'OR-000002');
        expect(TipoPlantilla.orden.conFirmaDelPaciente, isFalse);
      },
    );

    test('un borrador de otra versión no se emite', () async {
      final docs = b.servicio.documentos;
      await docs.aprobarDe('remision');
      final borrador = docs
          .nuevoBorrador(
            TipoPlantilla.remision,
            ficha: ficha,
            medico: medicoCompleto(),
          )
          .copyWith(destino: 'Endocrinología');
      final e = docs.evaluar(
        borrador.copyWith(versionPlantilla: 2),
        medico: medicoCompleto(),
        configuracion: _prestador,
      );
      expect(e.bloqueos.single, contains('vuelve a elegirla'));
      expect((await emitir(borrador)).numero, 'RM-000001');
    });
  });
}
