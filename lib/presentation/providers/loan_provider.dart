// lib/presentation/providers/loan_provider.dart
import 'package:flutter/material.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/loan_repository_impl.dart'; // Importa la implementación del repositorio
import 'package:loan_app/domain/repositories/i_loan_repository.dart';
/// [LoanProvider] gestiona el estado de los préstamos y las interacciones con el repositorio.
/// Utiliza ChangeNotifier para notificar a los oyentes (widgets de la UI) sobre los cambios.
class LoanProvider extends ChangeNotifier {
  // Instancia del repositorio de préstamos para interactuar con la base de datos.
  final LoanRepository _loanRepository = LoanRepositoryImpl();

  // Lista privada de préstamos. Se actualiza cada vez que hay cambios.
  List<LoanModel> _loans = [];
  List<LoanModel> get loans => _loans; // Getter público para acceder a la lista de préstamos.

  // Indicador de carga para la UI.
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Mensaje de error, si ocurre alguno.
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  LoanProvider() {
    // Al inicializar el proveedor, carga todos los préstamos existentes.
    loadLoans();
  }

  /// Carga todos los préstamos desde el repositorio.
  Future<void> loadLoans() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Notifica a la UI que la carga ha comenzado.

    try {
      _loans = await _loanRepository.getAllLoans();
    } catch (e) {
      _errorMessage = 'Error al cargar los préstamos: $e';
      debugPrint('Error loading loans: $e'); // Para depuración
    } finally {
      _isLoading = false;
      notifyListeners(); // Notifica a la UI que la carga ha terminado (o hubo un error).
    }
  }

  /// Añade un nuevo préstamo y recarga la lista.
  Future<void> addLoan(LoanModel loan) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loanRepository.addLoan(loan);
      await loadLoans(); // Recarga la lista para reflejar el nuevo préstamo.
    } catch (e) {
      _errorMessage = 'Error al añadir el préstamo: $e';
      debugPrint('Error adding loan: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualiza un préstamo existente y recarga la lista.
  Future<void> updateLoan(LoanModel loan) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loanRepository.updateLoan(loan);
      await loadLoans(); // Recarga la lista para reflejar los cambios.
    } catch (e) {
      _errorMessage = 'Error al actualizar el préstamo: $e';
      debugPrint('Error updating loan: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Marca un préstamo como pagado y recarga la lista.
  Future<void> markLoanAsPaid(String loanId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loanRepository.markLoanAsPaid(loanId);
      await loadLoans(); // Recarga la lista para reflejar el cambio de estado.
    } catch (e) {
      _errorMessage = 'Error al marcar el préstamo como pagado: $e';
      debugPrint('Error marking loan as paid: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Elimina un préstamo y recarga la lista.
  Future<void> deleteLoan(String loanId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loanRepository.deleteLoan(loanId);
      await loadLoans(); // Recarga la lista para reflejar la eliminación.
    } catch (e) {
      _errorMessage = 'Error al eliminar el préstamo: $e';
      debugPrint('Error deleting loan: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}