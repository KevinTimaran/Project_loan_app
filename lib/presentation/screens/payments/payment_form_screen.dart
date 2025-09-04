// lib/presentation/screens/payments/payment_form_screen.dart

import 'package:flutter/material.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
import 'package:loan_app/data/repositories/payment_repository.dart';
import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/domain/entities/payment.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart'; // 💡 Importa la librería intl

class PaymentFormScreen extends StatefulWidget {
  const PaymentFormScreen({super.key});

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ClientRepository _clientRepository = ClientRepository();
  final LoanRepository _loanRepository = LoanRepository();
  final PaymentRepository _paymentRepository = PaymentRepository();

  List<Client> _clients = [];
  List<LoanModel> _loans = [];
  Client? _selectedClient;
  LoanModel? _selectedLoan;
  
  // 💡 Usa el controlador personalizado para el monto
  final NumberFormatterController _amountController = NumberFormatterController();

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    final clients = await _clientRepository.getClients();
    setState(() {
      _clients = clients;
    });
  }

  Future<void> _loadLoansForClient(String clientId) async {
    final loans = await _loanRepository.getLoansByClientId(clientId);
    setState(() {
      _loans = loans;
      _selectedLoan = null;
    });
  }

  Future<void> _savePayment() async {
    if (_formKey.currentState!.validate()) {
      // 💡 CORRECCIÓN: Limpiar el texto antes de convertirlo a double
      final String cleanAmountText = _amountController.text.replaceAll('.', '');
      final double amount = double.tryParse(cleanAmountText) ?? 0.0;
      
      final newPayment = Payment(
        id: const Uuid().v4(),
        loanId: _selectedLoan!.id,
        amount: amount,
        date: DateTime.now(),
      );

      await _paymentRepository.addPayment(newPayment);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pago registrado exitosamente')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Pago'),
      ),
      body: _clients.isEmpty
          ? const Center(child: Text('No hay clientes para registrar un pago.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<Client>(
                      value: _selectedClient,
                      decoration: const InputDecoration(
                        labelText: 'Selecciona un cliente',
                        border: OutlineInputBorder(),
                      ),
                      items: _clients.map((client) {
                        return DropdownMenuItem(
                          value: client,
                          child: Text(client.name),
                        );
                      }).toList(),
                      onChanged: (client) {
                        setState(() {
                          _selectedClient = client;
                          _loadLoansForClient(client!.id);
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Por favor, selecciona un cliente.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<LoanModel>(
                      value: _selectedLoan,
                      decoration: const InputDecoration(
                        labelText: 'Selecciona un préstamo',
                        border: OutlineInputBorder(),
                      ),
                      items: _loans.map((loan) {
                        return DropdownMenuItem(
                          value: loan,
                          child: Text('Préstamo #${loan.id.substring(0, 4)} - Monto: \$${loan.amount}'),
                        );
                      }).toList(),
                      onChanged: _selectedClient == null
                          ? null
                          : (loan) {
                              setState(() {
                                _selectedLoan = loan;
                              });
                            },
                      validator: (value) {
                        if (value == null) {
                          return 'Por favor, selecciona un préstamo.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Monto del Pago',
                        hintText: 'Ej: 150000',
                        border: OutlineInputBorder(),
                        prefixText: '\$',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa el monto.';
                        }
                        // 💡 Validación mejorada para el formato de número
                        final cleanValue = value.replaceAll('.', '');
                        if (double.tryParse(cleanValue) == null) {
                          return 'Por favor, ingresa un número válido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _savePayment,
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar Pago'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// 💡 NUEVA CLASE: Controlador de texto personalizado para formatear números
class NumberFormatterController extends TextEditingController {
  // Configura el formato de número local para Colombia
  final NumberFormat _formatter = NumberFormat.decimalPattern('es_CO');

  @override
  set value(TextEditingValue newValue) {
    String cleanText = newValue.text.replaceAll('.', '');
    if (cleanText.isEmpty) {
      super.value = newValue.copyWith(text: '');
      return;
    }

    try {
      double value = double.parse(cleanText);
      String formattedText = _formatter.format(value);
      super.value = newValue.copyWith(
        text: formattedText,
        selection: TextSelection.collapsed(offset: formattedText.length),
      );
    } catch (e) {
      // Maneja errores de formato
      super.value = newValue;
    }
  }
}