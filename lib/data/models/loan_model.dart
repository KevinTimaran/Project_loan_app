// lib/data/models/loan_model.dart

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:loan_app/domain/entities/payment.dart';
import 'dart:math';

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
  @HiveField(16)
  double totalPaid;
  @HiveField(17)
  double remainingBalance;
  @HiveField(18)
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
    double? totalAmountToPay, // ✅ Now an optional named parameter
    double? calculatedPaymentAmount, // ✅ Now an optional named parameter
    this.totalPaid = 0.0,
    List<Payment>? payments,
    double? remainingBalance,
  })  : id = id ?? const Uuid().v4(),
        loanNumber = loanNumber ?? const Uuid().v4().hashCode.abs() % 100000,
        payments = payments ?? [],
        totalAmountToPay = totalAmountToPay ?? _calculateTotalAmountToPay(
          amount: amount,
          interestRate: interestRate,
          termValue: termValue,
          paymentFrequency: paymentFrequency,
        ),
        calculatedPaymentAmount = calculatedPaymentAmount ?? _calculatePaymentAmount(
          amount: amount,
          interestRate: interestRate,
          termValue: termValue,
          paymentFrequency: paymentFrequency,
        ),
        remainingBalance = remainingBalance ?? totalAmountToPay ?? _calculateTotalAmountToPay(
          amount: amount,
          interestRate: interestRate,
          termValue: termValue,
          paymentFrequency: paymentFrequency,
        );

  // Helper methods to calculate loan details
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
    
    // Simple interest calculation based on your other code
    final double totalInterest = amount * rate * n;
    final double totalPayment = amount + totalInterest;
    return totalPayment / n;
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

  bool get isFullyPaid => status == 'pagado';

  LoanModel copyWith({
    String? id,
    String? clientId,
    String? clientName,
    double? amount,
    double? interestRate,
    int? termValue,
    String? paymentFrequency,
    DateTime? startDate,
    DateTime? dueDate,
    String? status,
    String? whatsappNumber,
    String? phoneNumber,
    String? termUnit,
    int? loanNumber,
    double? totalAmountToPay,
    double? calculatedPaymentAmount,
    double? totalPaid,
    double? remainingBalance,
    List<Payment>? payments,
  }) {
    return LoanModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      amount: amount ?? this.amount,
      interestRate: interestRate ?? this.interestRate,
      termValue: termValue ?? this.termValue,
      paymentFrequency: paymentFrequency ?? this.paymentFrequency,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      termUnit: termUnit ?? this.termUnit,
      loanNumber: loanNumber ?? this.loanNumber,
      totalAmountToPay: totalAmountToPay ?? this.totalAmountToPay,
      calculatedPaymentAmount: calculatedPaymentAmount ?? this.calculatedPaymentAmount,
      totalPaid: totalPaid ?? this.totalPaid,
      payments: payments ?? this.payments,
      remainingBalance: remainingBalance ?? this.remainingBalance,
    );
  }

  void updateStatus(String newStatus) {
    status = newStatus;
    save();
  }

  void registerPayment(Payment newPayment) {
    payments.add(newPayment);
    totalPaid += newPayment.amount;
    remainingBalance = totalAmountToPay - totalPaid;

    if (remainingBalance <= 0) {
      status = 'pagado';
    }

    save();
  }
}