import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/documentos/plantillas.dart';
import '../../../core/pais/pais_provider.dart';
import '../../medico/medico_provider.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';
import '../widgets/editor_versionado.dart';

/// Ajustes → Plantillas: versiones, editar, aprobar y la política en PDF.
class TarjetaPlantillas extends ConsumerWidget {
  const TarjetaPlantillas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(versionIndiceProvider);
    final documentos = ref.read(servicioConsultorioProvider).documentos;
    return TarjetaConsultorio(
      icono: Icons.article_outlined,
      titulo: 'Plantillas de documentos',
      subtitulo: 'Textos con versión: solo se usan una vez aprobados',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Los textos base siguen la Ley 1581 de 2012 y el Decreto 1377 de '
            '2013, pero son un borrador: revísalos con tu abogado antes de '
            'aprobarlos (VERIFICAR). Cada documento firmado guarda la versión '
            'con la que se firmó.',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
          const SizedBox(height: 8),
          for (final tipo in TipoPlantilla.values)
            if (!tipo.clinico)
              _FilaPlantilla(plantilla: documentos.plantilla(tipo)),
        ],
      ),
    );
  }
}

class _FilaPlantilla extends ConsumerWidget {
  const _FilaPlantilla({required this.plantilla});

  final Plantilla plantilla;

  Future<void> _editar(BuildContext context, WidgetRef ref) async {
    final guardada = await editarTextoVersionado(
      context,
      titulo: plantilla.tipo.etiqueta,
      versiones: plantilla.versiones,
      marcadores: marcadoresPlantilla,
      guardar: (titulo, cuerpo) => ref
          .read(servicioConsultorioProvider)
          .documentos
          .guardarBorrador(plantilla.tipo, titulo: titulo, cuerpo: cuerpo),
    );
    if (guardada) ref.read(versionIndiceProvider.notifier).cambio();
  }

  Future<void> _politica(BuildContext context, WidgetRef ref) async {
    final medico = ref.read(medicoProvider);
    if (!medico.configurado) {
      mostrarMensaje(
        context,
        'Completa tus datos de médico: la política los lleva como '
        'responsable del tratamiento.',
      );
      context.push('/medico');
      return;
    }
    try {
      final pdf = await ref
          .read(servicioConsultorioProvider)
          .documentos
          .politicaPdf(medico: medico, pais: ref.read(paisProvider));
      ref.read(descargarPdfProvider)(
        pdf,
        'Politica_tratamiento_datos_v${plantilla.vigente!.version}.pdf',
      );
    } catch (e) {
      if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = plantilla;
    return FilaVersionada(
      nombre: p.tipo.etiqueta,
      versiones: p.versiones,
      alEditar: () => _editar(context, ref),
      textoAprobar:
          'Desde ahora los documentos nuevos de «${p.tipo.etiqueta}» usan '
          'este texto (VERIFICAR con tu abogado).',
      alAprobar: () async {
        await ref.read(servicioConsultorioProvider).documentos.aprobar(p.tipo);
        ref.read(versionIndiceProvider.notifier).cambio();
      },
      extra: [
        if (p.tipo == TipoPlantilla.politicaPrivacidad && p.vigente != null)
          OutlinedButton.icon(
            onPressed: () => _politica(context, ref),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Descargar PDF para exhibir'),
          ),
      ],
    );
  }
}

/// Marcadores que tienen sentido en un documento clínico.
const _marcadoresClinicos = [
  'medico',
  'registroMedico',
  'paciente',
  'documentoPaciente',
  'edad',
  'fecha',
  'responsable',
  'direccion',
  'ciudad',
  'telefono',
  'correo',
];

/// Ajustes → Documentos clínicos: certificados, incapacidad, órdenes y
/// remisión, con sus versiones. Se pueden agregar plantillas propias.
class TarjetaPlantillasClinicas extends ConsumerWidget {
  const TarjetaPlantillasClinicas({super.key});

  Future<void> _agregar(
    BuildContext context,
    WidgetRef ref,
    TipoPlantilla tipo,
  ) async {
    final nombre = await pedirTexto(
      context,
      titulo: 'Nueva plantilla · ${tipo.etiqueta}',
      etiqueta: 'Nombre (por ejemplo, «Control prenatal»)',
      aceptar: 'Agregar',
    );
    if (nombre == null || nombre.trim().isEmpty || !context.mounted) return;
    try {
      await ref
          .read(servicioConsultorioProvider)
          .documentos
          .crearPlantilla(tipo, nombre);
      ref.read(versionIndiceProvider.notifier).cambio();
      if (context.mounted) {
        mostrarMensaje(
          context,
          'Plantilla «${nombre.trim()}» agregada en borrador: escribe su '
          'texto y apruébala.',
        );
      }
    } catch (e) {
      if (context.mounted) mostrarMensaje(context, mensajeDeError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(versionIndiceProvider);
    final documentos = ref.read(servicioConsultorioProvider).documentos;
    return TarjetaConsultorio(
      icono: Icons.description_outlined,
      titulo: 'Documentos clínicos',
      subtitulo: 'Certificados, incapacidad, órdenes y remisión',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Los textos de fábrica son borradores con espacios «______»: '
            'revísalos y apruébalos antes de usarlos (VERIFICAR). El '
            'diagnóstico, los días, las fechas, la finalidad y el destino se '
            'piden en el formulario y van en un bloque aparte del PDF.',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
          for (final tipo in TipoPlantilla.clinicos) ...[
            const SizedBox(height: 14),
            Text(
              tipo.etiqueta.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: ColoresMarca.textoSuave,
              ),
            ),
            for (final p in documentos.plantillasDe(tipo))
              _FilaPlantillaClinica(plantilla: p),
            if (tipo.varias)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _agregar(context, ref, tipo),
                  icon: const Icon(Icons.add),
                  label: Text(
                    'Agregar plantilla de '
                    '${tipo == TipoPlantilla.certificado
                        ? 'certificado'
                        : tipo == TipoPlantilla.orden
                        ? 'orden'
                        : 'remisión'}',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _FilaPlantillaClinica extends ConsumerWidget {
  const _FilaPlantillaClinica({required this.plantilla});

  final Plantilla plantilla;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = plantilla;
    return FilaVersionada(
      nombre: p.propia ? '${p.nombre} (propia)' : p.nombre,
      versiones: p.versiones,
      alEditar: () async {
        final guardada = await editarTextoVersionado(
          context,
          titulo: '${p.tipo.etiqueta} · ${p.nombre}',
          versiones: p.versiones,
          marcadores: {
            for (final k in _marcadoresClinicos) k: marcadoresPlantilla[k]!,
          },
          guardar: (titulo, cuerpo) => ref
              .read(servicioConsultorioProvider)
              .documentos
              .guardarBorradorDe(p.id, titulo: titulo, cuerpo: cuerpo),
        );
        if (guardada) ref.read(versionIndiceProvider.notifier).cambio();
      },
      textoAprobar:
          'Desde ahora los documentos nuevos de «${p.nombre}» usan este '
          'texto (VERIFICAR).',
      alAprobar: () async {
        await ref.read(servicioConsultorioProvider).documentos.aprobarDe(p.id);
        ref.read(versionIndiceProvider.notifier).cambio();
      },
    );
  }
}
