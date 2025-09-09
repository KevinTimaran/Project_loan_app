// lib/presentation/screens/payments/daily_payments_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loan_app/data/repositories/payment_repository.dart';
import 'package:loan_app/domain/entities/payment.dart';

class DailyPaymentsScreen extends StatefulWidget {
  const DailyPaymentsScreen({super.key});

  @override
  State<DailyPaymentsScreen> createState() => _DailyPaymentsScreenState();
}

class _DailyPaymentsScreenState extends State<DailyPaymentsScreen> {
  final PaymentRepository _paymentRepository = PaymentRepository();
  List<Payment> _dailyPayments = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadDailyPayments();
  }

  Future<void> _loadDailyPayments() async {
    setState(() {
      _isLoading = true;
    });

    final payments = await _paymentRepository.getPaymentsByDate(_selectedDate);
    setState(() {
      _dailyPayments = payments;
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

  // AHORA DEVUELVE EL VALOR BOOL
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
    // ESTA LÍNEA FALTABA: Retorna el resultado del diálogo.
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Seleccionar Fecha:', style: TextStyle(fontSize: 16)),
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
                              // Esto funciona ahora porque la función _confirmAndDeletePayment devuelve un valor
                              return await _confirmAndDeletePayment(payment.id);
                            },
                            child: ListTile(
                              leading: const Icon(Icons.money),
                              title: Text(
                                'Monto: ${currencyFormatter.format(payment.amount)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('ID Préstamo: ${payment.loanId.substring(0, 4)}...'),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}