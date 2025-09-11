// lib/presentation/screens/clients/client_loan_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';

class ClientLoanHistoryScreen extends StatefulWidget {
  final String clientId;
  final String clientName;

  const ClientLoanHistoryScreen({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<ClientLoanHistoryScreen> createState() => _ClientLoanHistoryScreenState();
}

class _ClientLoanHistoryScreenState extends State<ClientLoanHistoryScreen> {
  final LoanRepository _loanRepository = LoanRepository();
  List<LoanModel> _loans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  Future<void> _loadLoans() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final loans = await _loanRepository.getLoansByClientId(widget.clientId);
      setState(() {
        _loans = loans;
      });
    } catch (e) {
      // Puedes manejar errores aquí si es necesario
      debugPrint('Error al cargar los préstamos: $e');
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
        title: Text('Historial de ${widget.clientName}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loans.isEmpty
              ? const Center(
                  child: Text('Este cliente no tiene préstamos registrados.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _loans.length,
                  itemBuilder: (context, index) {
                    final loan = _loans[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ListTile(
                        title: Text('Préstamo #${loan.loanNumber} - ${currencyFormatter.format(loan.amount)}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Término: ${loan.termValue} ${loan.termUnit}'),
                            Text('Fecha de Inicio: ${DateFormat('dd/MM/yyyy').format(loan.startDate)}'),
                            Text('Estado: ${loan.status}'),
                          ],
                        ),
                        trailing: Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          // Aquí puedes navegar a una pantalla de detalles del préstamo si la creas
                          // Por ahora, solo muestra un mensaje
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Navegando a los detalles del préstamo #${loan.loanNumber}...'),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}