#!/usr/bin/env bash
# Demostración (NO evidencia de línea base) del defecto G-SLICE-RESOURCE de
# BundleAmbulatoryRDA: el slice `Bundle.entry:ProcedureResources` declara
# `resource` de tipo `Resource` sin perfil, con discriminador (type,
# profile). Toda entrada que cumple su propio perfil coincide también con
# ese slice y el validador reporta «Element matches more than one slice».
#
# Toma el cuerpo oficial `enviar-rda-consulta-externa` de la colección
# Postman v1.5, le completa SOLO los dos elementos que su Practitioner omite
# frente a PractitionerRDA (`active` y `qualification`, copiados del Bundle
# sintético del gate) y lo valida con el mismo comando del gate.
#
# Requisitos: tool/ihce/verificar.sh ejecutado antes (cuerpos extraídos y
# Bundles del gate generados), jq y java.
set -euo pipefail
cd "$(dirname "$0")/../.."

ORIGEN=build/ihce/oficiales/postman-enviar-rda-consulta-externa.json
GATE=build/ihce/bundles/consulta-primera-vez.json
DIR=build/ihce/demostracion
mkdir -p "$DIR"

calificacion=$(jq '[.entry[].resource | select(.resourceType == "Practitioner")][0].qualification' "$GATE")
jq --argjson q "$calificacion" '
  .entry |= map(
    if .resource.resourceType == "Practitioner"
    then .resource.active = true | .resource.qualification = $q
    else . end)' "$ORIGEN" >"$DIR/postman-consulta-practitioner-completo.json"

java -jar tools/fhir/validator_cli.jar "$DIR/postman-consulta-practitioner-completo.json" \
  -version 4.0.1 -ig vendor/fhir/minsalud.fhir.co.rda -tx n/a \
  -profile https://fhir.minsalud.gov.co/rda/StructureDefinition/BundleAmbulatoryRDA \
  -output "$DIR/report.json" >"$DIR/log.txt" 2>&1 || true

if jq -e '[.issue[] | select(.details.text | contains("Element matches more than one slice - PractitionerResource, ProcedureResources"))] | length > 0' "$DIR/report.json" >/dev/null; then
  echo "Reproducido: el Practitioner completo del cuerpo oficial coincide con PractitionerResource y ProcedureResources."
else
  echo "No reproducido."
  exit 1
fi
