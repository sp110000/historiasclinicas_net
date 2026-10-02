#!/usr/bin/env bash
# Compila la versión para publicar en build/web: sin CDN y con el service
# worker que deja la app funcionando sin conexión. Los argumentos se pasan a
# `flutter build web` (por ejemplo, --base-href /historias/), salvo:
#   --csp-en-html   copia la Content-Security-Policy dentro de index.html,
#                   para hostings sin cabeceras propias (GitHub Pages).
set -euo pipefail
cd "$(dirname "$0")/.."
csp_en_html=0
argumentos=()
for a in "$@"; do
  if [ "$a" = "--csp-en-html" ]; then csp_en_html=1; else argumentos+=("$a"); fi
done
flutter build web --release --no-web-resources-cdn ${argumentos[@]+"${argumentos[@]}"}
if [ "$csp_en_html" = 1 ]; then
  dart run tool/pwa/csp_en_html.dart build/web
fi
dart run tool/pwa/generar_service_worker.dart build/web
