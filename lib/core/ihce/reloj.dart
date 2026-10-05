/// Reloj inyectable: las pruebas lo adelantan para expiraciones y backoff.
abstract interface class Reloj {
  DateTime ahora();
}

class RelojSistema implements Reloj {
  const RelojSistema();

  @override
  DateTime ahora() => DateTime.now();
}

class RelojFalso implements Reloj {
  RelojFalso(this._ahora);

  DateTime _ahora;

  @override
  DateTime ahora() => _ahora;

  void avanzar(Duration d) => _ahora = _ahora.add(d);

  void fijar(DateTime t) => _ahora = t;
}
