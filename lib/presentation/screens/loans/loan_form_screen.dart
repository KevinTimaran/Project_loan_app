// lib/presentation/screens/loans/loan_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
import 'package:loan_app/domain/entities/client.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:loan_app/presentation/providers/loan_calculator_provider.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Asegúrate de importar Hive

class LoanFormScreen extends StatefulWidget {
  final LoanModel? loan;

  const LoanFormScreen({super.key, this.loan});

  @override
  State<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends State<LoanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _interestRateController = TextEditingController();
  final TextEditingController _termValueController = TextEditingController();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _clientLastNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _whatsappNumberController = TextEditingController();
  final LoanRepository _loanRepository = LoanRepository();
  final ClientRepository _clientRepository = ClientRepository();
  
  final DateTime _startDate = DateTime.now();
  Client? _selectedClient;
  List<Client> _clients = [];
  bool _isLoadingClients = false;

  @override
  void initState() {
    super.initState();
    _loadClientsAndPopulateForm();
    
    // Los listeners actualizan el Provider
    _amountController.addListener(() {
      final value = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
      context.read<LoanCalculatorProvider>().setAmount(value);
    });
    _interestRateController.addListener(() {
      final value = double.tryParse(_interestRateController.text) ?? 0.0;
      context.read<LoanCalculatorProvider>().setInterestRate(value);
    });
    _termValueController.addListener(() {
      final value = int.tryParse(_termValueController.text) ?? 0;
      context.read<LoanCalculatorProvider>().setTermValue(value);
    });
  }

  Future<void> _loadClientsAndPopulateForm() async {
    setState(() {
      _isLoadingClients = true;
    });
    try {
      final loadedClients = await _clientRepository.getClients();
      
      // Asegúrate de que el widget no ha sido descartado
      if (!mounted) return;
      
      setState(() {
        _clients = loadedClients;
      });

      // Lógica para poblar los campos en modo de edición
      if (widget.loan != null) {
        final loan = widget.loan!;
        
        // Asignar valores a los controladores
        _amountController.text = NumberFormat('#,###').format(loan.amount);
        _interestRateController.text = (loan.interestRate * 100).toStringAsFixed(2);
        _termValueController.text = loan.termValue.toString();

        // Buscar y seleccionar el cliente
        try {
          final client = loadedClients.firstWhere(
            (c) => c.id == loan.clientId,
          );
          if (mounted) {
            setState(() {
              _selectedClient = client;
            });
            // Rellenar campos de cliente solo si es un cliente existente
            _clientNameController.text = client.name;
            _clientLastNameController.text = client.lastName;
            _phoneNumberController.text = client.phone ?? '';
            _whatsappNumberController.text = client.whatsapp ?? '';
          }
        } catch (e) {
          debugPrint('Cliente no encontrado para el préstamo: ${loan.clientId}');
          // Opcional: Mostrar un mensaje al usuario
        }
        
        // Inicializar el provider con los valores del préstamo
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final loanCalculator = context.read<LoanCalculatorProvider>();
          loanCalculator.setAmount(loan.amount);
          loanCalculator.setInterestRate(loan.interestRate * 100);
          loanCalculator.setTermValue(loan.termValue);
          loanCalculator.setPaymentFrequency(loan.paymentFrequency);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar clientes: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingClients = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _interestRateController.dispose();
    _termValueController.dispose();
    _clientNameController.dispose();
    _clientLastNameController.dispose();
    _phoneNumberController.dispose();
    _whatsappNumberController.dispose();
    super.dispose();
  }
  
  Future<void> _saveLoan() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      String? clientId;
      String? clientName;
      String? phoneNumber;
      String? whatsappNumber;

      final loanCalculator = context.read<LoanCalculatorProvider>();
      final amount = loanCalculator.amount;
      final interestRate = loanCalculator.interestRate / 100;
      final termValue = loanCalculator.termValue;
      final paymentFrequency = loanCalculator.paymentFrequency;
      final termUnit = loanCalculator.termUnit;
      final calculatedTotalToPay = loanCalculator.amortizationSchedule.fold<int>(0, (s, e) => s + ((e['paymentCents'] as int))) / 100.0;
      final dueDate = loanCalculator.dueDate;

      if (_selectedClient != null) {
        clientId = _selectedClient!.id;
        clientName = '${_selectedClient!.name} ${_selectedClient!.lastName}';
        phoneNumber = _selectedClient!.phone;
        whatsappNumber = _selectedClient!.whatsapp;
      } else {
        if (_clientNameController.text.isNotEmpty && _clientLastNameController.text.isNotEmpty) {
          phoneNumber = _phoneNumberController.text.trim();
          whatsappNumber = _whatsappNumberController.text.trim();

          final newClient = Client(
            id: const Uuid().v4(),
            name: _clientNameController.text.trim(),
            lastName: _clientLastNameController.text.trim(),
            phone: phoneNumber,
            whatsapp: whatsappNumber,
            identification: '',
          );
          await _clientRepository.createClient(newClient);
          clientId = newClient.id;
          clientName = '${newClient.name} ${newClient.lastName}';
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor, selecciona un cliente o ingresa los datos de uno nuevo.')),
          );
          return;
        }
      }

      if (widget.loan == null) {
        // Lógica para crear un nuevo préstamo
        final newLoan = LoanModel(
          id: const Uuid().v4(),
          clientId: clientId!,
          clientName: clientName!,
          amount: amount,
          interestRate: interestRate,
          termValue: termValue,
          startDate: _startDate,
          dueDate: dueDate,
          paymentFrequency: paymentFrequency,
          termUnit: termUnit,
          whatsappNumber: whatsappNumber,
          phoneNumber: phoneNumber,
          payments: [],
          remainingBalance: calculatedTotalToPay,
          loanNumber: await _loanRepository.getNextLoanNumber(),
          status: 'Activo',
        );
        await _loanRepository.addLoan(newLoan);
      } else {
        // Lógica para actualizar un préstamo existente
        final updatedLoan = widget.loan!.copyWith(
          clientId: clientId,
          clientName: clientName,
          amount: amount,
          interestRate: interestRate,
          termValue: termValue,
          dueDate: dueDate,
          paymentFrequency: paymentFrequency,
          termUnit: termUnit,
          whatsappNumber: whatsappNumber,
          phoneNumber: phoneNumber,
          remainingBalance: calculatedTotalToPay,
        );
        await _loanRepository.updateLoan(updatedLoan); // Asume que este método existe
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.loan == null ? 'Préstamo guardado exitosamente' : 'Préstamo actualizado exitosamente')),
        );
        Navigator.pop(context, true); // Retorna 'true' para indicar que se debe recargar la lista
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor completa correctamente el formulario antes de guardar.')),
        );
      }
    }
  }

  void _showSimulationModal() {
    final loanCalculator = context.read<LoanCalculatorProvider>();
    final amortizationSchedule = loanCalculator.amortizationSchedule;

    if (amortizationSchedule.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el monto, tasa y plazo para ver la simulación.')),
      );
      return;
    }

    final currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final int totalInterestCents = amortizationSchedule.fold<int>(0, (s, e) => s + ((e['interestCents'] as int)));
    final int totalPaidCents = amortizationSchedule.fold<int>(0, (s, e) => s + ((e['paymentCents'] as int)));
    final int principalCents = (loanCalculator.amount * 100).round();
    final DateTime? nextPaymentDate = amortizationSchedule.isNotEmpty ? amortizationSchedule.first['date'] as DateTime : null;
    final int finalRemainingCents = amortizationSchedule.isNotEmpty ? (amortizationSchedule.last['remainingCents'] as int) : principalCents;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.35,
          maxChildSize: 0.98,
          builder: (_, controller) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('Resumen del Crédito', style: Theme.of(context).textTheme.titleLarge ?? const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _summaryRowSmall('Fecha de crédito', DateFormat('dd/MM/yyyy').format(loanCalculator.startDate)),
                                    const SizedBox(height: 8),
                                    _summaryRowSmall('Fecha próxima cuota', nextPaymentDate != null ? DateFormat('dd/MM/yyyy').format(nextPaymentDate) : '-'),
                                    const SizedBox(height: 8),
                                    _summaryRowSmall('Vencimiento del crédito', DateFormat('dd/MM/yyyy').format(loanCalculator.dueDate)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _summaryRowSmall('Interés (anual)', '${loanCalculator.interestRate.toStringAsFixed(2)} %'),
                                    const SizedBox(height: 8),
                                    _summaryRowSmall('Valor total interés', currency.format(totalInterestCents / 100.0)),
                                    const SizedBox(height: 8),
                                    _summaryRowSmall('Valor cuota', currency.format((amortizationSchedule.isNotEmpty ? (amortizationSchedule.first['paymentCents'] as int) / 100.0 : 0.0))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _summaryRowBold('Total prestado', currency.format(principalCents / 100.0))),
                              const SizedBox(width: 12),
                              Expanded(child: _summaryRowBold('Total + interés', currency.format(totalPaidCents / 100.0))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _summaryRowBold('Saldo total final', currency.format(finalRemainingCents / 100.0)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.builder(
                            controller: controller,
                            itemCount: amortizationSchedule.length,
                            itemBuilder: (context, index) {
                              final e = amortizationSchedule[index];
                              final paymentPesos = (e['paymentCents'] as int) / 100.0;
                              final interestPesos = (e['interestCents'] as int) / 100.0;
                              final principalPesos = (e['principalCents'] as int) / 100.0;
                              final remainingPesos = (e['remainingCents'] as int) / 100.0;

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: CircleAvatar(child: Text('${e['index']}')),
                                  title: Text('Cuota #${e['index']} - ${currency.format(paymentPesos)}'),
                                  subtitle: Text('${DateFormat('dd/MM/yyyy').format(e['date'])}\nInterés: ${currency.format(interestPesos)} • Capital: ${currency.format(principalPesos)}'),
                                  isThreeLine: true,
                                  trailing: Text('Saldo: ${currency.format(remainingPesos)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _summaryRowSmall(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _summaryRowBold(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LoanCalculatorProvider>(
      builder: (context, loanCalculator, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.loan == null ? 'Registrar Préstamo' : 'Editar Préstamo'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Datos del Cliente',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _isLoadingClients
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<Client>(
                          value: _selectedClient,
                          decoration: const InputDecoration(
                            labelText: 'Selecciona un cliente existente',
                            border: OutlineInputBorder(),
                          ),
                          items: _clients.map((client) {
                            return DropdownMenuItem(
                              value: client,
                              child: Text('${client.name} ${client.lastName}'),
                            );
                          }).toList(),
                          onChanged: (client) {
                            setState(() {
                              _selectedClient = client;
                              if (client != null) {
                                _clientNameController.text = client.name;
                                _clientLastNameController.text = client.lastName;
                                _phoneNumberController.text = client.phone ?? '';
                                _whatsappNumberController.text = client.whatsapp ?? '';
                              } else {
                                _clientNameController.clear();
                                _clientLastNameController.clear();
                                _phoneNumberController.clear();
                                _whatsappNumberController.clear();
                              }
                            });
                          },
                        ),
                  const SizedBox(height: 16),
                  const Center(child: Text('O crea uno nuevo', style: TextStyle(fontStyle: FontStyle.italic))),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _clientNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Cliente',
                      border: OutlineInputBorder(),
                    ),
                    enabled: _selectedClient == null,
                    validator: (value) {
                      if (_selectedClient == null && (value == null || value.isEmpty)) {
                        return 'Por favor, ingresa el nombre del cliente.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _clientLastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Apellido del Cliente',
                      border: OutlineInputBorder(),
                    ),
                    enabled: _selectedClient == null,
                    validator: (value) {
                      if (_selectedClient == null && (value == null || value.isEmpty)) {
                        return 'Por favor, ingresa el apellido del cliente.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Número de teléfono',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _whatsappNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Número de WhatsApp',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Datos del Préstamo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Monto del Préstamo',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CurrencyInputFormatter(),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, ingresa un monto.';
                      }
                      final cleanValue = double.tryParse(value.replaceAll(',', ''));
                      if (cleanValue == null || cleanValue <= 0) {
                        return 'El monto debe ser un número positivo.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _interestRateController,
                    decoration: const InputDecoration(
                      labelText: 'Tasa de Interés Anual (%)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, ingresa una tasa de interés.';
                      }
                      final rate = double.tryParse(value);
                      if (rate == null || rate <= 0) {
                        return 'La tasa debe ser un número positivo.';
                      }
                      if (rate > 200) {
                        return 'La tasa no puede ser mayor al 200%';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: loanCalculator.paymentFrequency,
                    decoration: const InputDecoration(
                      labelText: 'Frecuencia de Pago',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Diario', 'Semanal', 'Quincenal', 'Mensual'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        context.read<LoanCalculatorProvider>().setPaymentFrequency(newValue);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _termValueController,
                    decoration: InputDecoration(
                      labelText: 'Plazo en ${loanCalculator.termUnit}',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, ingresa un plazo.';
                      }
                      final term = int.tryParse(value);
                      if (term == null || term <= 0) {
                        return 'El plazo debe ser un número entero positivo.';
                      }
                      if (term > 360) {
                        return 'El plazo no puede ser mayor a 360 ${loanCalculator.termUnit}.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: _showSimulationModal,
                      icon: const Icon(Icons.show_chart),
                      label: const Text('Ver simulación'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: _saveLoan,
                      child: Text(widget.loan == null ? '💸' : '💾', style: const TextStyle(fontSize: 20)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final newString = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (newString.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final double value = double.parse(newString);
    final formatter = NumberFormat('#,###');
    final String newText = formatter.format(value);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
