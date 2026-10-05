import 'package:web/web.dart' as web;

Stream<void> conexionRecuperada() =>
    web.EventStreamProviders.onlineEvent.forTarget(web.window).map((_) {});
