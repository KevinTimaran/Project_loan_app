// lib/domain/entities/loan.dart

import 'package:loan_app/domain/entities/client.dart';

class Loan {
  final String id;
  final Client client;
  final double amount;
  final double interestRate;
  final int termValue;
  final String termUnit;
  final String paymentFrequency;
  final double totalAmountToPay;
  final double calculatedPaymentAmount;
  final DateTime startDate;
  final DateTime dueDate;

  Loan({
    required this.id,
    required this.client,
    required this.amount,
    required this.interestRate,
    required this.termValue,
    required this.termUnit,
    required this.paymentFrequency,
    required this.totalAmountToPay,
    required this.calculatedPaymentAmount,
    required this.startDate,
    required this.dueDate,
  });
}