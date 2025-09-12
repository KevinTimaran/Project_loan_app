// lib/presentation/screens/loans/loan_form_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/presentation/screens/clients/client_list_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

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

  String _paymentFrequency = 'Mensual';
  late String _termUnit;
  final DateTime _startDate = DateTime.now();
  late DateTime _dueDate;
  Client? _selectedClient;
  List<Client> _clients = [];
  bool _isLoadingClients = false;

  // Totales mostrados (en pesos)
  double _calculatedInterest = 0.0;
  double _calculatedTotalToPay = 0.0;
  double _calculatedPaymentAmount = 0.0;
  int _numberOfPayments = 0;
  List<DateTime> _paymentDates = [];

  // Schedule: cada entrada almacena montos en CENTAVOS (int)
  // keys: paymentCents, interestCents, principalCents, remainingCents, date, index
  List<Map<String, dynamic>> _amortizationSchedule = [];

  @override
  void initState() {
    super.initState();
    _setTermUnitBasedOnFrequency();
    _dueDate = _calculateDueDate();
    _loadClients();
    _amountController.addListener(_updateCalculations);
    _interestRateController.addListener(_updateCalculations);
    _termValueController.addListener(_updateCalculations);
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateCalculations);
    _interestRateController.removeListener(_updateCalculations);
    _termValueController.removeListener(_updateCalculations);
    _amountController.dispose();
    _interestRateController.dispose();
    _termValueController.dispose();
    _clientNameController.dispose();
    _clientLastNameController.dispose();
    _phoneNumberController.dispose();
    _whatsappNumberController.dispose();
    super.dispose();
  }

  void _setTermUnitBasedOnFrequency() {
    switch (_paymentFrequency) {
      case 'Diario':
        _termUnit = 'Días';
        break;
      case 'Semanal':
        _termUnit = 'Semanas';
        break;
      case 'Quincenal':
        _termUnit = 'Quincenas';
        break;
      case 'Mensual':
      default:
        _termUnit = 'Meses';
        break;
    }
  }

  Future<void> _loadClients() async {
    setState(() {
      _isLoadingClients = true;
    });
    try {
      final loadedClients = await _clientRepository.getClients();
      setState(() {
        _clients = loadedClients;
      });
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

  void _updateCalculations() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    final interestRate = double.tryParse(_interestRateController.text) ?? 0.0;
    final termValue = int.tryParse(_termValueController.text) ?? 0;

    if (amount > 0 && interestRate >= 0 && termValue > 0) {
      _calculateLoanDetails(amount, interestRate, termValue);
    } else {
      setState(() {
        _calculatedInterest = 0.0;
        _calculatedTotalToPay = 0.0;
        _calculatedPaymentAmount = 0.0;
        _numberOfPayments = 0;
        _paymentDates = [];
        _amortizationSchedule = [];
      });
    }
  }

  // Helper: retorna número de periodos por año según la frecuencia
  int _periodsPerYearForFrequency(String freq) {
    switch (freq) {
      case 'Diario':
        return 365;
      case 'Semanal':
        return 52;
      case 'Quincenal':
        return 24;
      case 'Mensual':
      default:
        return 12;
    }
  }

  // Helper: suma meses de forma segura (evita overflow de día cuando el mes destino tiene menos días)
  DateTime addMonthsSafe(DateTime date, int monthsToAdd) {
    int year = date.year;
    int month = date.month + monthsToAdd;
    year += (month - 1) ~/ 12;
    month = ((month - 1) % 12) + 1;
    int day = date.day;
    int lastDayOfMonth = DateTime(year, month + 1, 0).day;
    if (day > lastDayOfMonth) day = lastDayOfMonth;
    return DateTime(year, month, day, date.hour, date.minute, date.second, date.millisecond, date.microsecond);
  }

  // ======= Helper central: genera el schedule con interés simple (trabaja en CENTAVOS) =======
  List<Map<String, dynamic>> buildSimpleInterestSchedule({
    required double principal,          // en pesos (ej. 3333333.0)
    required double annualRatePercent,  // ej. 24 (no decimal)
    required int numberOfPayments,
    required String frequency,          // 'Diario','Semanal','Quincenal','Mensual'
    required DateTime startDate,
  }) {
    int periodsPerYear;
    if (frequency == 'Diario') periodsPerYear = 365;
    else if (frequency == 'Semanal')
      periodsPerYear = 52;
    else if (frequency == 'Quincenal')
      periodsPerYear = 24;
    else
      periodsPerYear = 12;

    final double annualRate = annualRatePercent / 100.0;
    final double timeInYears = numberOfPayments / periodsPerYear;

    // Trabajar en centavos (int) para evitar floats
    final int principalCents = (principal * 100).round();

    // total de interés en centavos
    final int totalInterestCents = (principalCents * annualRate * timeInYears).round();

    // repartir en partes iguales y calcular restos
    final int principalPerPaymentCents = principalCents ~/ numberOfPayments;
    final int interestPerPaymentCents = totalInterestCents ~/ numberOfPayments;
    final int principalRemainder = principalCents - (principalPerPaymentCents * numberOfPayments);
    final int interestRemainder = totalInterestCents - (interestPerPaymentCents * numberOfPayments);

    DateTime current = startDate;
    int remainingCents = principalCents;
    List<Map<String, dynamic>> schedule = [];

    for (int i = 0; i < numberOfPayments; i++) {
      if (frequency == 'Diario')
        current = current.add(const Duration(days: 1));
      else if (frequency == 'Semanal')
        current = current.add(const Duration(days: 7));
      else if (frequency == 'Quincenal')
        current = current.add(const Duration(days: 15));
      else
        current = addMonthsSafe(current, 1);

      int principalPortionCents = principalPerPaymentCents;
      int interestPortionCents = interestPerPaymentCents;

      // en la última cuota añadimos los restos para que cuadre todo
      if (i == numberOfPayments - 1) {
        principalPortionCents += principalRemainder;
        interestPortionCents += interestRemainder;
      }

      final int paymentCents = principalPortionCents + interestPortionCents;
      remainingCents = (remainingCents - principalPortionCents).clamp(0, 1 << 62);

      schedule.add({
        'index': i + 1,
        'date': current,
        'paymentCents': paymentCents,
        'interestCents': interestPortionCents,
        'principalCents': principalPortionCents,
        'remainingCents': remainingCents,
      });
    }

    return schedule;
  }

  // ======= Lógica: usa el schedule central para setear estados visibles =======
  // NO cambies la firma de la función (se solicita mantenerla)
  void _calculateLoanDetails(double amount, double interestRate, int termValue) {
    final int n = termValue;
    if (n <= 0) {
      setState(() {
        _calculatedInterest = 0.0;
        _calculatedTotalToPay = 0.0;
        _calculatedPaymentAmount = 0.0;
        _numberOfPayments = 0;
        _paymentDates = [];
        _amortizationSchedule = [];
      });
      return;
    }

    final schedule = buildSimpleInterestSchedule(
      principal: amount,
      annualRatePercent: interestRate,
      numberOfPayments: n,
      frequency: _paymentFrequency,
      startDate: _startDate,
    );

    // calcular totales en centavos
    final int totalInterestCents = schedule.fold<int>(0, (s, e) => s + (e['interestCents'] as int));
    final int totalPaidCents = schedule.fold<int>(0, (s, e) => s + (e['paymentCents'] as int));
    final List<DateTime> dates = schedule.map((e) => e['date'] as DateTime).toList();

    setState(() {
      _amortizationSchedule = schedule;
      _calculatedInterest = (totalInterestCents / 100.0);
      _calculatedTotalToPay = (totalPaidCents / 100.0);
      _calculatedPaymentAmount = schedule.isNotEmpty ? (schedule.first['paymentCents'] as int) / 100.0 : 0.0;
      _numberOfPayments = n;
      _paymentDates = dates;
    });

    _updateDueDate();
  }

  DateTime _calculateDueDate() {
    final now = DateTime.now();
    int termValue = int.tryParse(_termValueController.text) ?? 0;

    if (termValue == 0) return now;

    switch (_termUnit) {
      case 'Días':
        return now.add(Duration(days: termValue));
      case 'Semanas':
        return now.add(Duration(days: termValue * 7));
      case 'Quincenas':
        return now.add(Duration(days: termValue * 15));
      case 'Meses':
      default:
        return DateTime(now.year, now.month + termValue, now.day);
    }
  }

  void _updateDueDate() {
    setState(() {
      _dueDate = _calculateDueDate();
    });
  }

  Future<void> _saveLoan() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      String? clientId;
      String? clientName;
      String? phoneNumber;
      String? whatsappNumber;

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

      final newLoan = LoanModel(
        clientId: clientId!,
        clientName: clientName!,
        amount: double.parse(_amountController.text.replaceAll(',', '')),
        interestRate: double.parse(_interestRateController.text) / 100,
        termValue: int.parse(_termValueController.text),
        startDate: _startDate,
        dueDate: _dueDate,
        paymentFrequency: _paymentFrequency,
        termUnit: _termUnit,
        whatsappNumber: whatsappNumber,
        phoneNumber: phoneNumber,
        payments: [], // Si quieres guardar _amortizationSchedule, adapta LoanModel
        remainingBalance: _calculatedTotalToPay,
      );

      await _loanRepository.addLoan(newLoan);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Préstamo guardado exitosamente')),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor completa correctamente el formulario antes de guardar.')),
        );
      }
    }
  }

  // Mostrar modal con simulación (desplegable) — ahora incluye la tarjeta resumen grande arriba
  void _showSimulationModal() {
    final currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

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
            // Totales en centavos (si schedule no vacío)
            final int totalInterestCents = _amortizationSchedule.fold<int>(0, (s, e) => s + ((e['interestCents'] as int)));
            final int totalPaidCents = _amortizationSchedule.fold<int>(0, (s, e) => s + ((e['paymentCents'] as int)));
            final int principalCents = (double.tryParse(_amountController.text.replaceAll(',', '')) != null)
                ? (double.parse(_amountController.text.replaceAll(',', '')) * 100).round()
                : 0;
            final DateTime? nextPaymentDate = _amortizationSchedule.isNotEmpty ? _amortizationSchedule.first['date'] as DateTime : null;

            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // TARJETA RESUMEN GRANDE (dentro del modal, primero)
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
                                    _summaryRowSmall('Fecha de crédito', DateFormat('dd/MM/yyyy').format(_startDate)),
                                    const SizedBox(height: 8),
                                    _summaryRowSmall('Fecha próxima cuota', nextPaymentDate != null ? DateFormat('dd/MM/yyyy').format(nextPaymentDate) : '-'),
                                    const SizedBox(height: 8),
                                    _summaryRowSmall('Vencimiento del crédito', DateFormat('dd/MM/yyyy').format(_dueDate)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _summaryRowSmall('Interés (anual)', _interestRateController.text.isNotEmpty ? '${_interestRateController.text.trim()} %' : '-'),
                                    const SizedBox(height: 8),
                                    _summaryRowSmall('Valor total interés', currency.format(totalInterestCents / 100.0)),
                                    const SizedBox(height: 8),
                                    _summaryRowSmall('Valor cuota', currency.format((_amortizationSchedule.isNotEmpty ? (_amortizationSchedule.first['paymentCents'] as int) / 100.0 : 0.0))),
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
                              Expanded(child: _summaryRowBold('Total + interés', currency.format((principalCents + totalInterestCents) / 100.0))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _summaryRowBold('Saldo total', currency.format((_amortizationSchedule.isNotEmpty ? (_amortizationSchedule.last['remainingCents'] as int) / 100.0 : (principalCents + totalInterestCents) / 100.0))),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Expanded(
                    child: _amortizationSchedule.isEmpty
                        ? Center(child: Text('Aún no hay simulación. Ingresa monto, tasa y plazo.', style: TextStyle(color: Colors.grey[700])))
                        : ListView.builder(
                            controller: controller,
                            itemCount: _amortizationSchedule.length,
                            itemBuilder: (context, index) {
                              final e = _amortizationSchedule[index];
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
              // Nota: la tarjeta resumen grande ya no está aquí; ahora aparece DENTRO del modal de simulación.
              // Se muestra el formulario normal debajo.
              // Sección de Datos del Cliente
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

              // Sección de Datos del Préstamo
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
                  if (value == null || value.isEmpty || double.tryParse(value.replaceAll(',', '')) == null) {
                    return 'Por favor, ingresa un monto válido.';
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
                  if (value == null || value.isEmpty || double.tryParse(value) == null) {
                    return 'Por favor, ingresa una tasa válida.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _paymentFrequency,
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
                    setState(() {
                      _paymentFrequency = newValue;
                      _setTermUnitBasedOnFrequency();
                      _updateCalculations();
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _termValueController,
                decoration: InputDecoration(
                  labelText: 'Plazo en $_termUnit',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _updateCalculations(),
                validator: (value) {
                  if (value == null || value.isEmpty || int.tryParse(value) == null) {
                    return 'Por favor, ingresa un plazo válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // fin del formulario
            ],
          ),
        ),
      ),

      // BOTONES FIJOS EN LA PARTE INFERIOR
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
                  child: const Text('💸', style: TextStyle(fontSize: 20)),
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

    double value = double.parse(newString);
    final formatter = NumberFormat('#,###');
    String newText = formatter.format(value);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
