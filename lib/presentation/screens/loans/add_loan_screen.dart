import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/presentation/providers/loan_provider.dart';
import 'package:intl/intl.dart';

/// Pantalla para añadir un nuevo préstamo.
class AddLoanScreen extends StatefulWidget {
  const AddLoanScreen({super.key});

  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _clientNameController = TextEditingController(); // Ahora para el nombre
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

      final newLoan = LoanModel(
        clientId: _clientNameController.text, // El nombre del cliente va a clientId
        amount: double.parse(_amountController.text),
        interestRate: double.parse(_interestRateController.text) / 100,
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
                decoration: const InputDecoration(labelText: 'Nombre del Cliente'), // Etiqueta cambiada
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
                keyboardType: TextInputType.numberWithOptions(decimal: true), // Teclado numérico, permite decimales
                validator: (value) {
                  if (value == null || value.isEmpty || double.tryParse(value) == null) {
                    return 'Por favor, ingresa un monto válido';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _interestRateController,
                decoration: const InputDecoration(labelText: 'Tasa de Interés Anual (%)'),
                keyboardType: TextInputType.numberWithOptions(decimal: true), // Teclado numérico, permite decimales
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
                keyboardType: TextInputType.number, // Teclado solo numérico (enteros)
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