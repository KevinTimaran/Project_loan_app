// lib/data/usecases/generate_payment_dates.dart
DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _addFrequency(DateTime base, String frequency, int count) {
  switch (frequency) {
    case 'daily':
      return base.add(Duration(days: count));
    case 'weekly':
      return base.add(Duration(days: 7 * count));
    case 'biweekly':
      return base.add(Duration(days: 14 * count));
    case 'monthly':
      // DateTime handles month overflow
      return DateTime(base.year, base.month + count, base.day);
    default:
      throw ArgumentError('Frecuencia desconocida: $frequency');
  }
}

/// Genera la lista de fechas de pago (normalizadas a 00:00).
List<DateTime> generatePaymentDates({
  required DateTime disbursementDate,
  required String frequency,
  required int term, // número de cuotas
  bool firstPaymentImmediately = false, // si true -> primera cuota = disbursementDate
}) {
  final start = _normalizeDate(disbursementDate);
  final first = firstPaymentImmediately ? start : _addFrequency(start, frequency, 1);
  final List<DateTime> dates = [];
  for (int i = 0; i < term; i++) {
    final due = _addFrequency(first, frequency, i);
    dates.add(_normalizeDate(due));
  }
  return dates;
}
