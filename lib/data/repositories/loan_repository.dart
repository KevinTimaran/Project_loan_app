// lib/data/repositories/loan_repository.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:loan_app/data/models/loan_model.dart';

class LoanRepository {
  final String _boxName = 'loans';

  Future<Box<LoanModel>> get _box async => await Hive.openBox<LoanModel>(_boxName);

  Future<void> addLoan(LoanModel loan) async {
    final box = await _box;
    await box.put(loan.id, loan);
  }

  Future<List<LoanModel>> getAllLoans() async {
    final box = await _box;
    return box.values.toList();
  }

  Future<List<LoanModel>> getActiveLoans() async {
    final box = await _box;
    return box.values.where((loan) => loan.status == 'activo').toList();
  }

  Future<List<LoanModel>> getLoansByClientId(String clientId) async {
    final box = await _box;
    return box.values
        .where((loan) => loan.clientId == clientId)
        .toList();
  }

  Future<double> getTotalLoanedAmount() async {
    final box = await _box;
    final allLoans = box.values.toList();
    return allLoans.fold<double>(0.0, (sum, item) => sum + item.amount);
  }

  Future<int> getNextLoanNumber() async {
    final box = await _box;
    if (box.isEmpty) {
      return 1;
    }
    // Asumimos que los préstamos se guardan con un número de préstamo
    final allLoans = box.values.toList();
    allLoans.sort((a, b) => a.loanNumber.compareTo(b.loanNumber));
    return allLoans.last.loanNumber + 1;
  }

  Future<LoanModel?> getLoanById(String id) async {
    final box = await _box;
    return box.get(id);
  }

  Future<void> updateLoan(LoanModel loan) async {
    final box = await _box;
    await box.put(loan.id, loan);
  }

  Future<void> deleteLoan(String id) async {
    final box = await _box;
    await box.delete(id);
  }
}