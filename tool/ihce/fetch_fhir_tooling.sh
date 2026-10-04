#!/usr/bin/env bash
# Aprovisiona los artefactos normativos del RDA (IHCE, Resolución 1888 de
# 2025) y las herramientas del gate FHIR R4. Es idempotente: lo que ya está
# en disco con la huella de vendor/fhir/VERSIONS.lock no se vuelve a bajar.
#
#   tool/ihce/fetch_fhir_tooling.sh               verifica contra el bloqueo
#   tool/ihce/fetch_fhir_tooling.sh --actualizar  baja todo y reescribe el bloqueo
#   tool/ihce/fetch_fhir_tooling.sh --sin-validador  omite el .jar (sin JRE)
#
# El sitio de la guía no responde 404: ante una ruta inexistente entrega su
# página de inicio. Por eso cada descarga se valida por contenido (JSON con
# el resourceType e id pedidos, PDF o ZIP por su firma), nunca por el código
# HTTP. Cualquier discrepancia es un error del script.
#
# Qué se versiona: este script, VERSIONS.lock y assets/ihce/fhir.schema.json
# (especificación FHIR, CC0). Los artefactos de la guía (CC BY-NC-SA 4.0),
# los documentos de MinSalud y el validador quedan fuera de git (.gitignore).
set -euo pipefail
cd "$(dirname "$0")/../.."

GUIA=https://vulcano.ihcecol.gov.co
IG=vendor/fhir/minsalud.fhir.co.rda
R4=vendor/fhir/hl7.fhir.r4.core
EJEMPLOS=vendor/fhir/ejemplos
FUENTES=vendor/fhir/fuentes
TOOLS=tools/fhir
LOCK=vendor/fhir/VERSIONS.lock
SCHEMA=assets/ihce/fhir.schema.json
BUILD=build/ihce

actualizar=0
con_validador=1
for a in "$@"; do
  case "$a" in
    --actualizar) actualizar=1 ;;
    --sin-validador) con_validador=0 ;;
    *) echo "Argumento desconocido: $a" >&2; exit 2 ;;
  esac
done

for herramienta in curl jq sha256sum unzip; do
  command -v "$herramienta" >/dev/null || { echo "Falta $herramienta" >&2; exit 1; }
done

mkdir -p "$IG" "$R4" "$EJEMPLOS" "$FUENTES" "$TOOLS" "$BUILD" "$(dirname "$SCHEMA")"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

falla() { echo "ERROR: $*" >&2; exit 1; }

# Huella bloqueada de una ruta ("" si no está en el bloqueo).
bloqueada() {
  [ -f "$LOCK" ] || { echo ""; return; }
  awk -v r="$1" '!/^#/ && $2 == r { print $1 }' "$LOCK"
}

# Metadato del bloqueo ("# clave: valor").
meta() {
  [ -f "$LOCK" ] || { echo ""; return; }
  sed -n "s/^# $1: //p" "$LOCK" | head -1
}

# ¿El archivo local coincide con el bloqueo? (permite no volver a bajarlo)
vigente() {
  local ruta=$1 esperada
  [ "$actualizar" = 0 ] || return 1
  [ -f "$ruta" ] || return 1
  esperada=$(bloqueada "$ruta")
  [ -n "$esperada" ] || return 1
  [ "$(sha256sum "$ruta" | cut -d' ' -f1)" = "$esperada" ]
}

bajar() { curl -fsSL --retry 3 --retry-delay 2 -o "$2" "$1"; }

# JSON válido con el resourceType e id pedidos.
validar_recurso() {
  local archivo=$1 tipo=$2 id=$3
  jq -e --arg t "$tipo" --arg i "$id" '.resourceType == $t and .id == $i' \
    "$archivo" >/dev/null 2>&1 ||
    falla "$archivo no es el recurso $tipo/$id (¿página de inicio en lugar de 404?)"
}

validar_firma() {
  local archivo=$1 firma=$2
  [ "$(head -c ${#firma} "$archivo")" = "$firma" ] ||
    falla "$archivo no empieza con '$firma'"
}

# ── 1. Identidad de la compilación vigente de la guía ──
bajar "$GUIA/package.manifest.json" "$BUILD/package.manifest.json"
jq -e '.name == "minsalud.fhir.co.rda" and (.fhirVersion | index("4.0.1"))' \
  "$BUILD/package.manifest.json" >/dev/null ||
  falla "package.manifest.json inesperado"
compilacion=$(jq -r .date "$BUILD/package.manifest.json")
version_guia=$(jq -r .version "$BUILD/package.manifest.json")
bajar "$GUIA/control-de-cambios.html" "$BUILD/control-de-cambios.html"
grep -q 'Control de cambios\|control-de-cambios' "$BUILD/control-de-cambios.html" ||
  falla "control-de-cambios.html inesperado"
ultimo_cambio=$(sed -e 's/<[^>]*>/ /g' "$BUILD/control-de-cambios.html" |
  grep -oE '20[0-9]{2}-[0-9]{2}-[0-9]{2}' | sort -r | head -1)
# artifacts.html redirige a /artifacts: se sigue la redirección.
bajar "$GUIA/artifacts.html" "$BUILD/artifacts.html"
grep -q 'StructureDefinition-BundleAmbulatoryRDA' "$BUILD/artifacts.html" ||
  falla "artifacts.html no enumera los perfiles"

if [ "$actualizar" = 0 ] && [ -f "$LOCK" ]; then
  [ "$(meta compilacion_guia)" = "$compilacion" ] ||
    falla "La guía cambió de compilación ($(meta compilacion_guia) → $compilacion). Ejecuta con --actualizar, regenera docs/ihce/PERFILES_RDA.md y repite el gate."
fi

# ── 2. JSON Schema oficial de FHIR R4 (4.0.1, CC0) ──
if ! vigente "$SCHEMA"; then
  bajar https://hl7.org/fhir/R4/fhir.schema.json.zip "$tmp/schema.zip"
  validar_firma "$tmp/schema.zip" PK
  unzip -o -q "$tmp/schema.zip" -d "$tmp/schema"
  jq -e '.discriminator.propertyName == "resourceType" and .definitions.Bundle' \
    "$tmp/schema/fhir.schema.json" >/dev/null || falla "fhir.schema.json inesperado"
  mv "$tmp/schema/fhir.schema.json" "$SCHEMA"
fi
tipos_fhir=$(jq -r '.discriminator.mapping | keys[]' "$SCHEMA")
es_tipo_fhir() { grep -qx "$1" <<<"$tipos_fhir"; }

# CodeSystems de la especificación FHIR R4 (CC0) que el RDA usa sin fijar el
# código en el perfil: razones de sección vacía y estado clínico de alergias.
for cs in list-empty-reason allergyintolerance-clinical; do
  if ! vigente "$R4/CodeSystem-$cs.json"; then
    bajar "https://hl7.org/fhir/R4/codesystem-$cs.json" "$tmp/cs.json"
    validar_recurso "$tmp/cs.json" CodeSystem "$cs"
    mv "$tmp/cs.json" "$R4/CodeSystem-$cs.json"
  fi
done

# ── 3. Artefactos de conformidad y ejemplos, uno por uno ──
refs=$(grep -oE 'href="[A-Za-z]+-[A-Za-z0-9.-]+(\.html)?"' "$BUILD/artifacts.html" |
  sed -e 's/^href="//' -e 's/"$//' -e 's/\.html$//' | sort -u)
n_conformidad=0
n_ejemplos=0
for ref in $refs; do
  tipo=${ref%%-*}
  id=${ref#*-}
  es_tipo_fhir "$tipo" || continue # páginas narrativas (RDA-consulta, …)
  case "$tipo" in
    StructureDefinition | ValueSet | CodeSystem | CapabilityStatement | \
      OperationDefinition | SearchParameter | ConceptMap | NamingSystem)
      destino="$IG/$ref.json"
      n_conformidad=$((n_conformidad + 1))
      ;;
    *)
      destino="$EJEMPLOS/$ref.json"
      n_ejemplos=$((n_ejemplos + 1))
      ;;
  esac
  if ! vigente "$destino"; then
    bajar "$GUIA/$ref.json" "$tmp/artefacto.json"
    validar_recurso "$tmp/artefacto.json" "$tipo" "$id"
    mv "$tmp/artefacto.json" "$destino"
  fi
done
[ "$n_conformidad" -ge 100 ] || falla "Muy pocos artefactos de conformidad ($n_conformidad)"

# Perfiles que derivan de FHIR Core CO: hoy ninguno (se comprueba).
externos=$(jq -r 'select(.resourceType == "StructureDefinition") | .baseDefinition' \
  "$IG"/StructureDefinition-*.json | grep -v '^http://hl7.org/fhir/StructureDefinition/' |
  grep -v '^https://fhir.minsalud.gov.co/rda/' || true)
[ -z "$externos" ] || falla "Perfiles con base externa (descargar de co.fhir.guide/core): $externos"

# ── 4. Documentos oficiales de MinSalud ──
MINSALUD=https://www.minsalud.gov.co
declare -A DOCS=(
  [Resolucion_1888_de_2025.pdf]="$MINSALUD/Normatividad_Nuevo/Resolucion%20No%201888%20de%202025.pdf"
  [Manual_operaciones_IHCE_v1.4.pdf]="$MINSALUD/ihce/Manuales/Manual_de_operaciones_interoperabilidad_IHCE_V_1_4.pdf"
  [Manual_gestion_llaves_IHCE.pdf]="$MINSALUD/sites/rid/Lists/BibliotecaDigital/RIDE/DE/OT/manual-gestion-llaves-ihce.pdf"
  [Especificacion_prescripcion_RDA.pdf]="$MINSALUD/sites/rid/Lists/BibliotecaDigital/RIDE/DE/OT/rda-prescripcion-medicamentos-enfermedadesh-etecnicas.pdf"
  [Documento_Maestro_IHCE.pdf]="$MINSALUD/ihce/Manuales/Documento_Maestro_IHCE.pdf"
)
for nombre in "${!DOCS[@]}"; do
  if ! vigente "$FUENTES/$nombre"; then
    bajar "${DOCS[$nombre]}" "$tmp/doc.pdf"
    validar_firma "$tmp/doc.pdf" %PDF-
    mv "$tmp/doc.pdf" "$FUENTES/$nombre"
  fi
done

# Colección Postman: trae valores de variables (credenciales del sandbox).
# Se guarda solo la huella del ZIP original y una copia saneada, sin esos
# valores. Nunca se imprimen.
POSTMAN_ZIP_URL="$MINSALUD/sites/rid/Lists/BibliotecaDigital/RIDE/DE/OT/Interop-api-minsalud-sandbox-prestadores-%20v1.5.zip"
POSTMAN="$FUENTES/postman_sandbox_prestadores_v1.5.saneada.json"
postman_zip_sha=$(meta postman_zip_sha256)
if [ "$actualizar" = 1 ] || [ ! -f "$POSTMAN" ] || [ -z "$postman_zip_sha" ] ||
  [ "$(sha256sum "$POSTMAN" | cut -d' ' -f1)" != "$(bloqueada "$POSTMAN")" ]; then
  bajar "$POSTMAN_ZIP_URL" "$tmp/postman.zip"
  validar_firma "$tmp/postman.zip" PK
  nuevo_sha=$(sha256sum "$tmp/postman.zip" | cut -d' ' -f1)
  if [ "$actualizar" = 0 ] && [ -n "$postman_zip_sha" ] && [ "$nuevo_sha" != "$postman_zip_sha" ]; then
    falla "La colección Postman cambió. Ejecuta con --actualizar y revisa D1–D3."
  fi
  postman_zip_sha=$nuevo_sha
  unzip -o -q "$tmp/postman.zip" -d "$tmp/postman"
  coleccion=$(find "$tmp/postman" -name '*.json' | head -1)
  [ -n "$coleccion" ] || falla "El ZIP de Postman no trae la colección"
  jq -e '.info.schema | test("postman")' "$coleccion" >/dev/null || falla "Colección Postman inesperada"
  jq '[.variable[]?.value // empty | select(length > 3)] as $s
      | .variable |= map(.value = "")
      | walk(if type == "string" then (reduce $s[] as $v (.; split($v) | join("<REDACTADO>"))) else . end)' \
    "$coleccion" >"$POSTMAN"
fi

# ── 5. Validador oficial de HL7 (requiere JRE) ──
etiqueta=$(meta validador_tag)
if [ "$con_validador" = 1 ]; then
  if [ "$actualizar" = 1 ] || [ -z "$etiqueta" ]; then
    etiqueta=$(curl -fsSI https://github.com/hapifhir/org.hl7.fhir.core/releases/latest/download/validator_cli.jar |
      sed -n 's#^[Ll]ocation: .*/releases/download/\([^/]*\)/.*#\1#p' | tr -d '\r' | head -1)
    [ -n "$etiqueta" ] || falla "No se pudo resolver la etiqueta del validador"
  fi
  if ! vigente "$TOOLS/validator_cli.jar"; then
    bajar "https://github.com/hapifhir/org.hl7.fhir.core/releases/download/$etiqueta/validator_cli.jar" \
      "$tmp/validator_cli.jar"
    validar_firma "$tmp/validator_cli.jar" PK
    mv "$tmp/validator_cli.jar" "$TOOLS/validator_cli.jar"
  fi
fi

# ── 6. Bloqueo ──
nuevo="$tmp/VERSIONS.lock"
{
  echo "# Generado por tool/ihce/fetch_fhir_tooling.sh. Fijado por huella, no por versión (D5)."
  echo "# guia: $GUIA"
  echo "# guia_paquete: minsalud.fhir.co.rda"
  echo "# guia_version_declarada: $version_guia"
  echo "# compilacion_guia: $compilacion"
  echo "# ultimo_cambio_guia: $ultimo_cambio"
  echo "# manual_operaciones: v01.4 (17-04-2026)"
  echo "# coleccion_postman: v1.5 (sandbox prestadores)"
  echo "# postman_zip_sha256: $postman_zip_sha"
  echo "# manual_credenciales: v04 (septiembre de 2026)"
  echo "# fhir_schema: hl7.org/fhir/R4/fhir.schema.json.zip (4.0.1, sin modificar)"
  echo "# validador_tag: $etiqueta"
  echo "# artefactos_conformidad: $n_conformidad"
  echo "# ejemplos: $n_ejemplos"
  {
    sha256sum "$SCHEMA" "$IG"/*.json "$R4"/*.json "$EJEMPLOS"/*.json "$FUENTES"/*
    [ "$con_validador" = 0 ] || [ ! -f "$TOOLS/validator_cli.jar" ] || sha256sum "$TOOLS/validator_cli.jar"
  } | sort -k2
} >"$nuevo"

if [ ! -f "$LOCK" ] || [ "$actualizar" = 1 ]; then
  if [ "$con_validador" = 0 ] && [ -f "$LOCK" ]; then
    grep ' tools/fhir/validator_cli.jar$' "$LOCK" >>"$nuevo" || true
  fi
  mv "$nuevo" "$LOCK"
  echo "Bloqueo escrito en $LOCK. Regenera los derivados:"
  echo "  dart run tool/ihce/generar_perfiles.dart"
else
  filtro='^#'
  [ "$con_validador" = 1 ] || filtro='^#| tools/fhir/validator_cli.jar$'
  if ! diff <(grep -Ev "$filtro" "$LOCK") <(grep -Ev "$filtro" "$nuevo") >"$tmp/diff"; then
    cat "$tmp/diff" >&2
    falla "Las huellas no coinciden con $LOCK. Ejecuta con --actualizar, regenera docs/ihce/PERFILES_RDA.md (dart run tool/ihce/generar_perfiles.dart) y repite el gate."
  fi
  echo "Artefactos verificados contra $LOCK (compilación $compilacion)."
fi
