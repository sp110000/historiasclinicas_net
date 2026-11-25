import 'cita.dart';

/// Número para `wa.me` desde el teléfono de la ficha: un celular colombiano
/// («300 123 4567», «+57 300…») da «573001234567»; un número con «+» y
/// otro indicativo se usa tal cual. Un fijo o algo ilegible da `null`.
String? numeroWhatsapp(String telefono) {
  final t = telefono.trim();
  final digitos = t.replaceAll(RegExp(r'\D'), '');
  if (digitos.length == 10 && digitos.startsWith('3')) return '57$digitos';
  if (digitos.length == 12 && digitos.startsWith('573')) return digitos;
  if (t.startsWith('+') &&
      !digitos.startsWith('57') &&
      digitos.length >= 8 &&
      digitos.length <= 15) {
    return digitos;
  }
  return null;
}

const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

const _diasSemana = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

/// «viernes 21 de noviembre»
String diaLargo(DateTime f) =>
    '${_diasSemana[f.weekday - 1]} ${f.day} de ${_meses[f.month - 1]}';

/// «8:00 a. m.», «2:30 p. m.», «12:00 p. m.»
String horaCorta(DateTime f) {
  final h = f.hour % 12 == 0 ? 12 : f.hour % 12;
  return '$h:${f.minute.toString().padLeft(2, '0')} '
      '${f.hour < 12 ? 'a. m.' : 'p. m.'}';
}

/// El recordatorio con la plantilla del médico. Solo lleva el nombre, el
/// día, la hora y el lugar: nada de salud ni el tipo de cita (pregunta 43).
String mensajeRecordatorio(
  String plantilla, {
  required String nombre,
  required DateTime inicio,
  required String consultorio,
  required String direccion,
}) {
  final valores = {
    'nombre': nombre.trim(),
    'dia': diaLargo(inicio),
    'día': diaLargo(inicio),
    'hora': horaCorta(inicio),
    'consultorio': consultorio.trim(),
    'direccion': direccion.trim(),
    'dirección': direccion.trim(),
  };
  return plantilla
      .replaceAllMapped(
        RegExp(r'\{(\w+|día|dirección)\}', unicode: true),
        (m) => valores[m.group(1)] ?? m.group(0)!,
      )
      .replaceAll(RegExp(r' ,'), ',')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}

/// `https://wa.me/573001234567?text=…` con el mensaje codificado.
String urlWhatsapp(String numero, String mensaje) =>
    'https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}';

String _dosDigitos(int n) => n.toString().padLeft(2, '0');

String _utc(DateTime f) {
  final u = f.toUtc();
  return '${u.year}${_dosDigitos(u.month)}${_dosDigitos(u.day)}T'
      '${_dosDigitos(u.hour)}${_dosDigitos(u.minute)}${_dosDigitos(u.second)}Z';
}

String _escapar(String t) => t
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll(RegExp(r'\r?\n'), r'\n');

/// Pliega una línea a 75 octetos (RFC 5545, 3.1) sin partir caracteres.
String _plegar(String linea) {
  final partes = <String>[];
  var actual = StringBuffer();
  var octetos = 0;
  for (final r in linea.runes) {
    final c = String.fromCharCode(r);
    final n = r < 0x80
        ? 1
        : r < 0x800
        ? 2
        : r < 0x10000
        ? 3
        : 4;
    final limite = partes.isEmpty ? 75 : 74;
    if (octetos + n > limite) {
      partes.add(actual.toString());
      actual = StringBuffer();
      octetos = 0;
    }
    actual.write(c);
    octetos += n;
  }
  partes.add(actual.toString());
  return partes.join('\r\n ');
}

/// El `.ics` de una cita: solo «Cita médica», la hora y el lugar (pregunta
/// 43). Sin el nombre del paciente, el tipo de cita ni el motivo.
String icsCita(Cita c, {required String lugar, required DateTime ahora}) {
  final lineas = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//historiasclinicas.net//Consultorio//ES',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    'UID:${c.id}@historiasclinicas.net',
    'DTSTAMP:${_utc(ahora)}',
    'DTSTART:${_utc(c.inicio)}',
    'DTEND:${_utc(c.fin)}',
    'SUMMARY:Cita médica',
    if (lugar.trim().isNotEmpty) 'LOCATION:${_escapar(lugar.trim())}',
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  return '${lineas.map(_plegar).join('\r\n')}\r\n';
}

/// «Cita_2026-11-21_0800.ics»
String nombreArchivoIcs(Cita c) =>
    'Cita_${c.inicio.year}-${_dosDigitos(c.inicio.month)}-'
    '${_dosDigitos(c.inicio.day)}_${_dosDigitos(c.inicio.hour)}'
    '${_dosDigitos(c.inicio.minute)}.ics';
