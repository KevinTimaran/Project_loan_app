import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
import 'package:loan_app/presentation/screens/loans/loan_view_only_screen.dart';
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

  String _getShortLoanId(LoanModel loan) {
    final id = loan.id;
    if (id.isEmpty) return '00000';

    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '00000';

    if (digits.length <= 5) {
      return digits.padLeft(5, '0');
    } else {
      return digits.substring(digits.length - 5);
    }
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
      debugPrint('Error al cargar los préstamos del cliente: $e');
      if (mounted) {
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

  Future<void> _deleteLoan(LoanModel loan) async {
    final bool confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Estás seguro de que deseas eliminar el préstamo #${_getShortLoanId(loan)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed && mounted) {
      try {
        await _loanRepository.deleteLoan(loan.id);
        debugPrint('✅ Préstamo ${loan.id} eliminado.');
        await _loadClientLoans();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Préstamo #${_getShortLoanId(loan)} eliminado.')),
          );
        }
      } catch (e) {
        debugPrint('❌ Error al eliminar préstamo: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar el préstamo: $e')),
          );
        }
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
                    final bool isOverdue = loan.status == 'mora';

                    Color cardColor;
                    Color statusColor;

                    if (isPaid) {
                      cardColor = Colors.green.shade50;
                      statusColor = Colors.green;
                    } else if (isOverdue) {
                      cardColor = Colors.red.shade50;
                      statusColor = Colors.red;
                    } else {
                      cardColor = Colors.white;
                      statusColor = Colors.blue;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      elevation: 2,
                      color: cardColor,
                      child: InkWell(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => isPaid
                                  ? LoanViewOnlyScreen(loan: loan)
                                  : LoanFormScreen(loan: loan),
                            ),
                          );
                          if (result == true && mounted) {
                            _loadClientLoans();
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              // Leading icon with status dot
                              Stack(
                                children: [
                                  Icon(
                                    isPaid 
                                      ? Icons.check_circle_outline 
                                      : (isOverdue 
                                          ? Icons.warning_amber 
                                          : Icons.account_balance_wallet_outlined),
                                    color: isPaid 
                                      ? Colors.green.shade700 
                                      : (isOverdue 
                                          ? Colors.red.shade700 
                                          : Colors.orange),
                                    size: 32,
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: cardColor,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              // Main content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Préstamo #${_getShortLoanId(loan)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        // Delete button - moved here to save space
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          onPressed: () => _deleteLoan(loan),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 30,
                                            minHeight: 30,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Monto: ${currencyFormatter.format(loan.amount)}',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Estado: ${loan.status}',
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      isPaid
                                          ? 'Pagado: ${currencyFormatter.format(loan.totalAmountToPay)}'
                                          : 'Saldo: ${currencyFormatter.format(loan.remainingBalance)}',
                                    ),
                                    Text(
                                      isPaid
                                          ? 'Finalizado: ${DateFormat('dd/MM/yyyy').format(loan.dueDate)}'
                                          : 'Inicio: ${DateFormat('dd/MM/yyyy').format(loan.startDate)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Arrow icon
                              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
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