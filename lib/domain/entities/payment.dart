// lib/domain/entities/payment.dart

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'payment.g.dart';

// 💡 CAMBIO CLAVE AQUÍ: Asegúrate de que este número sea único.
@HiveType(typeId: 4)
class Payment extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String loanId;
  @HiveField(2)
  final double amount;
  @HiveField(3)
  final DateTime date;

  Payment({
    String? id,
    required this.loanId,
    required this.amount,
    required this.date,
  }) : id = id ?? const Uuid().v4();
}