// lib/presentation/providers/loan_calculator_provider.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LoanCalculatorProvider extends ChangeNotifier {
  double _amount = 0.0;
  double _interestRate = 0.0; // Tasa anual en porcentaje (ej. 24)
  int _termValue = 0;
  String _paymentFrequency = 'Mensual';
  String _termUnit = 'Meses';
  final DateTime _startDate = DateTime.now();
  DateTime _dueDate = DateTime.now();

  List<Map<String, dynamic>> _amortizationSchedule = [];

  // Getters para acceder a los datos desde la UI
  double get amount => _amount;
  double get interestRate => _interestRate;
  int get termValue => _termValue;
  String get paymentFrequency => _paymentFrequency;
  String get termUnit => _termUnit;
  DateTime get startDate => _startDate;
  DateTime get dueDate => _dueDate;
  List<Map<String, dynamic>> get amortizationSchedule => _amortizationSchedule;

  // Setters que actualizan el estado y notifican a los listeners
  void setAmount(double value) {
    if (_amount != value) {
      _amount = value;
      _updateAllCalculations();
    }
  }

  void setInterestRate(double value) {
    if (_interestRate != value) {
      _interestRate = value;
      _updateAllCalculations();
    }
  }

  void setTermValue(int value) {
    if (_termValue != value) {
      _termValue = value;
      _updateAllCalculations();
    }
  }

  void setPaymentFrequency(String value) {
    if (_paymentFrequency != value) {
      _paymentFrequency = value;
      _setTermUnitBasedOnFrequency();
      _updateAllCalculations();
    }
  }

  // Lógica interna para actualizar la unidad del plazo según la frecuencia
  void _setTermUnitBasedOnFrequency() {
    switch (_paymentFrequency) {
      case 'Diario':
        _termUnit = 'Días';
        break;
      case 'Semanal':
        _termUnit = 'Semanas';
        break;
      case 'Quincenal':
        _termUnit = 'Quincenas';
        break;
      case 'Mensual':
      default:
        _termUnit = 'Meses';
        break;
    }
    notifyListeners(); // Notifica para actualizar la UI con la nueva _termUnit
  }

  // Helper: suma meses de forma segura (evita overflow de día cuando el mes destino tiene menos días)
  DateTime _addMonthsSafe(DateTime date, int monthsToAdd) {
    int year = date.year;
    int month = date.month + monthsToAdd;
    year += (month - 1) ~/ 12;
    month = ((month - 1) % 12) + 1;
    int day = date.day;
    int lastDayOfMonth = DateTime(year, month + 1, 0).day;
    if (day > lastDayOfMonth) day = lastDayOfMonth;
    return DateTime(year, month, day, date.hour, date.minute, date.second, date.millisecond, date.microsecond);
  }

  // Helper: calcula la fecha de vencimiento
  DateTime _calculateDueDateInternal() {
    final now = _startDate;
    if (_termValue == 0) return now;

    switch (_termUnit) {
      case 'Días':
        return now.add(Duration(days: _termValue));
      case 'Semanas':
        return now.add(Duration(days: _termValue * 7));
      case 'Quincenas':
        return now.add(Duration(days: _termValue * 15));
      case 'Meses':
      default:
        return _addMonthsSafe(now, _termValue);
    }
  }

  // Helper central: genera el schedule con interés simple (trabaja en CENTAVOS)
  List<Map<String, dynamic>> _buildSimpleInterestSchedule() {
    if (_amount <= 0 || _interestRate < 0 || _termValue <= 0) {
      return [];
    }

    final double principal = _amount;
    final double annualRatePercent = _interestRate;
    final int numberOfPayments = _termValue;
    final String frequency = _paymentFrequency;
    final DateTime startDate = _startDate;

    int periodsPerYear;
    if (frequency == 'Diario') periodsPerYear = 365;
    else if (frequency == 'Semanal') periodsPerYear = 52;
    else if (frequency == 'Quincenal') periodsPerYear = 24;
    else periodsPerYear = 12;

    final double annualRate = annualRatePercent / 100.0;
    final double timeInYears = numberOfPayments / periodsPerYear.toDouble(); // Convertir a double para la división

    final int principalCents = (principal * 100).round();
    final int totalInterestCents = (principalCents * annualRate * timeInYears).round();

    final int principalPerPaymentCents = principalCents ~/ numberOfPayments;
    final int interestPerPaymentCents = totalInterestCents ~/ numberOfPayments;
    final int principalRemainder = principalCents - (principalPerPaymentCents * numberOfPayments);
    final int interestRemainder = totalInterestCents - (interestPerPaymentCents * numberOfPayments);

    DateTime current = startDate;
    int remainingCents = principalCents;
    List<Map<String, dynamic>> schedule = [];

    for (int i = 0; i < numberOfPayments; i++) {
      if (frequency == 'Diario') current = current.add(const Duration(days: 1));
      else if (frequency == 'Semanal') current = current.add(const Duration(days: 7));
      else if (frequency == 'Quincenal') current = current.add(const Duration(days: 15));
      else current = _addMonthsSafe(current, 1);

      int principalPortionCents = principalPerPaymentCents;
      int interestPortionCents = interestPerPaymentCents;

      if (i == numberOfPayments - 1) {
        principalPortionCents += principalRemainder;
        interestPortionCents += interestRemainder;
      }

      final int paymentCents = principalPortionCents + interestPortionCents;
      remainingCents = (remainingCents - principalPortionCents).clamp(0, 1 << 62);

      schedule.add({
        'index': i + 1,
        'date': current,
        'paymentCents': paymentCents,
        'interestCents': interestPortionCents,
        'principalCents': principalPortionCents,
        'remainingCents': remainingCents,
      });
    }
    return schedule;
  }

  // Método que orquesta todos los cálculos y notifica a la UI
  void _updateAllCalculations() {
    _amortizationSchedule = _buildSimpleInterestSchedule();
    _dueDate = _calculateDueDateInternal();
    notifyListeners();
  }
}