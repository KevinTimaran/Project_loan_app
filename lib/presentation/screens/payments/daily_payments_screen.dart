//#################################################
//#  Pantalla de Cobros del Día                    #
//#  Muestra pagos realizados en la fecha          #
//#  seleccionada (por defecto hoy).               #
//#  Incluye resumen y lista detallada.           #
//#  + ID corta y legible para préstamos           #
//#  + Manejo mejorado de clientes desconocidos    #
//#################################################

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

  // ✅ AÑADIDO: Formateador de moneda y fecha
  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadDailyPayments();
  }

  Future<void> _loadDailyPayments() async {
    setState(() {
      _isLoading = true;
      _dailyPayments = [];
      _clientsMap.clear();
      _loansMap.clear();
      _totalAmountPaid = 0.0;
    });

    try {
      final payments = await _paymentRepository.getPaymentsByDate(_selectedDate);

      final futures = payments.map((payment) async {
        // Cargar préstamo asociado al pago
        final loan = await _loanRepository.getLoanById(payment.loanId);
        _loansMap[payment.loanId] = loan;

        // Si se encontró el préstamo, cargar el cliente asociado
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
    } catch (e) {
      setState(() {
        _isLoading = false;
        // Manejar error de carga
      });
      debugPrint('Error cargando pagos diarios: $e');
    }
  }

  // ✅ CORREGIDO: Usando Builder para obtener el context correcto
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

  // ✅ NUEVO: Generar ID corta y legible para préstamos
  String _getShortLoanId(LoanModel loan) {
    final id = loan.id;
    if (id.isEmpty) return '00000';
    
    // Extraer solo los números del ID
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (digits.isEmpty) return '00000';
    
    // Usar los últimos 4-5 dígitos para una ID más corta
    if (digits.length <= 4) {
      return digits.padLeft(4, '0');
    } else {
      return digits.substring(digits.length - 4);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    // ✅ CORREGIDO: Usando Builder para el GestureDetector
                    Builder(
                      builder: (BuildContext builderContext) {
                        return GestureDetector(
                          onTap: () => _selectDate(builderContext),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                _dateFormatter.format(_selectedDate),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      },
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
                          _currencyFormatter.format(_totalAmountPaid),
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

                          // ✅ MEJORADO: Determinar icono y estado del pago
                          final isFullPayment = loan != null &&
                              loan.calculatedPaymentAmount != null &&
                              (payment.amount - loan.calculatedPaymentAmount!).abs() <= 0.01;
                          final leadingIcon = isFullPayment 
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : const Icon(Icons.circle_outlined, color: Colors.orange);

                          // ✅ MEJORADO: Mostrar ID corta y legible del préstamo
                          final loanIdDisplay = loan != null ? '#${_getShortLoanId(loan)}' : '#Desconocido';

                          // ✅ MEJORADO: Mostrar nombre del cliente o mensaje de no encontrado
                          final clientNameDisplay = client != null 
                              ? '${client.name} ${client.lastName}'.trim() 
                              : (loan?.clientName?.isNotEmpty == true 
                                  ? loan!.clientName! 
                                  : 'Cliente no encontrado');

                          // NUEVO: Mostrar monto del préstamo (si está disponible)
                          final loanAmountDisplay = loan != null
                              ? _currencyFormatter.format(loan.amount)
                              : 'Monto desconocido';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: leadingIcon,
                              title: Text(
                                'Monto: ${_currencyFormatter.format(payment.amount)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Cliente: $clientNameDisplay'),
                                  Text('Préstamo: $loanAmountDisplay'), // <--- Aquí se muestra el monto del préstamo
                                ],
                              ),
                              trailing: Text(
                                DateFormat('hh:mm a').format(payment.date),
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