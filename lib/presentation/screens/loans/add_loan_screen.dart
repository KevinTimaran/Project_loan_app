// lib/presentation/screens/loans/add_loan_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/presentation/providers/loan_provider.dart';
import 'package:intl/intl.dart';
// Importa el formateador de moneda
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/services.dart'; // Necesario para TextInputFormatter

/// Pantalla para añadir un nuevo préstamo.
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
  final TextEditingController _termMonthsController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _clientNameController.dispose();
    _amountController.dispose();
    _interestRateController.dispose();
    _termMonthsController.dispose();
    super.dispose();
  }

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
          if (_termMonthsController.text.isNotEmpty) {
            final int term = int.tryParse(_termMonthsController.text) ?? 0;
            _dueDate = DateTime(_startDate.year, _startDate.month + term, _startDate.day);
          }
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  void _updateDueDateBasedOnTerm() {
    if (_termMonthsController.text.isNotEmpty) {
      final int term = int.tryParse(_termMonthsController.text) ?? 0;
      setState(() {
        _dueDate = DateTime(_startDate.year, _startDate.month + term, _startDate.day);
      });
    }
  }

  void _saveLoan() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Convertir la tasa de interés de porcentaje (ej. 50) a decimal (0.50)
      double interestRateDecimal = double.parse(_interestRateController.text) / 100;

      final newLoan = LoanModel(
        clientId: _clientNameController.text,
        // Limpiar el formato de moneda antes de parsear a double
        amount: double.parse(_amountController.text.replaceAll(RegExp(r'[^\d]+'), '')), // Eliminar todo lo que no sea dígito
        interestRate: interestRateDecimal,
        termMonths: int.parse(_termMonthsController.text),
        startDate: _startDate,
        dueDate: _dueDate,
        status: 'activo',
      );

      Provider.of<LoanProvider>(context, listen: false).addLoan(newLoan).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Préstamo añadido con éxito!')),
        );
        Navigator.of(context).pop();
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al añadir préstamo: $error')),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir Nuevo Préstamo'),
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
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  // CAMBIO: Usamos CurrencyTextInputFormatter.currency()
                  CurrencyTextInputFormatter.currency(
                    locale: 'es_CO', // Configura tu localización para el formato de moneda
                    decimalDigits: 2, // 2 decimales
                    symbol: '\$', // Símbolo de moneda
                    enableNegative: false, // Opcional: no permitir números negativos
                    // Otros parámetros como name, turnOffGrouping, etc., pueden ir aquí
                  ),
                ],
                validator: (value) {
                  // Validación: Limpiar el valor para verificar si es un número válido
                  // Regex mejorada para limpiar antes de parsear, considerando el formato del formatter
                  final cleanValue = value?.replaceAll(RegExp(r'[^\d]+'), ''); // Eliminar todo excepto dígitos
                  if (cleanValue == null || cleanValue.isEmpty || double.tryParse(cleanValue) == null) {
                    return 'Por favor, ingresa un monto válido';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _interestRateController,
                decoration: const InputDecoration(
                  labelText: 'Tasa de Interés Anual',
                  suffixText: '%', // Muestra un sufijo de porcentaje
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty || double.tryParse(value) == null) {
                    return 'Por favor, ingresa una tasa válida';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _termMonthsController,
                decoration: const InputDecoration(labelText: 'Plazo (meses)'),
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
              ListTile(
                title: Text('Fecha de Inicio: ${DateFormat('dd/MM/yyyy').format(_startDate)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, true),
              ),
              ListTile(
                title: Text('Fecha de Vencimiento: ${DateFormat('dd/MM/yyyy').format(_dueDate)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, false),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveLoan,
                child: const Text('Guardar Préstamo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}