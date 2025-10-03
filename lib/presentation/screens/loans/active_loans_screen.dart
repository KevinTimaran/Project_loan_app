import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
import 'package:loan_app/presentation/screens/loans/loan_detail_screen.dart';

class ActiveLoansScreen extends StatefulWidget {
  const ActiveLoansScreen({super.key});

  @override
  State<ActiveLoansScreen> createState() => _ActiveLoansScreenState();
}

class _ActiveLoansScreenState extends State<ActiveLoansScreen> {
  final LoanRepository _loanRepository = LoanRepository();
  List<LoanModel> _activeLoans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveLoans();
  }

  Future<void> _loadActiveLoans() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // ✅ Aseguramos que solo se carguen préstamos con saldo pendiente
      final allLoans = await _loanRepository.getAllLoans();
      final activeLoans = allLoans.where((loan) => loan.remainingBalance > 0).toList();
      
      setState(() {
        _activeLoans = activeLoans;
      });
    } catch (e) {
      debugPrint('Error al cargar los préstamos activos: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ✅ Función para generar un número de 5 dígitos a partir del ID
  String _formatLoanNumber(String id) {
    // Extrae solo los dígitos del ID
    final digitsOnly = id.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (digitsOnly.isEmpty) {
      // Si no hay dígitos, usa el hash del ID
      final hashCode = id.hashCode.abs();
      return (hashCode % 100000).toString().padLeft(5, '0');
    }
    
    // Toma los últimos 5 dígitos
    if (digitsOnly.length >= 5) {
      return digitsOnly.substring(digitsOnly.length - 5);
    } else {
      // Rellena con ceros a la izquierda
      return digitsOnly.padLeft(5, '0');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Préstamos Activos'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeLoans.isEmpty
              ? const Center(
                  child: Text('No hay préstamos activos en este momento.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _activeLoans.length,
                  itemBuilder: (context, index) {
                    final loan = _activeLoans[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ListTile(
                        // ✅ Usa la función para mostrar un número de 5 dígitos
                        title: Text('Préstamo #${_formatLoanNumber(loan.id)} - ${currencyFormatter.format(loan.amount)}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cliente: ${loan.clientName}'),
                            Text('Estado: ${loan.status}'),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LoanDetailScreen(loan: loan),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadActiveLoans,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}