// lib/presentation/screens/loans/loan_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/presentation/providers/loan_provider.dart';
import 'package:loan_app/presentation/screens/loans/add_loan_screen.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:hive/hive.dart'; // <--- ¡Importa Hive aquí!

/// Pantalla que muestra una lista de todos los préstamos.
class LoanListScreen extends StatelessWidget {
  const LoanListScreen({super.key});

  // Función para borrar todos los préstamos de Hive (para desarrollo/pruebas)
  Future<void> _clearAllLoans(BuildContext context) async {
    final loanBox = await Hive.openBox<LoanModel>('loans');
    await loanBox.clear(); // Borra todos los elementos de la caja 'loans'
    // Recarga los préstamos en el proveedor para que la UI se actualice
    Provider.of<LoanProvider>(context, listen: false).loadLoans();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Todos los préstamos han sido borrados!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = const Color(0xFF212121);
    final Color primaryBlue = const Color(0xFF1E88E5);
    final Color mainGreen = const Color(0xFF43A047);
    final Color alertRed = const Color(0xFFE53935);
    final Color warningOrange = const Color(0xFFFB8C00);
    final Color iconColor = const Color(0xFF424242);
    final Color alternateRowColor = const Color(0xFFFAFAFA);

    final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lista de Préstamos',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          // Botón para añadir un nuevo préstamo
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddLoanScreen()),
              );
            },
          ),
          // Botón para borrar todos los préstamos (¡TEMPORAL PARA PRUEBAS!)
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white), // Icono de borrar todo
            tooltip: 'Borrar Todos los Préstamos (¡Solo pruebas!)',
            onPressed: () {
              // Muestra un diálogo de confirmación antes de borrar TODO
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirmar Borrado General'),
                  content: const Text('¡ADVERTENCIA! ¿Estás seguro de que quieres borrar TODOS los préstamos? Esta acción es irreversible y solo para pruebas.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop(); // Cierra el diálogo
                        _clearAllLoans(context); // Llama a la función para borrar
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: alertRed,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Borrar Todo'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<LoanProvider>(
        builder: (context, loanProvider, child) {
          if (loanProvider.isLoading) {
            return Center(
              child: CircularProgressIndicator(color: primaryBlue),
            );
          }
          if (loanProvider.errorMessage != null) {
            return Center(
              child: Text(
                'Error: ${loanProvider.errorMessage}',
                style: TextStyle(color: alertRed, fontSize: 14, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            );
          }
          if (loanProvider.loans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.money_off, size: 80, color: iconColor.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No hay préstamos registrados.\n¡Agrega el primero!',
                    style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.7)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: loanProvider.loans.length,
            itemBuilder: (context, index) {
              final loan = loanProvider.loans[index];
              final bool isEvenRow = index % 2 == 0;
              final Color rowBackgroundColor = isEvenRow ? Colors.white : alternateRowColor;

              final String clientName = loan.clientId;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: rowBackgroundColor,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Stack(
                  children: [
                    ListTile(
                      leading: Icon(Icons.account_balance_wallet, color: iconColor),
                      title: Text(
                        'Cliente: $clientName',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monto: ${currencyFormatter.format(loan.amount)}',
                            style: TextStyle(fontSize: 14, color: textColor),
                          ),
                          Text(
                            'Tasa: ${(loan.interestRate * 100).toStringAsFixed(2)}%',
                            style: TextStyle(fontSize: 14, color: textColor),
                          ),
                          Text(
                            'Plazo: ${loan.termMonths} meses',
                            style: TextStyle(fontSize: 14, color: textColor),
                          ),
                          Text(
                            'Estado: ${loan.status.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: loan.isFullyPaid
                                  ? mainGreen
                                  : (loan.status == 'atrasado'
                                      ? alertRed
                                      : warningOrange),
                            ),
                          ),
                          Text(
                            'Pago Mensual: ${currencyFormatter.format(loan.monthlyPayment)}',
                            style: TextStyle(fontSize: 14, color: textColor),
                          ),
                          Text(
                            'Vencimiento: ${DateFormat('dd/MM/yyyy').format(loan.dueDate)}',
                            style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.7)),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!loan.isFullyPaid)
                            IconButton(
                              icon: Icon(Icons.check_circle, color: mainGreen),
                              tooltip: 'Marcar como Pagado',
                              onPressed: () {
                                loanProvider.markLoanAsPaid(loan.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Préstamo ${loan.id} marcado como pagado.',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    backgroundColor: mainGreen,
                                  ),
                                );
                              },
                            ),
                          IconButton(
                            icon: Icon(Icons.delete, color: alertRed),
                            tooltip: 'Eliminar Préstamo',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text(
                                    'Confirmar Eliminación',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  content: const Text(
                                    '¿Estás seguro de que deseas eliminar este préstamo? Esta acción es irreversible.',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(),
                                      child: Text('Cancelar', style: TextStyle(color: primaryBlue)),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        loanProvider.deleteLoan(loan.id);
                                        Navigator.of(ctx).pop();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Préstamo ${loan.id} eliminado.',
                                              style: TextStyle(color: Colors.white),
                                            ),
                                            backgroundColor: alertRed,
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: alertRed,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                                      ),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Tocado: Préstamo ${loan.id}',
                              style: TextStyle(color: Colors.white),
                            ),
                            backgroundColor: primaryBlue,
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'ID: ${loan.id}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddLoanScreen()),
          );
        },
        backgroundColor: mainGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        child: const Icon(Icons.add, size: 28),
        tooltip: 'Añadir Nuevo Préstamo',
      ),
    );
  }
}