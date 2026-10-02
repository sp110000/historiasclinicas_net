String _dos(int n) => n.toString().padLeft(2, '0');

/// `02/10/2026`
String formatoFecha(DateTime f) => '${_dos(f.day)}/${_dos(f.month)}/${f.year}';

/// `02/10/2026 09:14`
String formatoFechaHora(DateTime f) =>
    '${formatoFecha(f)} ${_dos(f.hour)}:${_dos(f.minute)}';
