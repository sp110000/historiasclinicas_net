import '../canonico/jcs.dart';
import '../modelo/documento_rda.dart';
import 'referencias.dart';

/// Nodo del grafo: una instancia de recurso FHIR con su origen.
class NodoGrafo {
  const NodoGrafo({
    required this.idLocal,
    required this.recurso,
    this.perfil,
    this.tablaOrigen,
    this.pkOrigen,
  });

  final String idLocal;
  final Map<String, Object?> recurso;
  final String? perfil;
  final String? tablaOrigen;
  final String? pkOrigen;

  String get tipo => recurso['resourceType']! as String;
}

/// Arista: una referencia FHIR (`ruta_fhir`) de un nodo a otro, o a un
/// recurso externo (`destinoExterno`).
class AristaGrafo {
  const AristaGrafo(this.origen, this.ruta, this.destino, this.referencia);

  final String origen;

  /// Ruta FHIR del elemento `Reference`, p. ej. `Encounter.diagnosis[0].condition`.
  final String ruta;

  /// `id` local del destino; `null` si la referencia es externa con tipo.
  final String? destino;
  final String referencia;
}

/// Grafo dirigido de un documento RDA. Admite ciclos legítimos
/// (`Encounter.diagnosis` ↔ `Condition.encounter`).
///
/// * **Raíz local:** el `Encounter` de la atención; agrega el estado de
///   interoperabilidad y el VIDA (en `ihce_rda_documento`, no en el FHIR).
/// * **Cabeza de transmisión:** el `Composition`, que ocupa `entry[0]`.
class GrafoRda {
  GrafoRda(this.referencias);

  final ReferenciasRda referencias;
  final _nodos = <String, NodoGrafo>{};
  String? raiz;
  String? cabeza;

  /// Referencias externas permitidas: recursos persistidos en IHCE (IPS,
  /// EAPB) o que el perfil fija (`Organization/MinSalud`).
  final externos = <String>{};

  Iterable<NodoGrafo> get nodos => _nodos.values;

  NodoGrafo? operator [](String idLocal) => _nodos[idLocal];

  void agregar(NodoGrafo n) {
    if (_nodos.containsKey(n.idLocal)) {
      throw StateError('Nodo repetido: ${n.idLocal}');
    }
    _nodos[n.idLocal] = n;
  }

  /// Recorre cada recurso y extrae sus `Reference.reference`.
  List<AristaGrafo> aristas() {
    final r = <AristaGrafo>[];
    void visitar(String origen, Object? v, String ruta) {
      if (v is Map) {
        final ref = v['reference'];
        if (ref is String) {
          r.add(AristaGrafo(origen, ruta, referencias.idDe(ref), ref));
        }
        for (final e in v.entries) {
          if (e.key == 'reference') continue;
          visitar(origen, e.value, '$ruta.${e.key}');
        }
      } else if (v is List) {
        for (var i = 0; i < v.length; i++) {
          visitar(origen, v[i], '$ruta[$i]');
        }
      }
    }

    for (final n in _nodos.values) {
      for (final e in n.recurso.entries) {
        visitar(n.idLocal, e.value, '${n.tipo}.${e.key}');
      }
    }
    return r;
  }

  /// Errores de integridad: aristas a nodos inexistentes que no son
  /// externos permitidos, y nodos que no se alcanzan desde la cabeza.
  List<String> verificarIntegridad() {
    final errores = <String>[];
    final todas = aristas();
    for (final a in todas) {
      final interno = a.destino != null && _nodos.containsKey(a.destino);
      final externo =
          externos.contains(a.referencia) ||
          (a.destino != null && externos.contains(a.destino));
      if (!interno && !externo) {
        errores.add('${a.ruta}: referencia sin entrada (${a.referencia})');
      }
    }
    if (cabeza == null || !_nodos.containsKey(cabeza)) {
      errores.add('El grafo no tiene Composition (cabeza)');
      return errores;
    }
    if (raiz == null || !_nodos.containsKey(raiz)) {
      errores.add('El grafo no tiene Encounter (raíz)');
    }
    final alcanzados = <String>{cabeza!};
    final pendientes = [cabeza!];
    while (pendientes.isNotEmpty) {
      final actual = pendientes.removeLast();
      for (final a in todas) {
        if (a.origen == actual &&
            a.destino != null &&
            _nodos.containsKey(a.destino) &&
            alcanzados.add(a.destino!)) {
          pendientes.add(a.destino!);
        }
      }
    }
    for (final id in _nodos.keys) {
      if (!alcanzados.contains(id)) errores.add('Nodo huérfano: $id');
    }
    return errores;
  }

  /// Registros persistibles de nodos y aristas internas.
  (List<NodoRda>, List<AristaRda>) aRegistros(String documentoId) => (
    [
      for (final n in _nodos.values)
        NodoRda(
          documentoId: documentoId,
          idLocal: n.idLocal,
          tipoRecurso: n.tipo,
          perfil: n.perfil,
          tablaOrigen: n.tablaOrigen,
          pkOrigen: n.pkOrigen,
          sha256: sha256Hex(jcsBytes(n.recurso)),
        ),
    ],
    [
      for (final a in aristas())
        if (a.destino != null && _nodos.containsKey(a.destino))
          AristaRda(
            documentoId: documentoId,
            idLocalOrigen: a.origen,
            rutaFhir: a.ruta,
            idLocalDestino: a.destino!,
          ),
    ],
  );
}
