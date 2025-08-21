// lib/data/models/loan_model.dart
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';

part 'loan_model.g.dart';

@HiveType(typeId: 3) // Asegúrate de que este typeId sea único y no usado por otros modelos.
class LoanModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String clientId; // Nombre del cliente

  @HiveField(2)
  late double amount;

  @HiveField(3)
  late double interestRate; // Tasa de interés ANUAL (decimal, ej. 0.05)

  @HiveField(4)
  late int termValue; // Número de unidades de plazo

  @HiveField(5)
  late DateTime startDate;

  @HiveField(6)
  late DateTime dueDate;

  @HiveField(7)
  late String status;

  @HiveField(8)
  late String paymentFrequency; // Frecuencia de pago (ej. 'Diario', 'Semanal', 'Quincenal', 'Mensual')

  @HiveField(9)
  late String? whatsappNumber;

  @HiveField(10)
  late String? phoneNumber;

  @HiveField(11)
  late String termUnit; // Unidad de plazo (ej. 'Días', 'Semanas', 'Quincenas', 'Meses')

  LoanModel({
    String? id,
    required this.clientId,
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
    this.id = id ?? _generateFiveDigitId();
    debugPrint('DEBUG CONSTRUCTOR: LoanModel creado con ID: ${this.id}');
  }

  String _generateFiveDigitId() {
    final random = Random();
    final int randomNumber = random.nextInt(90000) + 10000;
    debugPrint('DEBUG GENERADOR: Generando nuevo ID de 5 dígitos: $randomNumber');
    return randomNumber.toString();
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
    return 'LoanModel(id: $id, clientName: $clientId, amount: $amount, interestRate: $interestRate, termValue: $termValue, termUnit: $termUnit, startDate: $startDate, dueDate: $dueDate, status: $status, frequency: $paymentFrequency, whatsapp: $whatsappNumber, phone: $phoneNumber)';
  }
}