// lib/presentation/screens/loans/loan_form_screen.dart
//#################################################
//#  Pantalla de Formulario de Préstamo           #
//#  Permite crear o editar un préstamo,           #
//#  seleccionar cliente, ingresar datos y ver    #
//#  simulación de pagos.                         #
//#################################################

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
import 'package:loan_app/presentation/screens/loans/loan_edit_screen.dart';

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
  // ✅ Eliminado: _startDateController (ya no se necesita)

  final LoanRepository _loanRepository = LoanRepository();
  final ClientRepository _clientRepository = ClientRepository();

  String _paymentFrequency = 'Mensual';
  late String _termUnit;
  DateTime _startDate = DateTime.now();
  late DateTime _dueDate;
  Client? _selectedClient;
  List<Client> _clients = [];
  bool _isLoadingClients = false;
  bool _isCreatingNewClient = false;
  final bool _use26Quincenas = true;

  double _calculatedInterest = 0.0;
  double _calculatedTotalToPay = 0.0;
  double _calculatedPaymentAmount = 0.0;
  int _numberOfPayments = 0;
  List<DateTime> _paymentDates = [];
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
    // ✅ Eliminado: _startDateController.text = ...

    if (widget.loan != null) {
      _prefillFromLoan(widget.loan!);
    }
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
    // ✅ Eliminado: _startDateController.dispose();
    super.dispose();
  }

  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  void _prefillFromLoan(LoanModel loan) {
    _amountController.text = loan.amount.toStringAsFixed(0);
    _interestRateController.text = (loan.interestRate * 100).toString();
    _termValueController.text = loan.termValue.toString();
    _paymentFrequency = loan.paymentFrequency;
    _setTermUnitBasedOnFrequency();
    _startDate = loan.startDate;
    // ✅ Eliminado: _startDateController.text = ...
    _dueDate = loan.dueDate;
    _paymentDates = loan.paymentDates ?? [];
    _calculatedTotalToPay = loan.totalAmountToPay ?? _calculatedTotalToPay;
    _calculatedPaymentAmount = loan.calculatedPaymentAmount ?? _calculatedPaymentAmount;
    _calculatedInterest = (loan.totalAmountToPay ?? 0.0) - (loan.amount);
    _numberOfPayments = loan.termValue;
    _amortizationSchedule = [];
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

      if (widget.loan != null && widget.loan!.clientId.isNotEmpty) {
        final match = _clients.firstWhere(
          (c) => c.id == widget.loan!.clientId,
          orElse: () => Client(id: '', name: '', lastName: '', identification: '', phone: '', whatsapp: ''),
        );
        if (match.id.isNotEmpty) {
          setState(() {
            _selectedClient = match;
            _clientNameController.text = match.name;
            _clientLastNameController.text = match.lastName;
            _phoneNumberController.text = match.phone ?? '';
            _whatsappNumberController.text = match.whatsapp ?? '';
          });
        }
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
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    final interestRateInput = double.tryParse(_interestRateController.text) ?? 0.0;
    final termValue = int.tryParse(_termValueController.text) ?? 0;

    if (amount > 0 && interestRateInput >= 0 && termValue > 0) {
      _calculateLoanDetails(amount, interestRateInput, termValue);
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

  int _periodsPerYearForFrequency(String freq) {
    switch (freq) {
      case 'Diario':
        return 365;
      case 'Semanal':
        return 52;
      case 'Quincenal':
        return _use26Quincenas ? 26 : 24;
      case 'Mensual':
      default:
        return 12;
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

List<Map<String, dynamic>> buildAnnuitySchedule({
  required double principal,
  required double annualRatePercent,
  required int numberOfPayments,
  required String frequency,
  required DateTime startDate,
}) {
  debugPrint('🔄 Iniciando buildAnnuitySchedule...');
  debugPrint('   Principal: $principal, Tasa: $annualRatePercent%, Pagos: $numberOfPayments, Frecuencia: $frequency');

  final int periodsPerYear = _periodsPerYearForFrequency(frequency);
  final double annualRate = annualRatePercent / 100.0;
  final double r = annualRate / periodsPerYear;

  debugPrint('   Tasa periódica: $r, Periodos por año: $periodsPerYear');

  final int principalCents = (principal * 100).round();
  final int n = numberOfPayments;
  if (n <= 0) {
    debugPrint('❌ Número de pagos inválido: $n');
    return [];
  }

  double payment;
  if (r > 0) {
    final denom = 1 - pow(1 + r, -n);
    payment = denom == 0 ? principal / n : principal * r / denom;
  } else {
    payment = principal / n;
  }

  final int paymentCentsBase = (payment * 100).round();
  debugPrint('   Cuota base calculada: ${paymentCentsBase / 100}');

  List<Map<String, dynamic>> schedule = [];
  DateTime current = startDate;
  int remainingCents = principalCents;
  int totalInterestAccumCents = 0;
  int sumPaymentsCents = 0;

  for (int i = 0; i < n; i++) {
    if (frequency == 'Diario') {
      current = current.add(const Duration(days: 1));
    } else if (frequency == 'Semanal') {
      current = current.add(const Duration(days: 7));
    } else if (frequency == 'Quincenal') {
      current = current.add(Duration(days: _use26Quincenas ? 14 : 15));
    } else {
      current = addMonthsSafe(current, 1);
    }

    // Calcular interés para el período
    double interestForPeriod = (remainingCents / 100.0) * r;
    int interestCents = (interestForPeriod * 100).round();

    int principalCentsForPeriod;
    int paymentCents;

    // ✅ SOLUCIÓN: Lógica mejorada para la última cuota
    if (i == n - 1) {
      // Última cuota: el capital es exactamente el saldo restante
      principalCentsForPeriod = remainingCents;
      // Recalcular interés basado en el saldo real
      interestCents = ((remainingCents / 100.0) * r * 100).round();
      paymentCents = principalCentsForPeriod + interestCents;
      remainingCents = 0; // ✅ Forzar saldo a cero
    } else {
      // Cuotas normales
      principalCentsForPeriod = paymentCentsBase - interestCents;
      
      // Asegurar que el capital no sea negativo
      if (principalCentsForPeriod < 0) {
        principalCentsForPeriod = 0;
      }
      
      // Asegurar que no paguemos más del saldo restante
      if (principalCentsForPeriod > remainingCents) {
        principalCentsForPeriod = remainingCents;
      }
      
      paymentCents = paymentCentsBase;
      remainingCents = remainingCents - principalCentsForPeriod;
    }

    totalInterestAccumCents += interestCents;
    sumPaymentsCents += paymentCents;

    schedule.add({
      'index': i + 1,
      'date': current,
      'paymentCents': paymentCents,
      'interestCents': interestCents,
      'principalCents': principalCentsForPeriod,
      'remainingCents': remainingCents,
    });

    debugPrint('   Cuota ${i + 1}: Capital: ${principalCentsForPeriod / 100}, Interés: ${interestCents / 100}, Saldo: ${remainingCents / 100}');

    // ✅ Si el saldo es cero, terminar el ciclo
    if (remainingCents <= 0) {
      break;
    }
  }

  // ✅ VALIDACIÓN FINAL: Asegurar que el saldo final sea cero
  if (schedule.isNotEmpty) {
    final lastPayment = schedule.last;
    if (lastPayment['remainingCents'] > 0) {
      debugPrint('🔧 Aplicando ajuste final para residuo: ${lastPayment['remainingCents'] / 100}');
      // Ajuste final para eliminar cualquier residuo
      final adjustment = lastPayment['remainingCents'] as int;
      schedule.last['principalCents'] = (lastPayment['principalCents'] as int) + adjustment;
      schedule.last['paymentCents'] = (lastPayment['paymentCents'] as int) + adjustment;
      schedule.last['remainingCents'] = 0;
    }
  }

  debugPrint('✅ Cronograma generado: ${schedule.length} pagos, Saldo final: ${schedule.isNotEmpty ? schedule.last['remainingCents'] / 100 : 0}');

  return schedule;
}


 void _calculateLoanDetails(double amount, double interestRatePercent, int termValue) {
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

  debugPrint('🔄 Calculando detalles del préstamo...');
  debugPrint('   Monto: $amount, Tasa: $interestRatePercent%, Plazo: $n, Frecuencia: $_paymentFrequency');

  // ✅ GENERAR EL CRONOGRAMA
  final schedule = buildAnnuitySchedule(
    principal: amount,
    annualRatePercent: interestRatePercent,
    numberOfPayments: n,
    frequency: _paymentFrequency,
    startDate: _startDate,
  );

  debugPrint('   Cronograma generado: ${schedule.length} pagos');

  // ✅ ASIGNAR PRIMERO EL CRONOGRAMA
  setState(() {
    _amortizationSchedule = schedule;
  });

  // ✅ LUEGO VALIDAR Y CORREGIR
  _validateAndCorrectSchedule();

  // ✅ RECALCULAR TOTALES DESPUÉS DE LA CORRECCIÓN
  final int totalInterestCents = _amortizationSchedule.fold<int>(0, (s, e) => s + (e['interestCents'] as int));
  final int totalPaidCents = _amortizationSchedule.fold<int>(0, (s, e) => s + (e['paymentCents'] as int));
  final List<DateTime> dates = _amortizationSchedule.map((e) => _normalizeDate(e['date'] as DateTime)).toList();

  setState(() {
    _calculatedInterest = totalInterestCents / 100.0;
    _calculatedTotalToPay = totalPaidCents / 100.0;
    _calculatedPaymentAmount = _amortizationSchedule.isNotEmpty ? (_amortizationSchedule.first['paymentCents'] as int) / 100.0 : 0.0;
    _numberOfPayments = n;
    _paymentDates = dates;
  });

  debugPrint('   Total a pagar: $_calculatedTotalToPay');
  debugPrint('   Fechas de pago: ${_paymentDates.length}');
  debugPrint('   Interés calculado: $_calculatedInterest');

  _updateDueDate();
}

  DateTime _calculateDueDate() {
    final now = _startDate; // ✅ Usa _startDate, no DateTime.now()
    int termValue = int.tryParse(_termValueController.text) ?? 0;

    if (termValue == 0) return now;

    switch (_termUnit) {
      case 'Días':
        return now.add(Duration(days: termValue));
      case 'Semanas':
        return now.add(Duration(days: termValue * 7));
      case 'Quincenas':
        return now.add(Duration(days: termValue * (_use26Quincenas ? 14 : 15)));
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
        _updateCalculations();
      });
    }
  }
  // ✅ NUEVO: Función para validar y corregir el cronograma
  void _validateAndCorrectSchedule() {
    if (_amortizationSchedule.isEmpty) return;
    
    final lastPayment = _amortizationSchedule.last;
    final remainingCents = lastPayment['remainingCents'] as int;
    
    // Si hay residuo, aplicar corrección
    if (remainingCents > 0) {
      debugPrint('🔧 Aplicando corrección para residuo de ${remainingCents / 100}');
      
      // Ajustar la última cuota
      _amortizationSchedule.last['principalCents'] = 
          (_amortizationSchedule.last['principalCents'] as int) + remainingCents;
      _amortizationSchedule.last['paymentCents'] = 
          (_amortizationSchedule.last['paymentCents'] as int) + remainingCents;
      _amortizationSchedule.last['remainingCents'] = 0;
      
      // Recalcular totales
      final totalInterestCents = _amortizationSchedule.fold<int>(0, (s, e) => s + (e['interestCents'] as int));
      final totalPaidCents = _amortizationSchedule.fold<int>(0, (s, e) => s + (e['paymentCents'] as int));
      
      setState(() {
        _calculatedInterest = totalInterestCents / 100.0;
        _calculatedTotalToPay = totalPaidCents / 100.0;
      });
      
      debugPrint('✅ Corrección aplicada. Nuevo saldo: 0.0');
    }
  }

  Future<void> _saveLoan() async {
  if (_formKey.currentState!.validate()) {
    _formKey.currentState!.save();

    debugPrint('🔍 Iniciando guardado de préstamo...');

    String? clientId;
    String? clientName;
    String? phoneNumber;
    String? whatsappNumber;

    if (!_isCreatingNewClient && _selectedClient != null && _selectedClient!.id.isNotEmpty) {
      clientId = _selectedClient!.id;
      clientName = '${_selectedClient!.name} ${_selectedClient!.lastName}';
      phoneNumber = _selectedClient!.phone;
      whatsappNumber = _selectedClient!.whatsapp;
      debugPrint('✅ Cliente existente seleccionado: $clientName');
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
        
        debugPrint('🆕 Creando nuevo cliente: ${newClient.name} ${newClient.lastName}');
        await _clientRepository.createClient(newClient);
        clientId = newClient.id;
        clientName = '${newClient.name} ${newClient.lastName}';
      } else {
        debugPrint('❌ Datos de cliente incompletos');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor, selecciona un cliente o ingresa los datos de uno nuevo.')),
          );
        }
        return;
      }
    }

     final double amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    final double interestRatePercent = double.tryParse(_interestRateController.text) ?? 0.0;
    final int termValue = int.tryParse(_termValueController.text) ?? 1;

    debugPrint('📊 Datos del préstamo: Monto: $amount, Tasa: $interestRatePercent%, Plazo: $termValue');

    // ✅ FORZAR EL CÁLCULO INDEPENDIENTEMENTE
    debugPrint('🔄 Forzando cálculo del cronograma...');
    _calculateLoanDetails(amount, interestRatePercent, termValue);

    // ✅ ESPERAR PARA ASEGURAR QUE EL CÁLCULO SE COMPLETE
    await Future.delayed(const Duration(milliseconds: 100));

    debugPrint('💰 Total a pagar calculado: $_calculatedTotalToPay');
    debugPrint('📅 Fechas de pago: ${_paymentDates.length}');

    // ✅ VERIFICAR QUE LOS CÁLCULOS SEAN VÁLIDOS
    if (_calculatedTotalToPay == 0.0 || _paymentDates.isEmpty) {
      debugPrint('❌ Error: Cálculos no son válidos. Total: $_calculatedTotalToPay, Fechas: ${_paymentDates.length}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error en los cálculos. Verifica los datos e intenta nuevamente.')),
        );
      }
      return;
    }

    final idToUse = widget.loan?.id ?? const Uuid().v4();

    final newLoan = LoanModel(
      id: idToUse,
      clientId: clientId!,
      clientName: clientName!,
      amount: amount,
      interestRate: (interestRatePercent / 100),
      termValue: termValue,
      startDate: _startDate,
      dueDate: _dueDate,
      paymentFrequency: _paymentFrequency,
      termUnit: _termUnit,
      whatsappNumber: whatsappNumber,
      phoneNumber: phoneNumber,
      payments: widget.loan?.payments ?? [],
      remainingBalance: _calculatedTotalToPay, // ✅ Saldo inicial = total a pagar
      totalPaid: widget.loan?.totalPaid ?? 0.0,
      status: 'activo',
      calculatedPaymentAmount: _calculatedPaymentAmount,
      totalAmountToPay: _calculatedTotalToPay,
      paymentDates: _paymentDates,
    );

    debugPrint('💾 Guardando préstamo en repository...');
    
    try {
      await _loanRepository.updateLoan(newLoan);
      debugPrint('✅ Préstamo guardado exitosamente - ID: ${newLoan.id}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Préstamo guardado exitosamente')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Error al guardar préstamo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  } else {
    debugPrint('❌ Validación del formulario falló');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa correctamente el formulario antes de guardar.')),
      );
    }
  }
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
            final int principalCents = (double.tryParse(_amountController.text.replaceAll(',', '')) != null)
                ? (double.parse(_amountController.text.replaceAll(',', '')) * 100).round()
                : 0;
            final DateTime? nextPaymentDate = _amortizationSchedule.isNotEmpty ? _amortizationSchedule.first['date'] as DateTime : null;
            final double firstInterest = _amortizationSchedule.isNotEmpty ? (_amortizationSchedule.first['interestCents'] as int) / 100.0 : 0.0;

            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    flex: 0,
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Card(
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
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _summaryRowSmall('Interés primer periodo', currency.format(firstInterest)),
                              ),
                            ],
                          ),
                        ),
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
                                  subtitle: Text(
                                    '${DateFormat('dd/MM/yyyy').format(e['date'])}\n'
                                    'Interés: ${currency.format(interestPesos)} • Capital: ${currency.format(principalPesos)}',
                                  ),
                                  isThreeLine: true,
                                  trailing: Text(
                                    'Saldo: ${currency.format(remainingPesos)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
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
    final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

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
              Row(
                children: [
                  Expanded(
                    child: _isLoadingClients
                        ? const Center(child: CircularProgressIndicator())
                        : DropdownButtonFormField<Client>(
                            isExpanded: true,
                            value: _selectedClient,
                            decoration: const InputDecoration(
                              labelText: 'Selecciona un cliente existente',
                              border: OutlineInputBorder(),
                            ),
                            items: _clients.map((client) {
                              return DropdownMenuItem(
                                value: client,
                                child: Text(
                                  '${client.name} ${client.lastName}',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (client) {
                              setState(() {
                                _selectedClient = client;
                                _isCreatingNewClient = false;
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
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isCreatingNewClient = true;
                          _selectedClient = null;
                          _clientNameController.clear();
                          _clientLastNameController.clear();
                          _phoneNumberController.clear();
                          _whatsappNumberController.clear();
                        });
                      },
                      child: const Text('Nuevo cliente'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isCreatingNewClient)
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _isCreatingNewClient = false;
                          });
                        },
                        child: const Text('Usar existente'),
                      ),
                    ),
                ],
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
                enabled: _isCreatingNewClient || _selectedClient == null,
                validator: (value) {
                  if ((_isCreatingNewClient || _selectedClient == null) && (value == null || value.isEmpty)) {
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
                enabled: _isCreatingNewClient || _selectedClient == null,
                validator: (value) {
                  if ((_isCreatingNewClient || _selectedClient == null) && (value == null || value.isEmpty)) {
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
              // ✅ Reemplazado TextFormField por InputDecorator + GestureDetector
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Fecha de Inicio del Préstamo',
                  border: OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                child: GestureDetector(
                  onTap: () => _selectStartDate(context),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_startDate),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
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
