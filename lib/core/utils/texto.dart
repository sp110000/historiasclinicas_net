const _conTilde = 'áàäâÁÀÄÂéèëêÉÈËÊíìïîÍÌÏÎóòöôÓÒÖÔúùüûÚÙÜÛñÑçÇ';
const _sinTilde = 'aaaaAAAAeeeeEEEEiiiiIIIIooooOOOOuuuuUUUUnNcC';

/// Quita tildes, diéresis y la virgulilla de la ñ (`Peña` → `Pena`).
String sinTildes(String texto) {
  final b = StringBuffer();
  for (final c in texto.split('')) {
    final i = _conTilde.indexOf(c);
    b.write(i < 0 ? c : _sinTilde[i]);
  }
  return b.toString();
}
