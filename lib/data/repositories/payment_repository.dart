// lib/data/repositories/payment_repository.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:loan_app/domain/entities/payment.dart';

class PaymentRepository {
  final Box<Payment> _paymentBox = Hive.box<Payment>('payments');

  Future<void> addPayment(Payment payment) async {
    await _paymentBox.add(payment);
  }

  // Se añadió la función para obtener pagos por ID de préstamo
  Future<List<Payment>> getPaymentsByLoanId(String loanId) async {
    return _paymentBox.values
        .where((payment) => payment.loanId == loanId)
        .toList();
  }
}