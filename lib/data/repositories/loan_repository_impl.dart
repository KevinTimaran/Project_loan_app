//#########################################
//# este code sirve para manejar los prestamos en la app
//#########################################
import 'package:hive/hive.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/domain/repositories/i_loan_repository.dart';

/// Implementación concreta del [LoanRepository] utilizando Hive para la persistencia de datos.
class LoanRepositoryImpl implements LoanRepository {
  // Define el nombre de la "caja" (box) de Hive donde se almacenarán los préstamos.
  static const String _loanBoxName = 'loans';

  /// Obtiene la "caja" de Hive para los préstamos.
  /// Si la caja no está abierta, la abre.
  Future<Box<LoanModel>> _openBox() async {
    // Verifica si la caja ya está abierta para evitar abrirla múltiples veces.
    if (!Hive.isBoxOpen(_loanBoxName)) {
      return await Hive.openBox<LoanModel>(_loanBoxName);
    }
    return Hive.box<LoanModel>(_loanBoxName);
  }

  @override
  Future<void> addLoan(LoanModel loan) async {
    final box = await _openBox();
    // Añade el préstamo a la caja de Hive.
    await box.put(loan.id, loan);
  }

  @override
  Future<LoanModel?> getLoan(String id) async {
    final box = await _openBox();
    // Obtiene un préstamo por su ID.
    return box.get(id);
  }

  // AÑADIDO: Método para compatibilidad con daily_payments_screen.dart
  @override
  Future<LoanModel?> getLoanById(String id) async {
    return getLoan(id);
  }

  @override
  Future<List<LoanModel>> getAllLoans() async {
    final box = await _openBox();
    // Retorna todos los préstamos como una lista.
    return box.values.toList();
  }

  @override
  Future<List<LoanModel>> getLoansByClientId(String clientId) async {
    final box = await _openBox();
    // Filtra los préstamos por el ID del cliente.
    return box.values.where((loan) => loan.clientId == clientId).toList();
  }

  @override
  Future<void> updateLoan(LoanModel loan) async {
    final box = await _openBox();
    // Actualiza un préstamo existente. Hive sobrescribe si la clave ya existe.
    await box.put(loan.id, loan);
  }

  @override
  Future<void> deleteLoan(String id) async {
    final box = await _openBox();
    // Elimina un préstamo por su ID.
    await box.delete(id);
  }

  @override
  Future<void> markLoanAsPaid(String id) async {
    final box = await _openBox();
    final loan = box.get(id);
    if (loan != null) {
      // Actualiza el estado y guarda el cambio.
      loan.updateStatus('pagado');
      // No es necesario llamar a box.put(loan.id, loan) explícitamente aquí
      // porque loan.save() ya lo hace al ser una instancia de HiveObject.
    }
  }
}