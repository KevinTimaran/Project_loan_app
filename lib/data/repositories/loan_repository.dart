import 'package:hive_flutter/hive_flutter.dart';
import 'package:loan_app/data/models/loan_model.dart';

class LoanRepository {
  final String _boxName = 'loans';

  Future<Box<LoanModel>> get _box async => await Hive.openBox<LoanModel>(_boxName);

  Future<void> addLoan(LoanModel loan) async {
    final box = await _box;
    await box.put(loan.id, loan);
    await box.flush();
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
    return box.values.where((loan) => loan.clientId == clientId).toList();
  }

  Future<double> getTotalLoanedAmount() async {
    final box = await _box;
    return box.values.fold<double>(0.0, (sum, item) => sum + item.amount);
  }

  Future<LoanModel?> getLoanById(String id) async {
    final box = await _box;
    return box.get(id);
  }

  Future<void> updateLoan(LoanModel loan) async {
    final box = await _box;
    await box.put(loan.id, loan);

    try {
      await box.flush();
    } catch (_) {}

    print(
      'Repo.updateLoan called: id=${loan.id}, remaining=${loan.remainingBalance}, payments=${loan.payments?.length}',
    );
  }

  Future<void> deleteLoan(String id) async {
    final box = await _box;
    await box.delete(id);
  }
}
