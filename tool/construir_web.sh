#!/usr/bin/env bash
# Compila la versión para publicar en build/web: sin CDN y con el service
# worker que deja la app funcionando sin conexión. Los argumentos se pasan a
# `flutter build web` (por ejemplo, --base-href /historias/).
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --release --no-web-resources-cdn "$@"
dart run tool/pwa/generar_service_worker.dart build/web
