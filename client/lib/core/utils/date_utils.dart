const _months = [
  '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

/// Convierte "2026-04-17T19:16:55Z" o "2026-04-17 19:16:55..." → "17 Abr 2026"
String formatDate(String? raw) {
  if (raw == null || raw.length < 10) return '—';
  final datePart = raw.substring(0, 10);
  final parts = datePart.split('-');
  if (parts.length != 3) return datePart;
  final year = parts[0];
  final month = int.tryParse(parts[1]) ?? 0;
  final day = int.tryParse(parts[2]) ?? 0;
  if (month < 1 || month > 12) return datePart;
  return '$day ${_months[month]} $year';
}

/// Formatea solo hora local desde ISO: "19:16"
String formatTime(String? raw) {
  if (raw == null || raw.length < 16) return '';
  final normalized = raw.replaceFirst(' ', 'T');
  try {
    final dt = DateTime.parse(normalized).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  } catch (_) {
    return '';
  }
}

/// Devuelve "17 Abr 2026, 19:16" en hora local
String formatDateTime(String? raw) {
  if (raw == null || raw.length < 10) return '—';
  final date = formatDate(raw);
  final time = formatTime(raw);
  return time.isEmpty ? date : '$date, $time';
}
