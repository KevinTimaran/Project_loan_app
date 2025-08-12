// lib/data/models/loan_model.dart
class Loan {
  final String id;
  final double amount;
  final double interestRate;
  final int termMonths;
  final String status;
  final double monthlyPayment;
  final bool isFullyPaid;

  Loan({
    required this.id,
    required this.amount,
    required this.interestRate,
    required this.termMonths,
    required this.status,
    required this.monthlyPayment,
    required this.isFullyPaid,
  });
}