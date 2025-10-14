// lib/utils/loan_calculator.dart
import 'package:flutter/foundation.dart';

/// Genera fechas y montos de cuotas usando capital fijo + interés sobre saldo.
/// Trabaja en **centavos** internamente para evitar errores por coma flotante.
///
/// Retorna un Map con:
/// - 'dates' -> List<DateTime>
/// - 'installments' -> List<double> (pesos, con centavos)
/// - 'total' -> double (total a pagar)
Map<String, dynamic> generateSchedule({
  required double amount,
  required double annualRatePercent,
  required int term,
  required DateTime startDate,
  required String frequency, // 'Diario','Semanal','Quincenal','Mensual'
}) {
  final List<DateTime> dates = <DateTime>[];
  final List<double> installments = <double>[];

  if (term <= 0 || amount <= 0) {
    return {'dates': dates, 'installments': installments, 'total': 0.0};
  }

  // Determinar periodRate y periodo aproximado (para fecha)
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

  // Convertimos a centavos
  final int principalCents = (amount * 100).round();

  // Capital fijo por cuota en centavos (división entera) + resto
  final int principalPerPaymentCents = principalCents ~/ term;
  final int principalRemainder = principalCents - (principalPerPaymentCents * term);

  int remainingCents = principalCents;
  int totalToPayCents = 0;

  for (int i = 0; i < term; i++) {
    // calcular fecha de la cuota
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
    final normalizedDate = DateTime(date.year, date.month, date.day);
    dates.add(normalizedDate);

    // interés sobre saldo actual (en centavos)
    final double interestRaw = remainingCents * periodRate;
    final int interestCents = interestRaw.round();

    // principal para esta cuota (distribuir remainder en la última cuota)
    final int principalPortionCents = principalPerPaymentCents + (i == term - 1 ? principalRemainder : 0);

    final int paymentCents = principalPortionCents + interestCents;

    // actualizar totales
    totalToPayCents += paymentCents;
    remainingCents = (remainingCents - principalPortionCents).clamp(0, 1 << 62);

    // guardar cuota como double en pesos
    installments.add(paymentCents / 100.0);
  }

  final double totalToPay = totalToPayCents / 100.0;

  return {'dates': dates, 'installments': installments, 'total': totalToPay};
}
