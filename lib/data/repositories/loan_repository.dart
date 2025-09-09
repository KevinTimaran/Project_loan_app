// lib/data/repositories/loan_repository.dart

import 'package:hive_flutter/hive_flutter.dart';
import 'package:loan_app/data/models/loan_model.dart';

class LoanRepository {
  final Box<LoanModel> _loanBox = Hive.box<LoanModel>('loans');

  Future<void> addLoan(LoanModel loan) async {
    await _loanBox.add(loan);
  }

  Future<List<LoanModel>> getLoansByClientId(String clientId) async {
    return _loanBox.values
        .where((loan) => loan.clientId == clientId)
        .toList();
  }

  Future<double> getTotalLoanedAmount() async {
    final allLoans = _loanBox.values.toList();
    // CORREGIDO: Se especifica el tipo `double` en `fold`
    return allLoans.fold<double>(0.0, (sum, item) => sum + item.amount);
  }

  Future<List<LoanModel>> getActiveLoans() async {
    return _loanBox.values.toList();
  }
}