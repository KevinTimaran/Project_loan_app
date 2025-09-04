// lib/data/models/loan_model.dart
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';

part 'loan_model.g.dart';

@HiveType(typeId: 3)
class LoanModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String clientId; // ID único del cliente

  @HiveField(2)
  late String clientName; // NUEVO: Nombre del cliente para mostrar

  @HiveField(3)
  late double amount;

  @HiveField(4)
  late double interestRate;

  @HiveField(5)
  late int termValue;

  @HiveField(6)
  late DateTime startDate;

  @HiveField(7)
  late DateTime dueDate;

  @HiveField(8)
  late String status;

  @HiveField(9)
  late String paymentFrequency;

  @HiveField(10)
  late String? whatsappNumber;

  @HiveField(11)
  late String? phoneNumber;

  @HiveField(12)
  late String termUnit;

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
  }) {
    // 💡 Corrección: Usar Uuid().v4() para garantizar un ID único y evitar colisiones.
    this.id = id ?? const Uuid().v4();
    debugPrint('DEBUG CONSTRUCTOR: LoanModel creado con ID: ${this.id}');
  }

  double get _periodInterestRate {
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

  int get _numberOfPayments {
    return termValue;
  }

  double get calculatedPaymentAmount {
    if (_numberOfPayments == 0) return 0.0;
    if (interestRate == 0) {
      return amount / _numberOfPayments;
    }

    final double rate = _periodInterestRate;
    final int n = _numberOfPayments;

    if (rate == 0) {
      return amount / n;
    }

    final double numerator = amount * rate * pow(1 + rate, n);
    final double denominator = pow(1 + rate, n) - 1;

    if (denominator == 0) return 0.0;

    return numerator / denominator;
  }

  double get monthlyPayment {
    return calculatedPaymentAmount;
  }

  double get totalAmountDue {
    return calculatedPaymentAmount * _numberOfPayments;
  }

  bool get isFullyPaid => status == 'pagado';

  void updateStatus(String newStatus) {
    status = newStatus;
    save();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'clientName': clientName,
      'amount': amount,
      'interestRate': interestRate,
      'termValue': termValue,
      'startDate': startDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'status': status,
      'paymentFrequency': paymentFrequency,
      'whatsappNumber': whatsappNumber,
      'phoneNumber': phoneNumber,
      'termUnit': termUnit,
      'calculatedPaymentAmount': calculatedPaymentAmount,
      'totalAmountDue': totalAmountDue,
    };
  }

  @override
  String toString() {
    return 'LoanModel(id: $id, clientId: $clientId, clientName: $clientName, amount: $amount, interestRate: $interestRate, termValue: $termValue, termUnit: $termUnit, startDate: $startDate, dueDate: $dueDate, status: $status, frequency: $paymentFrequency, whatsapp: $whatsappNumber, phone: $phoneNumber)';
  }
}