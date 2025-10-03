//#################################################
//#  Pantalla de Edición de Préstamo               #//
//#  Permite modificar los detalles de un préstamo, #//
//#  recalcular pagos y actualizar la base de datos.#//
//#  Solo si el préstamo está activo.              #//
//#################################################

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:intl/intl.dart';

class LoanEditScreen extends StatefulWidget {
  final LoanModel loan;

   const LoanEditScreen({super.key, required this.loan});

  @override
  State<LoanEditScreen> createState() => _LoanEditScreenState();
}

class _LoanEditScreenState extends State<LoanEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _interestRateController = TextEditingController();
  final TextEditingController _termValueController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final LoanRepository _loanRepository = LoanRepository();
  final ClientRepository _clientRepository = ClientRepository();

  String _paymentFrequency = 'Mensual';
  late String _termUnit;
  late DateTime _startDate;
  late DateTime _dueDate;
  Client? _client;
  bool _isLoading = true;

  // Totales mostrados (en pesos)
  double _calculatedInterest = 0.0;
  double _calculatedTotalToPay = 0.0;
  double _calculatedPaymentAmount = 0.0;
  int _numberOfPayments = 0;
  List<DateTime> _paymentDates = [];

  // Schedule: cada entrada almacena montos en CENTAVOS (int)
  List<Map<String, dynamic>> _amortizationSchedule = [];

  @override
  void initState() {
    super.initState();
    _loadClientData();
  }

  Future<void> _loadClientData() async {
    try {
      // Cargar información del cliente
      _client = await _clientRepository.getClientById(widget.loan.clientId);
      
      // Inicializar campos con los datos del préstamo
      _amountController.text = NumberFormat.decimalPattern('es_CO').format(widget.loan.amount);
      _interestRateController.text = (widget.loan.interestRate * 100).toStringAsFixed(2);
      _termValueController.text = widget.loan.termValue.toString();
      _paymentFrequency = widget.loan.paymentFrequency;
      _startDate = widget.loan.startDate;
      _dueDate = widget.loan.dueDate;
      
      // Formatear fecha de inicio para mostrar
      _startDateController.text = DateFormat('dd/MM/yyyy').format(_startDate);
      
      _setTermUnitBasedOnFrequency();
      _updateCalculations();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
        // Aún así continuar con los datos del préstamo
        _setInitialLoanData();
      }
    }
  }

  void _setInitialLoanData() {
    _amountController.text = NumberFormat.decimalPattern('es_CO').format(widget.loan.amount);
    _interestRateController.text = (widget.loan.interestRate * 100).toStringAsFixed(2);
    _termValueController.text = widget.loan.termValue.toString();
    _paymentFrequency = widget.loan.paymentFrequency;
    _startDate = widget.loan.startDate;
    _dueDate = widget.loan.dueDate;
    _startDateController.text = DateFormat('dd/MM/yyyy').format(_startDate);
    
    _setTermUnitBasedOnFrequency();
    _updateCalculations();
    
    setState(() {
      _isLoading = false;
    });
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

  void _updateCalculations() {
    final amount = double.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
    final interestRate = double.tryParse(_interestRateController.text) ?? 0.0;
    final termValue = int.tryParse(_termValueController.text) ?? 0;

    if (amount > 0 && interestRate >= 0 && termValue > 0) {
      _calculateLoanDetails(amount, interestRate, termValue);
    } else if (_calculatedTotalToPay != 0.0 || _numberOfPayments != 0) {
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

  List<Map<String, dynamic>> buildSimpleInterestSchedule({
    required double principal,
    required double annualRatePercent,
    required int numberOfPayments,
    required String frequency,
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
    final double timeInYears = numberOfPayments / periodsPerYear.toDouble();

    final int principalCents = (principal * 100).round();
    final int totalInterestCents = (principalCents * annualRate * timeInYears).round();

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

  void _calculateLoanDetails(double amount, double interestRate, int termValue) {
    if (!mounted) return;

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
    final now = _startDate;
    int termValue = int.tryParse(_termValueController.text) ?? 0;

    if (termValue == 0) return now;

    switch (_paymentFrequency) {
      case 'Diario':
        return now.add(Duration(days: termValue));
      case 'Semanal':
        return now.add(Duration(days: termValue * 7));
      case 'Quincenal':
        return now.add(Duration(days: termValue * 15));
      case 'Mensual':
      default:
        return addMonthsSafe(now, termValue);
    }
  }

  void _updateDueDate() {
    setState(() {
      _dueDate = _calculateDueDate();
    });
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        _startDateController.text = DateFormat('dd/MM/yyyy').format(picked);
        _updateCalculations();
      });
    }
  }

  Future<void> _saveLoan() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        final amount = double.parse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
        final interestRate = double.parse(_interestRateController.text) / 100;
        final termValue = int.parse(_termValueController.text);
        
        // Validar que el monto no sea menor que lo ya pagado
        if (amount < widget.loan.totalPaid) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('El monto no puede ser menor al total ya pagado (${NumberFormat.currency(locale: 'es_CO', symbol: '\$').format(widget.loan.totalPaid)})')),
          );
          return;
        }

        final updatedLoan = widget.loan.copyWith(
          amount: amount,
          interestRate: interestRate,
          termValue: termValue,
          startDate: _startDate,
          dueDate: _dueDate,
          paymentFrequency: _paymentFrequency,
          termUnit: _termUnit,
          remainingBalance: _calculatedTotalToPay - widget.loan.totalPaid,
          calculatedPaymentAmount: _calculatedPaymentAmount,
          totalAmountToPay: _calculatedTotalToPay,
          paymentDates: _paymentDates,
        );
        
        await _loanRepository.updateLoan(updatedLoan);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Préstamo actualizado exitosamente')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al actualizar préstamo: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor completa correctamente el formulario antes de guardar.')),
        );
      }
    }
  }

  int _getPrincipalInCents() {
    final cleanText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.tryParse(cleanText) ?? 0.0;
    return (amount * 100).round();
  }

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
            final int totalInterestCents = _amortizationSchedule.fold<int>(0, (s, e) => s + ((e['interestCents'] as int)));
            final int principalCents = _getPrincipalInCents();
            final DateTime? nextPaymentDate = _amortizationSchedule.isNotEmpty ? _amortizationSchedule.first['date'] as DateTime : null;

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
                              Expanded(child: const Text('Resumen del Crédito', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
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
                        ? Center(child: const Text('Aún no hay simulación. Ingresa monto, tasa y plazo.', style: TextStyle(color: Colors.grey)))
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
      ]
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _interestRateController.dispose();
    _termValueController.dispose();
    _startDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Préstamo'),
      ),
      body: Column(
        children: [
  

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Información del cliente (solo lectura)
                          Card(
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Información del Cliente',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  ListTile(
                                    leading: const Icon(Icons.person),
                                    title: Text(_client?.name ?? widget.loan.clientName),
                                    subtitle: const Text('Nombre'),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.phone),
                                    title: Text(_client?.phone ?? widget.loan.phoneNumber ?? 'No especificado'),
                                    subtitle: const Text('Teléfono'),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.chat),
                                    title: Text(_client?.whatsapp ?? widget.loan.whatsappNumber ?? 'No especificado'),
                                    subtitle: const Text('WhatsApp'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Sección de Datos del Préstamo (editables)
                          const Text(
                            'Datos del Préstamo',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          
                          // Campo de fecha de inicio
                          TextFormField(
                            controller: _startDateController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Fecha de Inicio',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            onTap: () => _selectStartDate(context),
                          ),
                          const SizedBox(height: 16),
                          
                          TextFormField(
                            controller: _amountController,
                            decoration: const InputDecoration(
                              labelText: 'Monto del Préstamo',
                              border: OutlineInputBorder(),
                              prefixText: '\$',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              CurrencyInputFormatter(),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingresa el monto.';
                              }
                              final cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');
                              if (double.tryParse(cleanValue) == null) {
                                return 'Por favor, ingresa un monto válido.';
                              }
                              final amount = double.parse(cleanValue);
                              if (amount <= 0) {
                                return 'El monto debe ser mayor a cero.';
                              }
                              if (amount < widget.loan.totalPaid) {
                                return 'El monto no puede ser menor al total ya pagado.';
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
                              suffixText: '%',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingresa la tasa de interés.';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Por favor, ingresa una tasa válida.';
                              }
                              final rate = double.parse(value);
                              if (rate <= 0) {
                                return 'La tasa debe ser mayor a cero.';
                              }
                              if (rate > 100) {
                                return 'La tasa no puede ser mayor al 100%.';
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
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingresa el plazo.';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Por favor, ingresa un plazo válido.';
                              }
                              final term = int.parse(value);
                              if (term <= 0) {
                                return 'El plazo debe ser mayor a cero.';
                              }
                              return null;
                            },
                          ),
                          
                          // Información calculada
                          if (_calculatedTotalToPay > 0) ...[
                            const SizedBox(height: 24),
                            Card(
                              color: Colors.blue.shade50,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Resumen del Préstamo',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Total a pagar:'),
                                        Text(
                                          currencyFormatter.format(_calculatedTotalToPay),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Valor de la cuota:'),
                                        Text(
                                          currencyFormatter.format(_calculatedPaymentAmount),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Fecha de vencimiento:'),
                                        Text(
                                          DateFormat('dd/MM/yyyy').format(_dueDate),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
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
                  child: const Text('💾', style: TextStyle(fontSize: 20)),
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

    // Mantener posición relativa del cursor
    final offset = newValue.selection.baseOffset;
    final oldText = oldValue.text;
    final diff = newText.length - oldText.length;
    final newOffset = (offset + diff).clamp(0, newText.length);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}