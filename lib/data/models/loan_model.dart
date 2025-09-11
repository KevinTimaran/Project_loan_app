// lib/data/models/loan_model.dart

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import 'package:loan_app/domain/entities/payment.dart';

part 'loan_model.g.dart';

@HiveType(typeId: 2)
class LoanModel extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String clientId;
  @HiveField(2)
  final String clientName;
  @HiveField(3)
  final double amount;
  @HiveField(4)
  final double interestRate;
  @HiveField(5)
  final int termValue;
  @HiveField(6)
  final DateTime startDate;
  @HiveField(7)
  final DateTime dueDate;
  @HiveField(8)
  String status;
  @HiveField(9)
  final String paymentFrequency;
  @HiveField(10)
  final String? whatsappNumber;
  @HiveField(11)
  final String? phoneNumber;
  @HiveField(12)
  final String termUnit;
  @HiveField(13)
  final int loanNumber;
  @HiveField(14)
  final double totalAmountToPay;
  @HiveField(15)
  final double calculatedPaymentAmount;
  @HiveField(16) // ⚠️ NUEVO CAMPO
  double totalPaid;
  @HiveField(17) // ⚠️ NUEVO CAMPO
  double remainingBalance;
  @HiveField(18) // ⚠️ NUEVO CAMPO
  List<Payment> payments;

  LoanModel({
    String? id,
    required this.clientId,
    required this.clientName,
    required this.amount,
    required this.interestRate,
    required this.termValue,
    required this.startDate,
    required this.dueDate,
    this.status = 'activo',
    this.paymentFrequency = 'Mensual',
    this.whatsappNumber,
    this.phoneNumber,
    this.termUnit = 'Meses',
    int? loanNumber,
    this.totalPaid = 0.0,
    List<Payment>? payments,
    double? remainingBalance,
  })  : id = id ?? const Uuid().v4(),
        loanNumber = loanNumber ?? (const Uuid().v4().hashCode % 100000).abs(),
        totalAmountToPay = _calculateTotalAmountToPay(
          amount: amount,
          interestRate: interestRate,
          termValue: termValue,
          paymentFrequency: paymentFrequency,
        ),
        calculatedPaymentAmount = _calculatePaymentAmount(
          amount: amount,
          interestRate: interestRate,
          termValue: termValue,
          paymentFrequency: paymentFrequency,
        ),
        payments = payments ?? [],
        remainingBalance = remainingBalance ?? _calculateTotalAmountToPay(
          amount: amount,
          interestRate: interestRate,
          termValue: termValue,
          paymentFrequency: paymentFrequency,
        );

  // Getter para saber si el préstamo está completamente pagado
  bool get isFullyPaid => status == 'pagado';

  static double _calculatePeriodInterestRate({
    required double interestRate,
    required String paymentFrequency,
  }) {
    switch (paymentFrequency) {
      case 'Diario':
        return interestRate / 365;
      case 'Semanal':
        return interestRate / 52;
      case 'Quincenal':
        return interestRate / 24;
      case 'Mensual':
      default:
        return interestRate / 12;
    }
  }

  static double _calculatePaymentAmount({
    required double amount,
    required double interestRate,
    required int termValue,
    required String paymentFrequency,
  }) {
    final double rate = _calculatePeriodInterestRate(
      interestRate: interestRate,
      paymentFrequency: paymentFrequency,
    );
    final int n = termValue;

    if (n == 0) return 0.0;
    if (rate == 0) return amount / n;

    final double numerator = amount * rate * pow(1 + rate, n);
    final double denominator = pow(1 + rate, n) - 1;

    if (denominator == 0) return 0.0;
    return numerator / denominator;
  }

  static double _calculateTotalAmountToPay({
    required double amount,
    required double interestRate,
    required int termValue,
    required String paymentFrequency,
  }) {
    final double paymentAmount = _calculatePaymentAmount(
      amount: amount,
      interestRate: interestRate,
      termValue: termValue,
      paymentFrequency: paymentFrequency,
    );
    return paymentAmount * termValue;
  }

  void updateStatus(String newStatus) {
    status = newStatus;
    save();
  }

  // ⚠️ FUNCIÓN PARA REGISTRAR UN PAGO
  void registerPayment(Payment newPayment) {
    // 1. Añade el pago a la lista
    payments.add(newPayment);

    // 2. Suma el monto pagado
    totalPaid += newPayment.amount;

    // 3. Recalcula el saldo restante
    remainingBalance = totalAmountToPay - totalPaid;

    // 4. Si el saldo es menor o igual a cero, marca el préstamo como pagado
    if (remainingBalance <= 0) {
      status = 'pagado';
    }

    // 5. Guarda los cambios en Hive
    save();
  }
}