// lib/data/models/loan_model.dart
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:loan_app/domain/entities/payment.dart';
import 'package:uuid/uuid.dart';

part 'loan_model.g.dart';

@HiveType(typeId: 2)
class LoanModel {
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
  final int? loanNumber;

  @HiveField(14)
  final double? totalAmountToPay;

  @HiveField(15)
  final double? calculatedPaymentAmount;

  @HiveField(16)
  double totalPaid;

  @HiveField(17)
  double remainingBalance;

  @HiveField(18)
  List<Payment> payments;

  @HiveField(19)
  List<DateTime> paymentDates;

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
    required this.paymentFrequency,
    this.whatsappNumber,
    this.phoneNumber,
    required this.termUnit,
    this.loanNumber,
    this.totalAmountToPay,
    this.calculatedPaymentAmount,
    this.totalPaid = 0.0,
    double? remainingBalance,
    List<Payment>? payments,
    List<DateTime>? paymentDates,
  })  : id = id ?? const Uuid().v4(),
        remainingBalance = remainingBalance ?? (totalAmountToPay ?? amount),
        payments = payments ?? <Payment>[],
        paymentDates = paymentDates ?? <DateTime>[];

  // ✅ MEJORADO: Lógica de isFullyPaid más robusta
  bool get isFullyPaid {
    // Si el status ya es 'pagado', retornar true inmediatamente
    if (status.toLowerCase() == 'pagado') return true;
    
    // Si remainingBalance es muy cercano a cero, considerar pagado
    if (remainingBalance <= 0.01) return true;
    
    // Si totalPaid es igual o mayor al totalAmountToPay (con tolerancia)
    if (totalAmountToPay != null) {
      return totalPaid >= (totalAmountToPay! - 0.01);
    }
    
    // Fallback: comparar con amount original
    return totalPaid >= (amount - 0.01);
  }

  // ✅ NUEVO: Propiedad para verificar si está activo
  bool get isActive => status.toLowerCase() == 'activo';

  String get shortId {
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return id.length <= 5 ? id : id.substring(0, 5);
    return digits.length <= 5 ? digits : digits.substring(digits.length - 5);
  }

  // ✅ MEJORADO: registerPayment con lógica más robusta
  void registerPayment(Payment payment) {
    // Agregar el pago a la lista
    payments.add(payment);
    
    // Actualizar total pagado
    totalPaid += payment.amount;
    
    // ✅ CALCULO CORREGIDO: remainingBalance debe ser totalAmountToPay - totalPaid
    final totalOwed = totalAmountToPay ?? amount;
    remainingBalance = (totalOwed - totalPaid).clamp(0.0, double.infinity);
    
    // ✅ LÓGICA MEJORADA: Marcar como pagado si se cumple
    if (remainingBalance <= 0.01) {
      status = 'pagado';
      remainingBalance = 0.0; // ✅ FORZAR a cero
    }
    
    // ✅ ACTUALIZAR paymentDates: remover la fecha del pago realizado
    _updatePaymentDatesAfterPayment(payment.date);
    
    debugPrint('💰 Pago registrado - TotalPagado: $totalPaid, SaldoRestante: $remainingBalance, Estado: $status');
  }

  // ✅ NUEVO: Método para actualizar paymentDates después de un pago
  void _updatePaymentDatesAfterPayment(DateTime paymentDate) {
    final normalizedPaymentDate = DateTime(paymentDate.year, paymentDate.month, paymentDate.day);
    
    // Remover la fecha del pago realizado de paymentDates
    paymentDates.removeWhere((date) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      return normalizedDate == normalizedPaymentDate;
    });
    
    debugPrint('📅 PaymentDates actualizado: ${paymentDates.length} fechas restantes');
  }

  // ✅ CORREGIDO: updateStatus sin save()
  void updateStatus(String newStatus) {
    status = newStatus;
    // Si se marca como pagado, asegurar que los valores sean consistentes
    if (newStatus.toLowerCase() == 'pagado') {
      final totalOwed = totalAmountToPay ?? amount;
      totalPaid = totalOwed;
      remainingBalance = 0.0;
    }
  }

  void normalizePaymentDates() {
    paymentDates = paymentDates.map((d) => DateTime(d.year, d.month, d.day)).toList();
  }

  // ✅ MEJORADO: Método para verificar si tiene pagos pendientes para una fecha específica
  bool hasPaymentDueOn(DateTime date) {
    // Si está completamente pagado, no tiene pagos pendientes
    if (isFullyPaid) return false;
    
    // Si no está activo, no tiene pagos pendientes
    if (!isActive) return false;
    
    final normalizedDate = DateTime(date.year, date.month, date.day);
    
    // Verificar en paymentDates
    for (final paymentDate in paymentDates) {
      final normalizedPaymentDate = DateTime(paymentDate.year, paymentDate.month, paymentDate.day);
      if (normalizedPaymentDate == normalizedDate) {
        return true;
      }
    }
    
    // Verificar dueDate como fallback (solo si está en el futuro o es hoy)
    if (dueDate != null) {
      final normalizedDueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
      if (normalizedDueDate == normalizedDate) {
        return true;
      }
      
      // ✅ NUEVO: Si la fecha de vencimiento ya pasó, considerar como pago pendiente
      // hasta que se marque como pagado
      if (normalizedDueDate.isBefore(normalizedDate) && remainingBalance > 0.01) {
        return true;
      }
    }
    
    return false;
  }

  // ✅ MEJORADO: Método para obtener el monto debido hoy
  double getAmountDueToday() {
    if (isFullyPaid) return 0.0;
    if (!isActive) return 0.0;
    
    final cuota = calculatedPaymentAmount ?? 0.0;
    
    // Si la cuota es mayor al saldo, cobrar solo el saldo restante
    final amountDue = cuota > remainingBalance ? remainingBalance : cuota;
    
    // ✅ NUEVO: Asegurar que no sea negativo
    return amountDue.clamp(0.0, double.infinity);
  }

  // ✅ NUEVO: Método para verificar si tiene pagos atrasados
  bool get hasOverduePayments {
    if (isFullyPaid) return false;
    
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    
    // Verificar si dueDate ya pasó y todavía tiene saldo
    if (dueDate != null) {
      final normalizedDueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
      if (normalizedDueDate.isBefore(normalizedToday) && remainingBalance > 0.01) {
        return true;
      }
    }
    
    // Verificar paymentDates que ya pasaron
    for (final paymentDate in paymentDates) {
      final normalizedPaymentDate = DateTime(paymentDate.year, paymentDate.month, paymentDate.day);
      if (normalizedPaymentDate.isBefore(normalizedToday)) {
        return true;
      }
    }
    
    return false;
  }

  // ✅ NUEVO: Método para obtener el próximo pago
  DateTime? get nextPaymentDate {
    if (isFullyPaid) return null;
    
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    
    // Buscar la próxima fecha de pago en paymentDates
    DateTime? nextDate;
    for (final paymentDate in paymentDates) {
      final normalizedPaymentDate = DateTime(paymentDate.year, paymentDate.month, paymentDate.day);
      if (normalizedPaymentDate.isAfter(normalizedToday) || 
          normalizedPaymentDate.isAtSameMomentAs(normalizedToday)) {
        if (nextDate == null || normalizedPaymentDate.isBefore(nextDate)) {
          nextDate = normalizedPaymentDate;
        }
      }
    }
    
    return nextDate ?? dueDate;
  }

  LoanModel copyWith({
    String? id,
    String? clientId,
    String? clientName,
    double? amount,
    double? interestRate,
    int? termValue,
    DateTime? startDate,
    DateTime? dueDate,
    String? status,
    String? paymentFrequency,
    String? whatsappNumber,
    String? phoneNumber,
    String? termUnit,
    int? loanNumber,
    double? totalAmountToPay,
    double? calculatedPaymentAmount,
    double? totalPaid,
    double? remainingBalance,
    List<Payment>? payments,
    List<DateTime>? paymentDates,
  }) {
    return LoanModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      amount: amount ?? this.amount,
      interestRate: interestRate ?? this.interestRate,
      termValue: termValue ?? this.termValue,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      paymentFrequency: paymentFrequency ?? this.paymentFrequency,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      termUnit: termUnit ?? this.termUnit,
      loanNumber: loanNumber ?? this.loanNumber,
      totalAmountToPay: totalAmountToPay ?? this.totalAmountToPay,
      calculatedPaymentAmount: calculatedPaymentAmount ?? this.calculatedPaymentAmount,
      totalPaid: totalPaid ?? this.totalPaid,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      payments: payments ?? List<Payment>.from(this.payments),
      paymentDates: paymentDates ?? List<DateTime>.from(this.paymentDates),
    );
  }

  @override
  String toString() {
    return 'LoanModel(id: $id, client: $clientName, status: $status, totalPaid: $totalPaid, remaining: $remainingBalance, isFullyPaid: $isFullyPaid, payments: ${payments.length})';
  }

  // ✅ NUEVO: Método para debug
  Map<String, dynamic> toDebugMap() {
    return {
      'id': id,
      'clientName': clientName,
      'status': status,
      'totalPaid': totalPaid,
      'remainingBalance': remainingBalance,
      'isFullyPaid': isFullyPaid,
      'isActive': isActive,
      'amountDueToday': getAmountDueToday(),
      'paymentDatesCount': paymentDates.length,
      'paymentsCount': payments.length,
      'hasOverduePayments': hasOverduePayments,
      'nextPaymentDate': nextPaymentDate?.toString(),
    };
  }
}