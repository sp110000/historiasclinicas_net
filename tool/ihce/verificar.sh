#!/usr/bin/env bash
# ihce:verify — gate completo del módulo IHCE/RDA (Fase 8), en un comando:
#
#   aprovisionamiento → pruebas → capa 1 → capa 2 → regla 10
#
#   tool/ihce/verificar.sh
#
# Capa 1: JSON Schema oficial de FHIR R4 sobre cada recurso y Bundle
# generado (dentro de las pruebas). Criterio: cero errores.
# Capa 2: validador oficial de HL7 con la guía fijada en VERSIONS.lock y
# -tx n/a. Criterio: cero hallazgos error/fatal fuera de la línea base
# (docs/ihce/validation-baseline.json, solo exclusiones reproducidas en un
# artefacto oficial con el mismo comando o causadas por -tx n/a).
# Sin JRE, la capa 2 queda PENDIENTE (no superada) y el comando sale con 3.
#
# Ninguna prueba ni paso llama a IHCE: la red solo se usa para verificar o
# descargar artefactos normativos públicos (fetch_fhir_tooling.sh).
set -uo pipefail
cd "$(dirname "$0")/../.."

FLUTTER=${FLUTTER:-flutter}
DART=${DART:-dart}
IG=vendor/fhir/minsalud.fhir.co.rda
JAR=tools/fhir/validator_cli.jar
OFICIALES=build/ihce/oficiales
PERFIL=https://fhir.minsalud.gov.co/rda/StructureDefinition
VALIDAR=(-version 4.0.1 -ig "$IG" -tx n/a)

paso() { printf '\n== %s\n' "$*"; }
rojo() { printf '\nGATE EN ROJO: %s\n' "$*"; exit 1; }

paso "1/5 Aprovisionamiento (huellas de vendor/fhir/VERSIONS.lock)"
if command -v java >/dev/null; then
  tool/ihce/fetch_fhir_tooling.sh || rojo "aprovisionamiento"
else
  tool/ihce/fetch_fhir_tooling.sh --sin-validador || rojo "aprovisionamiento"
fi

paso "2/5 Pruebas (suite completa; T01–T24 sin red)"
"$FLUTTER" test || rojo "pruebas"

paso "3/5 Capa 1 — JSON Schema FHIR R4 (Bundles del gate y ejemplos oficiales)"
# Las pruebas ya la ejecutan; aquí se regeneran los Bundles del gate con
# fechas relativas a hoy y se repite el control del propio gate (T20).
"$FLUTTER" test test/ihce/gate_bundles_test.dart test/ihce/gate_test.dart ||
  rojo "capa 1"
ls build/ihce/bundles/*.json >/dev/null 2>&1 || rojo "no hay Bundles del gate"

paso "4/5 Capa 2 — validador HL7 (perfiles de la guía)"
if ! command -v java >/dev/null || [ ! -f "$JAR" ]; then
  echo "PENDIENTE: sin JRE o sin $JAR. La capa 2 queda cableada, NO superada."
  capa2=pendiente
else
  # Artefactos oficiales (evidencia de la línea base), con el mismo comando.
  # Se cachean por huella: solo se revalidan si cambian la guía, el
  # validador o los cuerpos de la colección.
  "$DART" tool/ihce/linea_base.dart extraer >/dev/null || rojo "extracción Postman"
  huella=$( (cat vendor/fhir/VERSIONS.lock; cat "$OFICIALES"/postman-*.json) | sha256sum | cut -c1-64)
  if [ "$(cat "$OFICIALES/.huella" 2>/dev/null)" != "$huella" ]; then
    echo "Validando artefactos oficiales (cuerpos Postman y ejemplos de la guía)…"
    declare -A perfiles=(
      [enviar-rda-consulta-externa]=BundleAmbulatoryRDA
      [enviar-rda-urgencias]=BundleEmergencyRDA
      [enviar-rda-hospitalizacion]=BundleHospitalizationRDA
      [enviar-rda-paciente]=BundlePatientStatementRDA
    )
    for op in "${!perfiles[@]}"; do
      java -jar "$JAR" "$OFICIALES/postman-$op.json" "${VALIDAR[@]}" \
        -profile "$PERFIL/${perfiles[$op]}" \
        -output "$OFICIALES/postman-$op.report.json" \
        >"$OFICIALES/postman-$op.log" 2>&1 || true
      [ -f "$OFICIALES/postman-$op.report.json" ] || rojo "validador sobre postman-$op"
    done
    java -jar "$JAR" vendor/fhir/ejemplos/*.json "${VALIDAR[@]}" \
      -output "$OFICIALES/ejemplos.report.json" >"$OFICIALES/ejemplos.log" 2>&1 || true
    [ -f "$OFICIALES/ejemplos.report.json" ] || rojo "validador sobre los ejemplos"
    echo "$huella" >"$OFICIALES/.huella"
  fi

  # Bundles del gate (configuración de fábrica) contra BundleAmbulatoryRDA.
  rm -f build/ihce/validation-report.json
  java -jar "$JAR" build/ihce/bundles/*.json "${VALIDAR[@]}" \
    -profile "$PERFIL/BundleAmbulatoryRDA" \
    -output build/ihce/validation-report.json >build/ihce/validation.log 2>&1 || true
  [ -f build/ihce/validation-report.json ] || rojo "el validador no produjo reporte"

  # Variantes opcionales (p. ej. D1 «plain»): se reportan, no entran al gate.
  if ls build/ihce/bundles-opcionales/*.json >/dev/null 2>&1; then
    java -jar "$JAR" build/ihce/bundles-opcionales/*.json "${VALIDAR[@]}" \
      -profile "$PERFIL/BundleAmbulatoryRDA" \
      -output build/ihce/validation-report-opcionales.json \
      >build/ihce/validation-opcionales.log 2>&1 || true
  fi

  if "$DART" tool/ihce/linea_base.dart comparar; then
    capa2=verde
  else
    capa2=rojo
  fi
fi

paso "5/5 Regla 10 (interfaz mínima)"
"$DART" tool/ihce/regla10.dart || rojo "regla 10"

paso "Resumen"
echo "Pruebas: verde · Capa 1: verde · Capa 2: $capa2 · Regla 10: verde"
case "$capa2" in
  verde) echo "GATE EN VERDE." ;;
  pendiente) echo "GATE INCOMPLETO: capa 2 pendiente (sin JRE)."; exit 3 ;;
  *) rojo "capa 2 (ver docs/ihce/DESVIACIONES.md)" ;;
esac
