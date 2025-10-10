// lib/data/models/loan_model.dart
import 'package:hive/hive.dart';
import 'package:loan_app/domain/entities/payment.dart';
import 'package:uuid/uuid.dart';

part 'loan_model.g.dart';

@HiveType(typeId: 2)
class LoanModel extends HiveObject {
  // === Mantener los mismos índices que tu adapter generado (.g.dart) ===
  @HiveField(0)
  late final String id;

  @HiveField(1)
  late final String clientId;

  @HiveField(2)
  late final String clientName;

  @HiveField(3)
  late final double amount;

  @HiveField(4)
  late final double interestRate;

  @HiveField(5)
  late final int termValue;

  @HiveField(6)
  late final DateTime startDate;

  @HiveField(7)
  late final DateTime dueDate;

  @HiveField(8)
  late String status;

  @HiveField(9)
  late final String paymentFrequency;

  @HiveField(10)
  String? whatsappNumber;

  @HiveField(11)
  String? phoneNumber;

  @HiveField(12)
  late final String termUnit;

  @HiveField(13)
  int? loanNumber;

  @HiveField(14)
  double? totalAmountToPay;

  @HiveField(15)
  double? calculatedPaymentAmount;

  @HiveField(16)
  late double totalPaid;

  @HiveField(17)
  late double remainingBalance;

  @HiveField(18)
  late List<Payment> payments;

  @HiveField(19)
  late List<DateTime> paymentDates;

  LoanModel({
    String? id,
    required String clientId,
    required String clientName,
    required double amount,
    required double interestRate,
    required int termValue,
    required DateTime startDate,
    required DateTime dueDate,
    String status = 'activo',
    required String paymentFrequency,
    String? whatsappNumber,
    String? phoneNumber,
    required String termUnit,
    int? loanNumber,
    double? totalAmountToPay,
    double? calculatedPaymentAmount,
    double totalPaid = 0.0,
    double? remainingBalance,
    List<Payment>? payments,
    List<DateTime>? paymentDates,
  })  : id = id == null || id.isEmpty ? const Uuid().v4() : id,
        clientId = clientId,
        clientName = clientName,
        amount = amount,
        interestRate = interestRate,
        termValue = termValue,
        startDate = startDate,
        dueDate = dueDate,
        status = status,
        paymentFrequency = paymentFrequency,
        whatsappNumber = whatsappNumber,
        phoneNumber = phoneNumber,
        termUnit = termUnit,
        loanNumber = loanNumber,
        totalAmountToPay = totalAmountToPay,
        calculatedPaymentAmount = calculatedPaymentAmount,
        totalPaid = totalPaid,
        // ✅ Inicializar remainingBalance con lógica robusta
        remainingBalance = remainingBalance ??
            (totalAmountToPay != null && totalAmountToPay > 0
                ? totalAmountToPay
                : amount),
        payments = payments ?? <Payment>[],
        paymentDates = (paymentDates ?? <DateTime>[]).map((d) => DateTime(d.year, d.month, d.day)).toList();

  /// Comprueba si ya está totalmente pagado (con tolerancia más amplia para residuales)
  bool get isFullyPaid {
    // ✅ MEJORADO: Tolerancia más amplia para residuales pequeños comunes
    return remainingBalance <= 0.50; // Hasta 50 centavos se considera pagado
  }

  /// Devuelve una versión corta del id (5 dígitos numéricos)
  String get shortId {
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '00000';
    return digits.length <= 5 ? digits.padLeft(5, '0') : digits.substring(digits.length - 5);
  }

  /// Registra un pago en el préstamo (actualiza listas y saldos).
  void registerPayment(Payment payment) {
    // ✅ Convertir todo a centavos para precisión exacta
    final int paymentCents = (payment.amount * 100).round();
    final int currentRemainingCents = (remainingBalance * 100).round();

    // Calcular nuevo saldo en centavos
    int newRemainingCents = currentRemainingCents - paymentCents;
    if (newRemainingCents < 0) newRemainingCents = 0;

    // Actualizar montos en pesos (double) con 2 decimales exactos
    remainingBalance = newRemainingCents / 100.0;
    totalPaid += payment.amount;

    // ✅ MEJORADO: Marcar como pagado si el saldo es <= 50 centavos (residuales comunes)
    if (remainingBalance <= 0.50) {
      remainingBalance = 0.0;
      status = 'pagado';
    }

    // Añadir el pago
    payments.add(payment);

    // Persistir en Hive si es posible
    try {
      save();
    } catch (_) {
      // Ignorar si no está en Hive
    }
  }

  void updateStatus(String newStatus) {
    status = newStatus;
    try {
      save();
    } catch (_) {}
  }

  void normalizePaymentDatesIfNeeded() {
    paymentDates = paymentDates.map((d) => DateTime(d.year, d.month, d.day)).toList();
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
      payments: payments ?? this.payments,
      paymentDates: paymentDates ?? this.paymentDates,
    );
  }

  @override
  String toString() {
    return 'LoanModel(id: $id, clientId: $clientId, clientName: $clientName, amount: $amount, remaining: $remainingBalance, payments: ${payments.length}, paymentDates: ${paymentDates.length})';
  }
}