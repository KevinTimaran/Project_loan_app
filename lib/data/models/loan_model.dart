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

  @HiveField(20)
  List<bool> selectedDays;

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
    List<bool>? selectedDays,
  })  : id = id ?? const Uuid().v4(),
        remainingBalance = remainingBalance ?? (totalAmountToPay ?? amount),
        payments = payments ?? <Payment>[],
        paymentDates = paymentDates ?? <DateTime>[],
        selectedDays = selectedDays ?? List<bool>.filled(7, true);

  // ✅ MEJORADO: Lógica de isFullyPaid más robusta con tolerancia mejorada
  bool get isFullyPaid {
    // Si el status ya es 'pagado', retornar true inmediatamente
    if (status.toLowerCase() == 'pagado') return true;
    
    // ✅ TOLERANCIA MEJORADA: Considerar pagado si el saldo es muy pequeño
    if (remainingBalance <= 0.01) return true;
    
    // Si totalPaid es igual o mayor al totalAmountToPay (con tolerancia)
    if (totalAmountToPay != null) {
      double difference = totalAmountToPay! - totalPaid;
      return difference <= 0.01;
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

  // ✅ MEJORADO: registerPayment con lógica más robusta para eliminar residuos
  void registerPayment(Payment payment) {
    // Agregar el pago a la lista
    payments.add(payment);
    
    // Actualizar total pagado
    totalPaid += payment.amount;
    
    // ✅ LÓGICA MEJORADA: Cálculo más robusto del saldo restante
    final totalOwed = totalAmountToPay ?? amount;
    double newBalance = totalOwed - totalPaid;
    
    // ✅ FORZAR A CERO si el residuo es muy pequeño
    if (newBalance.abs() <= 0.01) {
      newBalance = 0.0;
      status = 'pagado';
      debugPrint('🎉 Préstamo marcado como completamente pagado. Residuo eliminado.');
    }
    
    remainingBalance = newBalance.clamp(0.0, double.infinity);
    
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

  // ✅ NUEVO: Método para forzar cierre del préstamo
  void forceCloseLoan() {
    status = 'pagado';
    remainingBalance = 0.0;
    if (totalAmountToPay != null) {
      totalPaid = totalAmountToPay!;
    } else {
      totalPaid = amount;
    }
    debugPrint('🔒 Préstamo forzado a estado pagado');
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
    final normalizedDueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
    if (normalizedDueDate == normalizedDate) {
      return true;
    }
    
    // ✅ NUEVO: Si la fecha de vencimiento ya pasó, considerar como pago pendiente
    // hasta que se marque como pagado
    if (normalizedDueDate.isBefore(normalizedDate) && remainingBalance > 0.01) {
      return true;
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
    final normalizedDueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
    if (normalizedDueDate.isBefore(normalizedToday) && remainingBalance > 0.01) {
      return true;
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

  // ✅ NUEVO: Método para verificar si el préstamo puede recibir pagos
  bool get canAcceptPayments {
    return isActive && !isFullyPaid && remainingBalance > 0.01;
  }

  // ✅ NUEVO: Método para obtener el progreso del pago (0.0 a 1.0)
  double get paymentProgress {
    final totalOwed = totalAmountToPay ?? amount;
    if (totalOwed <= 0) return 1.0;
    
    final progress = totalPaid / totalOwed;
    return progress.clamp(0.0, 1.0);
  }

  // ✅ NUEVO: Método para validar consistencia de datos
  bool validateConsistency() {
    final totalOwed = totalAmountToPay ?? amount;
    final calculatedBalance = totalOwed - totalPaid;
    final balanceDifference = (remainingBalance - calculatedBalance).abs();
    
    // Permitir pequeñas diferencias por redondeo
    if (balanceDifference > 0.02) {
      debugPrint('⚠️  Advertencia: Inconsistencia en saldo. Calculado: $calculatedBalance, Actual: $remainingBalance');
      return false;
    }
    
    // Validar que si está pagado, el saldo sea cero
    if (status.toLowerCase() == 'pagado' && remainingBalance > 0.01) {
      debugPrint('⚠️  Advertencia: Estado pagado pero saldo restante: $remainingBalance');
      return false;
    }
    
    return true;
  }

  // ✅ NUEVO: Método para corregir inconsistencias automáticamente
  void autoCorrectInconsistencies() {
    final totalOwed = totalAmountToPay ?? amount;
    
    // Si el saldo es muy pequeño pero el estado no es pagado
    if (remainingBalance <= 0.01 && status != 'pagado') {
      forceCloseLoan();
      debugPrint('🔧 Auto-corrección: Préstamo marcado como pagado por saldo mínimo');
      return;
    }
    
    // Si el estado es pagado pero hay saldo, ajustar
    if (status == 'pagado' && remainingBalance > 0.01) {
      remainingBalance = 0.0;
      totalPaid = totalOwed;
      debugPrint('🔧 Auto-corrección: Saldo forzado a cero para préstamo pagado');
      return;
    }
    
    // Recalcular saldo si hay inconsistencia
    final calculatedBalance = totalOwed - totalPaid;
    final balanceDifference = (remainingBalance - calculatedBalance).abs();
    
    if (balanceDifference > 0.02) {
      remainingBalance = calculatedBalance.clamp(0.0, double.infinity);
      debugPrint('🔧 Auto-corrección: Saldo recalculado a $remainingBalance');
    }
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
    List<bool>? selectedDays,
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
      selectedDays: selectedDays ?? this.selectedDays,
    );
  }

  @override
  String toString() {
    return 'LoanModel(id: $id, client: $clientName, status: $status, totalPaid: $totalPaid, remaining: $remainingBalance, isFullyPaid: $isFullyPaid, payments: ${payments.length})';
  }

  // ✅ MEJORADO: Método para debug con más información
  Map<String, dynamic> toDebugMap() {
    return {
      'id': id,
      'clientName': clientName,
      'status': status,
      'totalPaid': totalPaid,
      'remainingBalance': remainingBalance,
      'isFullyPaid': isFullyPaid,
      'isActive': isActive,
      'canAcceptPayments': canAcceptPayments,
      'amountDueToday': getAmountDueToday(),
      'paymentProgress': '${(paymentProgress * 100).toStringAsFixed(1)}%',
      'paymentDatesCount': paymentDates.length,
      'paymentsCount': payments.length,
      'hasOverduePayments': hasOverduePayments,
      'nextPaymentDate': nextPaymentDate?.toString(),
      'dataConsistent': validateConsistency(),
    };
  }
}