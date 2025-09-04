// lib/data/repositories/loan_repository.dart

import 'package:hive_flutter/hive_flutter.dart';
import 'package:loan_app/data/models/loan_model.dart';

class LoanRepository {
  final Box<LoanModel> _loanBox = Hive.box<LoanModel>('loans');

  // 💡 CAMBIO AQUÍ: El método espera un clientId de tipo String
  Future<List<LoanModel>> getLoansByClientId(String clientId) async {
    return _loanBox.values
        .where((loan) => loan.clientId == clientId)
        .toList();
  }
}