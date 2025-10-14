// lib/utils/schedule_calculator.dart
/// Utilidad para generar schedule de pagos (trabaja en centavos internamente).
/// Exporta `generateSchedule` y la clase `ScheduleResult`.

class ScheduleResult {
  final List<DateTime> dates;
  final List<double> installments;
  final double total;

  ScheduleResult({
    required this.dates,
    required this.installments,
    required this.total,
  });
}

/// Genera un schedule de pagos usando cálculo por centavos.
/// - amount: monto en pesos (ej: 1000.50)
/// - annualRatePercent:  (ej: 12.0 para 12% anual)
/// - term: número de cuotas (int)
/// - startDate: fecha de inicio
/// - frequency: 'Diario','Semanal','Quincenal','Mensual'
ScheduleResult generateSchedule({
  required double amount,
  required double annualRatePercent,
  required int term,
  required DateTime startDate,
  required String frequency,
}) {
  if (term <= 0) {
    return ScheduleResult(dates: [], installments: [], total: 0.0);
  }

  // Determinar tasa por periodo
  double periodRate;
  Duration periodDuration;

  switch (frequency.toLowerCase()) {
    case 'diario':
      periodRate = (annualRatePercent / 100) / 365;
      periodDuration = const Duration(days: 1);
      break;
    case 'semanal':
      periodRate = (annualRatePercent / 100) / 52;
      periodDuration = const Duration(days: 7);
      break;
    case 'quincenal':
      periodRate = (annualRatePercent / 100) / 24;
      periodDuration = const Duration(days: 15);
      break;
    case 'mensual':
    default:
      periodRate = (annualRatePercent / 100) / 12;
      periodDuration = const Duration(days: 30);
      break;
  }

  // Trabajar en centavos para evitar drift de punto flotante
  final int principalCents = (amount * 100).round();
  final int principalPerPaymentCents = principalCents ~/ term;
  final int principalRemainder = principalCents - (principalPerPaymentCents * term);

  int remainingCents = principalCents;
  int totalToPayCents = 0;

  final List<DateTime> dates = [];
  final List<double> installments = [];

  for (int i = 0; i < term; i++) {
    // calcular fecha de cuota
    DateTime date;
    if (frequency.toLowerCase() == 'mensual') {
      int year = startDate.year;
      int month = startDate.month + i;
      year += (month - 1) ~/ 12;
      month = ((month - 1) % 12) + 1;
      int day = startDate.day;
      final int lastDay = DateTime(year, month + 1, 0).day;
      if (day > lastDay) day = lastDay;
      date = DateTime(year, month, day);
    } else {
      date = startDate.add(periodDuration * i);
    }

    // normalizar fecha (sin hora)
    final normalizedDate = DateTime(date.year, date.month, date.day);
    dates.add(normalizedDate);

    // interés sobre saldo actual (en centavos)
    final double interestRaw = remainingCents * periodRate;
    final int interestCents = interestRaw.round();

    // principal para esta cuota (distribuir remainder en la última cuota)
    final int principalPortionCents = principalPerPaymentCents + (i == term - 1 ? principalRemainder : 0);

    final int paymentCents = principalPortionCents + interestCents;

    totalToPayCents += paymentCents;
    remainingCents = (remainingCents - principalPortionCents).clamp(0, 1 << 62);

    installments.add(paymentCents / 100.0);
  }

  final double totalToPay = totalToPayCents / 100.0;

  return ScheduleResult(
    dates: dates,
    installments: installments.map((d) => double.parse(d.toStringAsFixed(2))).toList(),
    total: double.parse(totalToPay.toStringAsFixed(2)),
  );
}
