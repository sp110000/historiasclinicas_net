#!/usr/bin/env bash
# Compila la versión para publicar en build/web: sin CDN y con el service
# worker que deja la app funcionando sin conexión. Los argumentos se pasan a
# `flutter build web` (por ejemplo, --base-href /historias/), salvo:
#   --csp-en-html   copia la Content-Security-Policy dentro de index.html,
#                   para hostings sin cabeceras propias (GitHub Pages).
#   --salida DIR    compila en DIR en lugar de build/web (por ejemplo, la
#                   versión del consultorio con CONSULTORIO_ENABLED=true).
set -euo pipefail
cd "$(dirname "$0")/.."
csp_en_html=0
salida=build/web
argumentos=()
siguiente_es_salida=0
for a in "$@"; do
  if [ "$siguiente_es_salida" = 1 ]; then
    salida="$a"
    siguiente_es_salida=0
  elif [ "$a" = "--salida" ]; then
    siguiente_es_salida=1
  elif [ "$a" = "--csp-en-html" ]; then
    csp_en_html=1
  else
    argumentos+=("$a")
  fi
done
case "$salida" in
  /*) salida_absoluta="$salida" ;;
  *) salida_absoluta="$(pwd)/$salida" ;;
esac
flutter build web --release --no-web-resources-cdn --output "$salida_absoluta" \
  ${argumentos[@]+"${argumentos[@]}"}
# Módulo IHCE/RDA apagado (por defecto): sus datos no se publican.
dart run tool/pwa/datos_ihce.dart "$salida" ${argumentos[@]+"${argumentos[@]}"}
if [ "$csp_en_html" = 1 ]; then
  dart run tool/pwa/csp_en_html.dart "$salida"
fi
dart run tool/pwa/generar_service_worker.dart "$salida"
