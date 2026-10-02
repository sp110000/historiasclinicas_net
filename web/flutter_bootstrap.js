{{flutter_js}}
{{flutter_build_config}}

// Sin CDN en ejecución: CanvasKit (--no-web-resources-cdn) y las fuentes de
// respaldo del motor (Roboto) se sirven desde el propio sitio.
_flutter.loader.load({
  config: {
    fontFallbackBaseUrl: 'fonts/',
  },
});
