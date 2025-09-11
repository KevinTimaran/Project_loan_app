// lib/presentation/screens/loans/loan_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
import 'package:loan_app/presentation/screens/loans/loan_detail_screen.dart';

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
    setState(() {
      _isLoading = true;
    });
    try {
      final loans = await _loanRepository.getLoansByClientId(widget.clientId);
      setState(() {
        _clientLoans = loans;
      });
    } catch (e) {
      debugPrint('Error al cargar los préstamos del cliente: $e');
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
                      child: ListTile(
                        title: Text('Préstamo #${loan.loanNumber} - ${currencyFormatter.format(loan.amount)}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
        onPressed: _loadClientLoans,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}