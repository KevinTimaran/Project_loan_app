//#########################################
//# este code sirve para manejar los pagos en la app
//#########################################

import 'package:hive_flutter/hive_flutter.dart';
import 'package:loan_app/domain/entities/payment.dart';

class PaymentRepository {
  static const String _paymentBox = 'payments';

  Future<void> addPayment(Payment payment) async {
    final box = await Hive.openBox<Payment>(_paymentBox);
    await box.put(payment.id, payment);
  }

  Future<List<Payment>> getPaymentsByLoanId(String loanId) async {
    final box = await Hive.openBox<Payment>(_paymentBox);
    return box.values.where((payment) => payment.loanId == loanId).toList();
  }


  Future<List<Payment>> getAllPayments() async {
    final box = await Hive.openBox<Payment>('payments');
    return box.values.toList();
  }

  Future<void> deletePayment(String id) async {
    final box = await Hive.openBox<Payment>(_paymentBox);
    await box.delete(id);
  }

  Future<List<Payment>> getPaymentsByDate(DateTime date) async {
    final box = await Hive.openBox<Payment>(_paymentBox);
    return box.values.where((payment) {
      final paymentDate = payment.date;
      return paymentDate.year == date.year &&
          paymentDate.month == date.month &&
          paymentDate.day == date.day;
    }).toList();
  }

  // AÑADIDO: Método para obtener el monto total de todos los pagos
  Future<double> getTotalPaymentsAmount() async {
    final box = await Hive.openBox<Payment>(_paymentBox);
    double total = 0.0;
    for (var payment in box.values) {
      total += payment.amount;
    }
    return total;
  }
}
