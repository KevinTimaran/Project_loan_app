// lib/domain/repositories/loan_repository.dart
import '../../data/models/loan_model.dart'; // Importa el modelo de préstamo

/// Interfaz abstracta para el repositorio de préstamos.
/// Define los contratos para las operaciones CRUD (Crear, Leer, Actualizar, Eliminar)
/// y otras operaciones específicas de préstamos.
abstract class LoanRepository {
  /// Añade un nuevo préstamo a la base de datos.
  Future<void> addLoan(LoanModel loan);

  /// Obtiene un préstamo específico por su ID.
  Future<LoanModel?> getLoan(String id);

  /// Obtiene una lista de todos los préstamos.
  Future<List<LoanModel>> getAllLoans();

  /// Obtiene una lista de préstamos asociados a un cliente específico.
  Future<List<LoanModel>> getLoansByClientId(String clientId);

  /// Actualiza un préstamo existente en la base de datos.
  Future<void> updateLoan(LoanModel loan);

  /// Elimina un préstamo por su ID.
  Future<void> deleteLoan(String id);

  /// Marca un préstamo como pagado, actualizando su estado.
  Future<void> markLoanAsPaid(String id);
}