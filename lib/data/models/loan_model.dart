// lib/data/models/loan_model.dart
import 'package:hive/hive.dart';
import 'package:loan_app/domain/entities/payment.dart';
import 'package:uuid/uuid.dart';

part 'loan_model.g.dart';

@HiveType(typeId: 2)
class LoanModel extends HiveObject {
  // === Mantener los mismos índices que tu adapter generado (.g.dart) ===
  @HiveField(0)
  late final String id; // ahora no nulo (se garantiza en el constructor)

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

  // NOTE: el índice 17 en tu adapter era remainingBalance
  @HiveField(17)
  late double remainingBalance;

  // payments en la posición 18 (lo dejamos no nulo en runtime)
  @HiveField(18)
  late List<Payment> payments;

  // paymentDates en la posición 19 (no nulo en runtime)
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
        remainingBalance = remainingBalance ?? (totalAmountToPay ?? amount),
        payments = payments ?? <Payment>[],
        paymentDates = (paymentDates ?? <DateTime>[]).map((d) => DateTime(d.year, d.month, d.day)).toList();

  /// Comprueba si ya está totalmente pagado
  bool get isFullyPaid {
    // Si totalAmountToPay está definido, compararlo con totalPaid
    if (totalAmountToPay != null) {
      return totalPaid >= totalAmountToPay!;
    }
    // Si no, comparar remainingBalance
    return remainingBalance <= 0.0;
  }

  /// Devuelve una versión corta del id (5 dígitos o menos) para UI
  String get shortId {
    // Extrae solo dígitos y toma últimos/primeros según prefieras
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return id.length <= 5 ? id : id.substring(0, 5);
    }
    return digits.length <= 5 ? digits : digits.substring(digits.length - 5);
  }

  /// Registra un pago en el préstamo (actualiza listas y saldos).
  /// No es async: actualiza campos en memoria; si quieres persistir, llama a save() en el LoanModel (HiveObject).
  void registerPayment(Payment payment) {
    // --- Operamos en centavos para evitar errores de punto flotante ---
    // convertir a centavos (int)
    final int paymentCents = (payment.amount * 100).round();

    // convertir totalPaid y remainingBalance actuales a centavos
    final int currentTotalPaidCents = (totalPaid * 100).round();
    final int currentRemainingCents = (remainingBalance * 100).round();

    // nuevo total pagado en centavos
    final int newTotalPaidCents = currentTotalPaidCents + paymentCents;

    // calcular nuevo remaining en centavos y clampeo a 0
    int newRemainingCents = currentRemainingCents - paymentCents;
    if (newRemainingCents < 0) newRemainingCents = 0;

    // asignar de vuelta a double con 2 decimales exactos
    totalPaid = newTotalPaidCents / 100.0;
    remainingBalance = newRemainingCents / 100.0;

    // Añadir el pago a la lista
    payments.add(payment);

    // Si saldo es 0, marcar como pagado
    if (remainingBalance <= 0.0) {
      status = 'pagado';
    }

    // Persistir si el objeto está en Hive (guardar en try/catch para no romper flujos que no esperan IO)
    try {
      save();
    } catch (_) {
      // ignorar si no se puede persistir aquí; caller puede persistir mediante repositorios
    }
  }

  /// Actualiza el estado (y persiste tente si es posible)
  void updateStatus(String newStatus) {
    status = newStatus;
    try {
      save();
    } catch (_) {}
  }

  /// Normaliza paymentDates a 00:00 por seguridad (útil en migraciones)
  void normalizePaymentDatesIfNeeded() {
    paymentDates = paymentDates.map((d) => DateTime(d.year, d.month, d.day)).toList();
  }

  /// Copia con override de campos (útil en ediciones)
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
