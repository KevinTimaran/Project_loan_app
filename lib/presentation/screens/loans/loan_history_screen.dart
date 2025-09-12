// lib/presentation/screens/loans/loan_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
import 'package:loan_app/presentation/screens/loans/loan_detail_screen.dart';
import 'package:loan_app/presentation/screens/loans/loan_form_screen.dart'; // Importa la pantalla de formulario

class LoanHistoryScreen extends StatefulWidget {
  final String clientId;

  const LoanHistoryScreen({
    super.key,
    required this.clientId,
  });

  @override
  State<LoanHistoryScreen> createState() => _LoanHistoryScreenState();
}

class _LoanHistoryScreenState extends State<LoanHistoryScreen> {
  final LoanRepository _loanRepository = LoanRepository();
  List<LoanModel> _clientLoans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClientLoans();
  }

  Future<void> _loadClientLoans() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final loans = await _loanRepository.getLoansByClientId(widget.clientId);
      if (mounted) {
        setState(() {
          _clientLoans = loans;
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error al cargar los préstamos del cliente: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar los préstamos. Intenta de nuevo.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Préstamos del Cliente'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _clientLoans.isEmpty
              ? const Center(
                  child: Text('Este cliente no tiene préstamos registrados.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _clientLoans.length,
                  itemBuilder: (context, index) {
                    final loan = _clientLoans[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        title: Text(
                          'Préstamo #${index + 1} - ${currencyFormatter.format(loan.amount)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Saldo: ${currencyFormatter.format(loan.remainingBalance)}'),
                            Text('Fecha: ${DateFormat('dd/MM/yyyy').format(loan.startDate)}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LoanFormScreen(loan: loan),
                                  ),
                                );
                                if (result == true) {
                                  _loadClientLoans(); // Recarga la lista si el formulario fue guardado
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_ios),
                          ],
                        ),
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
        onPressed: _loadClientLoans,
        tooltip: 'Refrescar historial',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}