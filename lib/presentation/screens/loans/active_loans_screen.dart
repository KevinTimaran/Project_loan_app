// lib/presentation/screens/loans/active_loans_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
      final loans = await _loanRepository.getActiveLoans();
      setState(() {
        _activeLoans = loans;
      });
    } catch (e) {
      debugPrint('Error al cargar los préstamos activos: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                        title: Text('Préstamo #${loan.loanNumber} - ${currencyFormatter.format(loan.amount)}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cliente: ${loan.clientName}'),
                            Text('Estado: ${loan.status}'),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          // Navegar a la pantalla de detalles del préstamo
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