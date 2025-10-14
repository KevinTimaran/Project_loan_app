// lib/presentation/screens/loans/add_loan_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/presentation/providers/loan_provider.dart';
import 'package:intl/intl.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loan_app/domain/entities/client.dart';
import 'package:uuid/uuid.dart';

// Importa la utilidad
import 'package:loan_app/utils/schedule_calculator.dart';

class AddLoanScreen extends StatefulWidget {
  const AddLoanScreen({super.key});

  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _interestRateController = TextEditingController();
  final TextEditingController _termValueController = TextEditingController();
  final TextEditingController _whatsappNumberController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  String _selectedPaymentFrequency = 'Mensual';
  final List<String> _paymentFrequencies = ['Diario', 'Semanal', 'Quincenal', 'Mensual'];

  String _currentTermUnitLabel = 'Meses';

  @override
  void initState() {
    super.initState();
    _updateDueDateBasedOnTerm();
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _amountController.dispose();
    _interestRateController.dispose();
    _termValueController.dispose();
    _whatsappNumberController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _dueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          _updateDueDateBasedOnTerm();
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  void _updateDueDateBasedOnTerm() {
    if (_termValueController.text.isNotEmpty) {
      final int term = int.tryParse(_termValueController.text) ?? 0;
      DateTime calculatedDueDate = _startDate;

      setState(() {
        switch (_selectedPaymentFrequency) {
          case 'Diario':
            calculatedDueDate = _startDate.add(Duration(days: term));
            break;
          case 'Semanal':
            calculatedDueDate = _startDate.add(Duration(days: term * 7));
            break;
          case 'Quincenal':
            calculatedDueDate = _startDate.add(Duration(days: term * 15));
            break;
          case 'Mensual':
          default:
            int year = _startDate.year;
            int month = _startDate.month + term;
            year += (month - 1) ~/ 12;
            month = ((month - 1) % 12) + 1;
            final int day = _startDate.day;
            final int lastDay = DateTime(year, month + 1, 0).day;
            calculatedDueDate = DateTime(year, month, day > lastDay ? lastDay : day);
            break;
        }
        _dueDate = calculatedDueDate;
      });
    }
  }

  void _updateTermUnitLabel(String? frequency) {
    setState(() {
      _selectedPaymentFrequency = frequency ?? _selectedPaymentFrequency;
      switch (_selectedPaymentFrequency) {
        case 'Diario':
          _currentTermUnitLabel = 'Días';
          break;
        case 'Semanal':
          _currentTermUnitLabel = 'Semanas';
          break;
        case 'Quincenal':
          _currentTermUnitLabel = 'Quincenas';
          break;
        case 'Mensual':
        default:
          _currentTermUnitLabel = 'Meses';
          break;
      }
      _updateDueDateBasedOnTerm();
    });
  }

  /// Envoltorio privado que usa la utilidad externa para mantener compat con el resto del código.
  Map<String, dynamic> _generateSchedule({
    required double amount,
    required double annualRatePercent,
    required int term,
    required DateTime startDate,
    required String frequency,
  }) {
    final result = generateSchedule(
      amount: amount,
      annualRatePercent: annualRatePercent,
      term: term,
      startDate: startDate,
      frequency: frequency,
    );

    return {
      'dates': result.dates,
      'installments': result.installments,
      'total': result.total,
    };
  }

  Future<void> _saveLoan() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        final loanProvider = Provider.of<LoanProvider>(context, listen: false);

        // 1. Crear cliente
        final newClient = Client(
          id: const Uuid().v4(),
          name: _clientNameController.text.trim(),
          lastName: '',
          identification: '',
          phone: _phoneNumberController.text.trim(),
          whatsapp: _whatsappNumberController.text.trim(),
        );

        // 2. Guardar cliente
        await loanProvider.addClient(newClient);

        // 3. Parsear monto y tasa
        final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
        final String cleanedAmountText = _amountController.text.replaceAll('\$', '').trim();
        final double parsedAmount = currencyFormatter.parse(cleanedAmountText).toDouble();

        final double annualInterestPercent = double.parse(_interestRateController.text);
        final int term = int.parse(_termValueController.text);

        // 4. Generar schedule (usando la utilidad compartida)
        final schedule = _generateSchedule(
          amount: parsedAmount,
          annualRatePercent: annualInterestPercent,
          term: term,
          startDate: _normalizeDate(_startDate),
          frequency: _selectedPaymentFrequency,
        );

        final List<DateTime> paymentDates = (schedule['dates'] as List<DateTime>)
            .map((d) => _normalizeDate(d))
            .toList();

        final List<double> installmentsD = (schedule['installments'] as List).map((e) => (e as num).toDouble()).toList();

        // convertimos cada cuota a centavos y sumamos para total exacto
        final List<int> installmentsCents = installmentsD.map((d) => (d * 100).round()).toList();
        final int totalToPayCents = installmentsCents.fold<int>(0, (s, c) => s + c);
        final int firstInstallmentCents = installmentsCents.isNotEmpty ? installmentsCents.first : 0;

        final double totalToPay = (totalToPayCents / 100.0);
        final double calculatedPaymentAmount = (firstInstallmentCents / 100.0);

        // 5. Crear LoanModel
        final newLoan = LoanModel(
          id: const Uuid().v4(),
          clientId: newClient.id,
          clientName: newClient.name,
          amount: parsedAmount,
          interestRate: annualInterestPercent / 100,
          termValue: term,
          startDate: _normalizeDate(_startDate),
          dueDate: _normalizeDate(_dueDate),
          status: 'activo',
          paymentFrequency: _selectedPaymentFrequency,
          whatsappNumber: _whatsappNumberController.text.isEmpty ? null : _whatsappNumberController.text.trim(),
          phoneNumber: _phoneNumberController.text.isEmpty ? null : _phoneNumberController.text.trim(),
          termUnit: _currentTermUnitLabel,
          paymentDates: paymentDates,
          calculatedPaymentAmount: double.parse((calculatedPaymentAmount).toStringAsFixed(2)),
          totalAmountToPay: double.parse((totalToPay).toStringAsFixed(2)),
          remainingBalance: double.parse((totalToPay).toStringAsFixed(2)),
          totalPaid: 0.0,
        );

        // 6. Guardar préstamo
        await loanProvider.addLoan(newLoan);

        // 7. Confirmación y volver
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Préstamo y cliente añadidos con éxito!')),
        );
        Navigator.of(context).pop();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al añadir préstamo y cliente: $error')),
        );
      }
    }
  }

  void _showPaymentSimulation(BuildContext context) {
    final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

    final String cleanedAmountText = _amountController.text.replaceAll('\$', '').trim();

    double amount;
    try {
      amount = currencyFormatter.parse(cleanedAmountText).toDouble();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa un monto válido.')),
      );
      return;
    }

    final double annualRate = double.tryParse(_interestRateController.text) ?? 0;
    final int cuotas = int.tryParse(_termValueController.text) ?? 1;
    final DateTime startDate = _startDate;

    if (amount <= 0 || annualRate <= 0 || cuotas <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa valores válidos para la tasa y el número de cuotas.')),
      );
      return;
    }

    double periodRate;
    Duration periodDuration;

    switch (_selectedPaymentFrequency) {
      case 'Diario':
        periodRate = (annualRate / 100) / 365;
        periodDuration = const Duration(days: 1);
        break;
      case 'Semanal':
        periodRate = (annualRate / 100) / 52;
        periodDuration = const Duration(days: 7);
        break;
      case 'Quincenal':
        periodRate = (annualRate / 100) / 24;
        periodDuration = const Duration(days: 15);
        break;
      case 'Mensual':
      default:
        periodRate = (annualRate / 100) / 12;
        periodDuration = const Duration(days: 30);
        break;
    }

    final List<Widget> cuotasCards = [];
    final double capitalFijo = amount / cuotas;
    double saldoPendiente = amount;

    double totalIntereses = 0;
    double totalPagar = 0;

    for (int i = 0; i < cuotas; i++) {
      final double interes = saldoPendiente * periodRate;
      final double total = capitalFijo + interes;
      final DateTime fecha = startDate.add(periodDuration * i);

      totalIntereses += interes;
      totalPagar += total;

      cuotasCards.add(
        Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: ListTile(
            title: Text('Cuota ${i + 1}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Capital: ${currencyFormatter.format(capitalFijo)}'),
                Text('Interés: ${currencyFormatter.format(interes)}'),
                Text('Total a pagar: ${currencyFormatter.format(total)}'),
                Text('Saldo pendiente: ${currencyFormatter.format(saldoPendiente - capitalFijo)}'),
                Text('Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}'),
              ],
            ),
          ),
        ),
      );
      saldoPendiente -= capitalFijo;
    }

    cuotasCards.add(
      Card(
        color: Colors.grey[200],
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: ListTile(
          title: const Text(
            'Resumen del Préstamo',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Capital total: ${currencyFormatter.format(amount)}'),
              Text('Intereses totales: ${currencyFormatter.format(totalIntereses)}'),
              Text(
                'Total a pagar: ${currencyFormatter.format(totalPagar)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text('Simulación de Pagos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...cuotasCards,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Añadir Nuevo Préstamo'),
        backgroundColor: const Color(0xFF1E88E5),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _clientNameController,
                decoration: const InputDecoration(labelText: 'Nombre del Cliente'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa el nombre del cliente';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Monto del Préstamo'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  CurrencyTextInputFormatter.currency(
                    locale: 'es_CO',
                    decimalDigits: 2,
                    symbol: '\$',
                    enableNegative: false,
                  ),
                ],
                validator: (value) {
                  try {
                    final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
                    final String cleanedValue = value?.replaceAll('\$', '').trim() ?? '0';
                    final double parsedAmount = currencyFormatter.parse(cleanedValue).toDouble();
                    if (parsedAmount <= 0) {
                      return 'Por favor, ingresa un monto válido';
                    }
                  } catch (e) {
                    return 'Por favor, ingresa un monto válido';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _interestRateController,
                decoration: const InputDecoration(
                  labelText: 'Tasa de Interés Anual',
                  suffixText: '%',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty || double.tryParse(value) == null || double.parse(value) <= 0) {
                    return 'Por favor, ingresa una tasa válida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPaymentFrequency,
                decoration: const InputDecoration(
                  labelText: 'Frecuencia de Pago',
                  border: OutlineInputBorder(),
                ),
                items: _paymentFrequencies.map((String frequency) {
                  return DropdownMenuItem<String>(
                    value: frequency,
                    child: Text(frequency),
                  );
                }).toList(),
                onChanged: _updateTermUnitLabel,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, selecciona una frecuencia';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _termValueController,
                decoration: InputDecoration(
                  labelText: 'Plazo ($_currentTermUnitLabel)',
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _updateDueDateBasedOnTerm(),
                validator: (value) {
                  if (value == null || value.isEmpty || int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Por favor, ingresa un plazo válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _whatsappNumberController,
                decoration: const InputDecoration(
                  labelText: 'Número de WhatsApp',
                  hintText: 'Ej: +57 3XX YYY ZZZZ',
                  prefixIcon: Icon(FontAwesomeIcons.whatsapp),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneNumberController,
                decoration: const InputDecoration(
                  labelText: 'Número de Teléfono',
                  hintText: 'Ej: +57 3XX YYY ZZZZ',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (BuildContext builderContext) {
                  return ListTile(
                    title: Text('Fecha de Inicio: ${DateFormat('dd/MM/yyyy').format(_startDate)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _selectDate(builderContext, true),
                  );
                },
              ),
              Builder(
                builder: (BuildContext builderContext) {
                  return ListTile(
                    title: Text('Fecha de Vencimiento: ${DateFormat('dd/MM/yyyy').format(_dueDate)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _selectDate(builderContext, false),
                  );
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.calculate),
                  label: const Text('Simular pagos'),
                  onPressed: () {
                    _showPaymentSimulation(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saveLoan,
        backgroundColor: const Color(0xFF43A047),
        child: const Icon(Icons.save),
        tooltip: 'Guardar Préstamo',
      ),
    );
  }
}
