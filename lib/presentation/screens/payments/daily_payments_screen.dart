import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
import 'package:loan_app/data/repositories/payment_repository.dart';
import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/domain/entities/payment.dart';

class DailyPaymentsScreen extends StatefulWidget {
  const DailyPaymentsScreen({super.key});

  @override
  State<DailyPaymentsScreen> createState() => _DailyPaymentsScreenState();
}

class _DailyPaymentsScreenState extends State<DailyPaymentsScreen> {
  final PaymentRepository _paymentRepository = PaymentRepository();
  final ClientRepository _clientRepository = ClientRepository();
  final LoanRepository _loanRepository = LoanRepository();

  List<Payment> _dailyPayments = [];
  Map<String, Client?> _clientsMap = {};
  Map<String, LoanModel?> _loansMap = {};

  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  double _totalAmountPaid = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDailyPayments();
  }

  Future<void> _loadDailyPayments() async {
    setState(() {
      _isLoading = true;
      _dailyPayments = [];
      _clientsMap = {};
      _loansMap = {};
      _totalAmountPaid = 0.0;
    });

    final payments = await _paymentRepository.getPaymentsByDate(_selectedDate);

    final futures = payments.map((payment) async {
      final loan = await _loanRepository.getLoanById(payment.loanId);
      _loansMap[payment.loanId] = loan;

      if (loan != null) {
        final client = await _clientRepository.getClientById(loan.clientId);
        _clientsMap[loan.clientId] = client;
      }
    });

    await Future.wait(futures);

    setState(() {
      _dailyPayments = payments;
      _totalAmountPaid = payments.fold(0.0, (sum, item) => sum + item.amount);
      _isLoading = false;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadDailyPayments();
    }
  }

  Future<bool?> _confirmAndDeletePayment(String paymentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text('¿Estás seguro de que deseas eliminar este pago?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _paymentRepository.deletePayment(paymentId);
      _loadDailyPayments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pago eliminado exitosamente.')),
        );
      }
    }
    return confirmed;
  }

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagos del Día'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Fecha:', style: TextStyle(fontSize: 16)),
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd/MM/yyyy').format(_selectedDate),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem(
                          'Total Recaudado',
                          currencyFormatter.format(_totalAmountPaid),
                          Icons.attach_money,
                        ),
                        _buildSummaryItem(
                          'Pagos',
                          _dailyPayments.length.toString(),
                          Icons.list_alt,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _dailyPayments.isEmpty
                    ? const Center(child: Text('No hay pagos registrados para esta fecha.'))
                    : ListView.builder(
                        itemCount: _dailyPayments.length,
                        itemBuilder: (context, index) {
                          final payment = _dailyPayments[index];
                          final loan = _loansMap[payment.loanId];
                          final client = _clientsMap[loan?.clientId];
                          
                          final isFullPayment = loan != null && payment.amount == loan.calculatedPaymentAmount;
                          final leadingIcon = isFullPayment ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.circle_outlined, color: Colors.orange);

                          return Dismissible(
                            key: Key(payment.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            confirmDismiss: (direction) async {
                              return await _confirmAndDeletePayment(payment.id);
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                leading: leadingIcon,
                                title: Text(
                                  'Monto: ${currencyFormatter.format(payment.amount)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Cliente: ${client?.name ?? 'Desconocido'} - Préstamo: #${loan?.loanNumber ?? 'Desconocido'}',
                                ),
                                trailing: Text(
                                  DateFormat('hh:mm a').format(payment.date),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(title, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}