// lib/presentation/screens/clients/client_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
import 'package:loan_app/presentation/screens/loans/loan_detail_screen.dart';
import 'package:loan_app/presentation/screens/loans/loan_form_screen.dart';

class ClientHistoryScreen extends StatefulWidget {
  final String clientId;

  const ClientHistoryScreen({
    super.key,
    required this.clientId,
  });

  @override
  State<ClientHistoryScreen> createState() => _ClientHistoryScreenState();
}

class _ClientHistoryScreenState extends State<ClientHistoryScreen> {
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
                    final bool isPaid = loan.status == 'pagado';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        title: Text(
                          'Préstamo #${index + 1} - ${currencyFormatter.format(loan.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isPaid ? Colors.grey : Colors.black,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estado: ${loan.status}', 
                              style: TextStyle(
                                color: isPaid ? Colors.green : Colors.orange
                              )
                            ),
                            Text(
                              isPaid 
                                ? 'Monto pagado: ${currencyFormatter.format(loan.totalAmountToPay)}'
                                : 'Saldo: ${currencyFormatter.format(loan.remainingBalance)}'
                            ),
                            Text(
                              isPaid
                                ? 'Fecha de finalización: ${DateFormat('dd/MM/yyyy').format(loan.dueDate)}'
                                : 'Fecha de inicio: ${DateFormat('dd/MM/yyyy').format(loan.startDate)}'
                            ),
                          ],
                        ),
                        trailing: isPaid
                            ? const Icon(Icons.arrow_forward_ios)
                            : Row(
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
                                        _loadClientLoans();
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