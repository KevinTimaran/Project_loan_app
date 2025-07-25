// lib/presentation/screens/loan/loan_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/presentation/providers/loan_provider.dart';
import 'package:loan_app/presentation/screens/loans/loan_form_screen.dart'; // Para añadir nuevos préstamos

/// Pantalla que muestra una lista de todos los préstamos.
class LoanListScreen extends StatelessWidget {
  const LoanListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Usa Consumer para escuchar los cambios en LoanProvider.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Préstamos'),
        actions: [
          // Botón para añadir un nuevo préstamo.
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Navega a la pantalla para añadir un préstamo.
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddLoanScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<LoanProvider>(
        builder: (context, loanProvider, child) {
          // Muestra un indicador de carga si los datos están siendo cargados.
          if (loanProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          // Muestra un mensaje de error si ocurrió uno.
          if (loanProvider.errorMessage != null) {
            return Center(
              child: Text(
                'Error: ${loanProvider.errorMessage}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          // Muestra un mensaje si no hay préstamos.
          if (loanProvider.loans.isEmpty) {
            return const Center(child: Text('No hay préstamos registrados.'));
          }

          // Construye la lista de préstamos.
          return ListView.builder(
            itemCount: loanProvider.loans.length,
            itemBuilder: (context, index) {
              final loan = loanProvider.loans[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text('Préstamo ID: ${loan.id.substring(0, 6)}...'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Monto: \$${loan.amount.toStringAsFixed(2)}'),
                      Text('Tasa: ${(loan.interestRate * 100).toStringAsFixed(2)}%'),
                      Text('Plazo: ${loan.termMonths} meses'),
                      Text('Estado: ${loan.status}',
                        style: TextStyle(
                          color: loan.isFullyPaid ? Colors.green : (loan.status == 'atrasado' ? Colors.red : Colors.orange),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('Pago Mensual: \$${loan.monthlyPayment.toStringAsFixed(2)}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botón para marcar como pagado (si no está ya pagado)
                      if (!loan.isFullyPaid)
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () {
                            loanProvider.markLoanAsPaid(loan.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Préstamo marcado como pagado.')),
                            );
                          },
                        ),
                      // Botón para eliminar préstamo
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          // Mostrar un diálogo de confirmación antes de eliminar
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Confirmar Eliminación'),
                              content: const Text('¿Estás seguro de que quieres eliminar este préstamo?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    loanProvider.deleteLoan(loan.id);
                                    Navigator.of(ctx).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Préstamo eliminado.')),
                                    );
                                  },
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    // Aquí podrías navegar a una pantalla de detalle de préstamo si la creas.
                    // Por ahora, solo muestra un mensaje.
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Detalles del préstamo ${loan.id.substring(0, 6)}...')),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}