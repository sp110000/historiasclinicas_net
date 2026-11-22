import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../core/consultorio/procedimientos/plantilla_procedimiento.dart';
import '../../../core/widgets/campos.dart';
import '../estado/consultorio_provider.dart';
import '../estado/pacientes_provider.dart';
import '../widgets/comunes.dart';

List<String> _lineas(String t) => [
  for (final l in t.split('\n'))
    if (l.trim().isNotEmpty) l.trim(),
];

/// Ajustes → Procedimientos → Editar: la definición declarativa de la
/// plantilla (pregunta 31). Guardar crea o reemplaza el borrador; para
/// aprobarla hace falta el protocolo completo.
class EditorProcedimientoPage extends ConsumerStatefulWidget {
  const EditorProcedimientoPage({super.key, required this.plantillaId});

  final String plantillaId;

  @override
  ConsumerState<EditorProcedimientoPage> createState() =>
      _EditorProcedimientoPageState();
}

class _EditorProcedimientoPageState
    extends ConsumerState<EditorProcedimientoPage> {
  late DefinicionProcedimiento _d;
  late int _version;
  late bool _esBorrador;
  var _guardando = false;

  @override
  void initState() {
    super.initState();
    final p = ref
        .read(servicioConsultorioProvider)
        .procedimientos
        .plantilla(widget.plantillaId)!;
    _d = p.ultima.definicion;
    _esBorrador = p.borrador != null;
    _version = p.borrador?.version ?? p.ultima.version + 1;
  }

  void _poner(DefinicionProcedimiento d) => setState(() => _d = d);

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await ref
          .read(servicioConsultorioProvider)
          .procedimientos
          .guardarBorrador(widget.plantillaId, _d);
      ref.read(versionIndiceProvider.notifier).cambio();
      if (!mounted) return;
      mostrarMensaje(context, 'Borrador v$_version guardado.');
      context.go('/ajustes');
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        mostrarMensaje(context, mensajeDeError(e));
      }
    }
  }

  Widget _items(EfectoItem efecto, String etiqueta) => _CampoLista(
    etiqueta: etiqueta,
    valores: [
      for (final i in _d.items)
        if (i.efecto == efecto) i.texto,
    ],
    alCambiar: (l) => _poner(
      _d.copyWith(
        items: [
          for (final i in _d.items)
            if (i.efecto != efecto) i,
          for (final t in l) ItemValoracion(t, efecto),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final faltan = d.faltantes;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver a Ajustes',
          onPressed: () => context.go('/ajustes'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          '${d.nombre} · ${_esBorrador ? 'borrador' : 'nueva versión'} v$_version',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: CuerpoConsultorio(
        children: [
          const Text(
            'Lo que viene de fábrica es una referencia (VERIFICAR). El '
            'protocolo (componentes, volúmenes, anestésico con su máximo, '
            'sesiones, intervalo, indicaciones, control, riesgos y '
            'alternativas) lo escribes tú: sin él la plantilla no se puede '
            'aprobar ni usar.',
            style: TextStyle(color: ColoresMarca.textoSuave),
          ),
          const SizedBox(height: 12),
          _Seccion(
            titulo: 'Procedimiento',
            children: [
              CampoTexto(
                etiqueta: 'Nombre',
                valorInicial: d.nombre,
                alCambiar: (v) => _poner(_d.copyWith(nombre: v.trim())),
              ),
              CampoTexto(
                etiqueta: 'Familia de técnicas (certificaciones, VERIFICAR)',
                valorInicial: d.familia,
                alCambiar: (v) => _poner(_d.copyWith(familia: v.trim())),
              ),
            ],
          ),
          _Seccion(
            titulo: 'Valoración',
            children: [
              RejillaCampos(
                anchoMinimo: 200,
                children: [
                  CampoNumero(
                    etiqueta: 'IMC desde el que avisa',
                    valor: d.imcMaximoAviso,
                    alCambiar: (v) => _poner(_d.copyWith(imcMaximoAviso: v)),
                  ),
                  CampoNumero(
                    etiqueta: 'Vigencia de «apto»',
                    unidad: 'días',
                    decimales: false,
                    valor: d.vigenciaDias.toDouble(),
                    alCambiar: (v) =>
                        _poner(_d.copyWith(vigenciaDias: (v ?? 90).round())),
                  ),
                ],
              ),
              _CampoLista(
                etiqueta: 'Zonas (una por línea)',
                valores: d.zonas,
                alCambiar: (l) => _poner(_d.copyWith(zonas: l)),
              ),
              _items(
                EfectoItem.noApto,
                'Contraindicaciones que dan «no apto» (una por línea)',
              ),
              _items(
                EfectoItem.diferir,
                'Contraindicaciones que dan «diferir» (una por línea)',
              ),
              _items(
                EfectoItem.precaucion,
                'Precauciones que piden nota (una por línea)',
              ),
              _CampoLista(
                etiqueta: 'Recomendaciones (una por línea)',
                valores: d.recomendaciones,
                alCambiar: (l) => _poner(_d.copyWith(recomendaciones: l)),
              ),
            ],
          ),
          if (d.tamizajes.isNotEmpty)
            _Seccion(
              titulo: 'Tamizajes',
              children: [
                const Text(
                  'Sin licencia confirmada la app no trae el texto de los '
                  'ítems (pregunta 30): cárgalo tú, uno por línea, en el '
                  'orden del instrumento.',
                  style: TextStyle(color: ColoresMarca.textoSuave),
                ),
                for (final (i, t) in d.tamizajes.indexed)
                  _CampoLista(
                    etiqueta:
                        '${t.nombre}: ${t.numeroItems} ítems · ${t.referencia}',
                    valores: t.textos,
                    conservarVacias: true,
                    alCambiar: (l) => _poner(
                      _d.copyWith(
                        tamizajes: [...d.tamizajes]..[i] = t.conTextos(l),
                      ),
                    ),
                  ),
              ],
            ),
          _Seccion(
            titulo: 'Protocolo de la sesión',
            children: [
              _CampoLista(
                etiqueta: 'Componentes de la solución (uno por línea)',
                valores: d.componentes,
                alCambiar: (l) => _poner(_d.copyWith(componentes: l)),
              ),
              RejillaCampos(
                anchoMinimo: 200,
                children: [
                  CampoNumero(
                    etiqueta: 'Volumen máximo por zona',
                    unidad: 'mL',
                    valor: d.volumenMaximoZonaMl,
                    alCambiar: (v) =>
                        _poner(_d.copyWith(volumenMaximoZonaMl: v)),
                  ),
                  CampoNumero(
                    etiqueta: 'Volumen máximo por sesión',
                    unidad: 'mL',
                    valor: d.volumenMaximoSesionMl,
                    alCambiar: (v) =>
                        _poner(_d.copyWith(volumenMaximoSesionMl: v)),
                  ),
                  CampoNumero(
                    etiqueta: 'Intervalo entre sesiones',
                    unidad: 'días',
                    decimales: false,
                    valor: d.intervaloDias?.toDouble(),
                    alCambiar: (v) =>
                        _poner(_d.copyWith(intervaloDias: v?.round())),
                  ),
                  CampoNumero(
                    etiqueta: 'Número de sesiones',
                    decimales: false,
                    valor: d.numeroSesiones?.toDouble(),
                    alCambiar: (v) =>
                        _poner(_d.copyWith(numeroSesiones: v?.round())),
                  ),
                  CampoNumero(
                    etiqueta: 'Días hasta el control',
                    unidad: 'días',
                    decimales: false,
                    valor: d.diasControl?.toDouble(),
                    alCambiar: (v) =>
                        _poner(_d.copyWith(diasControl: v?.round())),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text('ANESTÉSICOS', style: EstilosMarca.rotulo),
              const Text(
                'El máximo en mg/kg lo fijas tú (pregunta 32, VERIFICAR). La '
                'sesión avisa desde el 80 % y bloquea por encima del 100 %.',
                style: TextStyle(color: ColoresMarca.textoSuave),
              ),
              for (final (i, a) in d.anestesicos.indexed)
                _FilaAnestesico(
                  key: ValueKey('anestesico$i${d.anestesicos.length}'),
                  anestesico: a,
                  alCambiar: (x) => _poner(
                    _d.copyWith(anestesicos: [...d.anestesicos]..[i] = x),
                  ),
                  alQuitar: () => _poner(
                    _d.copyWith(anestesicos: [...d.anestesicos]..removeAt(i)),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _poner(
                    _d.copyWith(
                      anestesicos: [
                        ...d.anestesicos,
                        const AnestesicoProtocolo(nombre: ''),
                      ],
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar anestésico'),
                ),
              ),
              _CampoLista(
                etiqueta: 'Lista de verificación previa (un ítem por línea)',
                valores: d.listaVerificacion,
                alCambiar: (l) => _poner(_d.copyWith(listaVerificacion: l)),
              ),
              CampoTexto(
                etiqueta: 'Indicaciones posteriores',
                valorInicial: d.indicacionesPosteriores,
                lineas: 5,
                alCambiar: (v) =>
                    _poner(_d.copyWith(indicacionesPosteriores: v.trim())),
              ),
              CampoTexto(
                etiqueta: 'Protocolo escrito (opcional)',
                valorInicial: d.protocolo,
                lineas: 4,
                alCambiar: (v) => _poner(_d.copyWith(protocolo: v.trim())),
              ),
            ],
          ),
          _Seccion(
            titulo: 'Consentimiento informado',
            children: [
              CampoTexto(
                etiqueta: 'Riesgos (frecuentes y graves)',
                valorInicial: d.riesgos,
                lineas: 4,
                alCambiar: (v) => _poner(_d.copyWith(riesgos: v.trim())),
              ),
              CampoTexto(
                etiqueta: 'Alternativas',
                valorInicial: d.alternativas,
                lineas: 3,
                alCambiar: (v) => _poner(_d.copyWith(alternativas: v.trim())),
              ),
            ],
          ),
          if (faltan.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Para aprobarla falta ${faltan.join(', ')}.',
                style: const TextStyle(color: ColoresMarca.aviso),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: const Text('Guardar borrador'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.children});

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: RadiosMarca.tarjeta,
      border: Border.all(color: ColoresMarca.borde),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titulo.toUpperCase(), style: EstilosMarca.rotulo),
        const SizedBox(height: 10),
        for (final c in children) ...[c, const SizedBox(height: 12)],
      ],
    ),
  );
}

/// Lista editable como texto, un elemento por línea.
class _CampoLista extends StatelessWidget {
  const _CampoLista({
    required this.etiqueta,
    required this.valores,
    required this.alCambiar,
    this.conservarVacias = false,
  });

  final String etiqueta;
  final List<String> valores;
  final ValueChanged<List<String>> alCambiar;

  /// Conserva las líneas vacías (los ítems de un tamizaje van por orden).
  final bool conservarVacias;

  @override
  Widget build(BuildContext context) => CampoTexto(
    etiqueta: etiqueta,
    valorInicial: valores.join('\n'),
    lineas: 4,
    alCambiar: (t) => alCambiar(
      conservarVacias ? [for (final l in t.split('\n')) l.trim()] : _lineas(t),
    ),
  );
}

class _FilaAnestesico extends StatelessWidget {
  const _FilaAnestesico({
    super.key,
    required this.anestesico,
    required this.alCambiar,
    required this.alQuitar,
  });

  final AnestesicoProtocolo anestesico;
  final ValueChanged<AnestesicoProtocolo> alCambiar;
  final VoidCallback alQuitar;

  @override
  Widget build(BuildContext context) {
    final a = anestesico;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RejillaCampos(
            anchoMinimo: 160,
            children: [
              CampoTexto(
                etiqueta: 'Anestésico',
                valorInicial: a.nombre,
                alCambiar: (v) => alCambiar(
                  AnestesicoProtocolo(
                    nombre: v.trim(),
                    concentracionMgMl: a.concentracionMgMl,
                    maximoMgKg: a.maximoMgKg,
                  ),
                ),
              ),
              CampoNumero(
                etiqueta: 'Concentración',
                unidad: 'mg/mL',
                valor: a.concentracionMgMl,
                alCambiar: (v) => alCambiar(
                  AnestesicoProtocolo(
                    nombre: a.nombre,
                    concentracionMgMl: v,
                    maximoMgKg: a.maximoMgKg,
                  ),
                ),
              ),
              CampoNumero(
                etiqueta: 'Máximo',
                unidad: 'mg/kg',
                valor: a.maximoMgKg,
                alCambiar: (v) => alCambiar(
                  AnestesicoProtocolo(
                    nombre: a.nombre,
                    concentracionMgMl: a.concentracionMgMl,
                    maximoMgKg: v,
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Quitar el anestésico',
          onPressed: alQuitar,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}
