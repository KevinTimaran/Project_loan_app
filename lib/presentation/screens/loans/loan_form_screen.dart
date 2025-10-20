// lib/presentation/screens/loans/loan_form_screen.dart
//#################################################
//#  Pantalla de Formulario de Préstamo           #
//#  CON SISTEMA DE INTERÉS ANTICIPADO            #
//#################################################

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
import 'package:loan_app/domain/entities/client.dart';
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
  DateTime _startDate = DateTime.now();
  late DateTime _dueDate;
  Client? _selectedClient;
  List<Client> _clients = [];
  bool _isLoadingClients = false;
  bool _isCreatingNewClient = false;
  final bool _use26Quincenas = true;

  // 🆕 NUEVO: Días de la semana seleccionados para frecuencia diaria
  List<bool> _selectedDays = List.generate(7, (index) => index != 6); // Todos excepto domingo

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
  _dueDate = loan.dueDate;
  _paymentDates = loan.paymentDates ?? [];
  _calculatedTotalToPay = loan.totalAmountToPay ?? _calculatedTotalToPay;
  _calculatedPaymentAmount = loan.calculatedPaymentAmount ?? _calculatedPaymentAmount;
  _calculatedInterest = (loan.totalAmountToPay ?? 0.0) - (loan.amount);
  _numberOfPayments = loan.termValue;
  _amortizationSchedule = [];

  // 🔸 CORREGIDO: Cargar días seleccionados del préstamo existente
  if (loan.selectedDays != null && loan.selectedDays.length == 7) {
    _selectedDays = List<bool>.from(loan.selectedDays);
  } else {
    // Si no hay días guardados, usar los por defecto para la frecuencia
    _selectedDays = _getDefaultDaysForFrequency(_paymentFrequency);
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

  List<bool> _getDefaultDaysForFrequency(String frequency) {
  switch (frequency) {
    case 'Diario':
      // Para frecuencia diaria, todos los días excepto domingo
      return List.generate(7, (index) => index != 6);
    case 'Semanal':
      // Para semanal, solo lunes
      return List.generate(7, (index) => index == 0);
    case 'Quincenal':
      // Para quincenal, días 1 y 15 (simulado como lunes)
      return List.generate(7, (index) => index == 0);
    default: // Mensual
      // Para mensual, solo el día 1 (simulado como lunes)
      return List.generate(7, (index) => index == 0);
  }
}


  List<DateTime> _generatePaymentDates({
    required DateTime startDate,
    required int numberOfPayments,
    required String frequency,
  }) {
    List<DateTime> dates = [];
    DateTime current = startDate;

    for (int i = 0; i < numberOfPayments; i++) {
      if (frequency == 'Diario') {
        // Para frecuencia diaria, considerar solo días seleccionados
        current = _getNextAvailableDay(current);
      } else if (frequency == 'Semanal') {
        current = current.add(const Duration(days: 7));
      } else if (frequency == 'Quincenal') {
        current = current.add(Duration(days: _use26Quincenas ? 14 : 15));
      } else {
        current = addMonthsSafe(current, 1);
      }
      
      dates.add(DateTime(current.year, current.month, current.day));
    }

    return dates;
  }

  /// 🆕 NUEVO: Encontrar el próximo día disponible basado en días seleccionados
  DateTime _getNextAvailableDay(DateTime fromDate) {
    DateTime current = fromDate.add(const Duration(days: 1));
    
    while (true) {
      int weekday = current.weekday - 1; // DateTime: 1=lunes, 7=domingo -> Convertir a 0-6
      if (_selectedDays[weekday]) {
        return current;
      }
      current = current.add(const Duration(days: 1));
    }
  }

  /// 🆕 NUEVO: Selector de días de la semana
 Widget _buildDaySelector() {
  const List<String> dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']; // 🔸 CORREGIDO: 'sab' -> 'Dom'
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Días de cobro:',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDays[index] = !_selectedDays[index];
                _updateCalculations(); // Recalcular cuando cambian los días
              });
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _selectedDays[index] ? Colors.blue[700] : Colors.grey[300],
                shape: BoxShape.circle,
                border: Border.all(
                  color: _selectedDays[index] ? Colors.blue[900]! : Colors.grey[500]!,
                ),
              ),
              child: Center(
                child: Text(
                  dayNames[index],
                  style: TextStyle(
                    color: _selectedDays[index] ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 8),
      Text(
        'Días seleccionados: ${_selectedDays.where((day) => day).length}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    ],
  );
}

  /// SISTEMA: INTERÉS ANTICIPADO
  List<Map<String, dynamic>> buildAnticipatedInterestSchedule({
    required double principal,
    required double annualRatePercent,
    required int numberOfPayments,
    required String frequency,
    required DateTime startDate,
  }) {
    debugPrint('🔄 Iniciando buildAnticipatedInterestSchedule...');
    debugPrint('   Principal: $principal, Tasa: $annualRatePercent%, Pagos: $numberOfPayments, Frecuencia: $frequency');

    // CÁLCULO DE INTERÉS ANTICIPADO
    final double interestAmount = principal * (annualRatePercent / 100);
    final double totalToPay = principal + interestAmount;
    final double paymentAmount = totalToPay / numberOfPayments;

    debugPrint('   Interés total: $interestAmount, Total a pagar: $totalToPay, Cuota: $paymentAmount');

    List<Map<String, dynamic>> schedule = [];
    
    // 🆕 MODIFICADO: Usar el nuevo método para generar fechas
    final List<DateTime> paymentDates = _generatePaymentDates(
      startDate: startDate,
      numberOfPayments: numberOfPayments,
      frequency: frequency,
    );

    for (int i = 0; i < numberOfPayments; i++) {
      final DateTime paymentDate = paymentDates[i];

      // EN INTERÉS ANTICIPADO: cada cuota paga la misma cantidad de capital e interés
      final double principalPortion = principal / numberOfPayments;
      final double interestPortion = interestAmount / numberOfPayments;
      
      // Calcular saldo restante (solo capital)
      final double remainingPrincipal = principal - (principalPortion * (i + 1));
      
      // Convertir a centavos para precisión
      final int paymentCents = (paymentAmount * 100).round();
      final int interestCents = (interestPortion * 100).round();
      final int principalCents = (principalPortion * 100).round();
      final int remainingCents = (remainingPrincipal * 100).round();

      schedule.add({
        'index': i + 1,
        'date': paymentDate,
        'paymentCents': paymentCents,
        'interestCents': interestCents,
        'principalCents': principalCents,
        'remainingCents': remainingCents,
      });

      debugPrint('   Cuota ${i + 1}: Pago: ${paymentCents / 100}, Capital: ${principalCents / 100}, Interés: ${interestCents / 100}, Saldo: ${remainingCents / 100}');
    }

    debugPrint('✅ Cronograma de interés anticipado generado: ${schedule.length} pagos');
    return schedule;
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

    debugPrint('🔄 Calculando detalles del préstamo (INTERÉS ANTICIPADO)...');
    debugPrint('   Monto: $amount, Tasa: $interestRatePercent%, Plazo: $n, Frecuencia: $_paymentFrequency');

    // USAR EL NUEVO SISTEMA DE INTERÉS ANTICIPADO
    final schedule = buildAnticipatedInterestSchedule(
      principal: amount,
      annualRatePercent: interestRatePercent,
      numberOfPayments: n,
      frequency: _paymentFrequency,
      startDate: _startDate,
    );

    debugPrint('   Cronograma generado: ${schedule.length} pagos');

    // Calcular totales
    final int totalInterestCents = schedule.fold<int>(0, (s, e) => s + (e['interestCents'] as int));
    final int totalPaidCents = schedule.fold<int>(0, (s, e) => s + (e['paymentCents'] as int));
    final List<DateTime> dates = schedule.map((e) => _normalizeDate(e['date'] as DateTime)).toList();

    setState(() {
      _amortizationSchedule = schedule;
      _calculatedInterest = totalInterestCents / 100.0;
      _calculatedTotalToPay = totalPaidCents / 100.0;
      _calculatedPaymentAmount = schedule.isNotEmpty ? (schedule.first['paymentCents'] as int) / 100.0 : 0.0;
      _numberOfPayments = n;
      _paymentDates = dates;
    });

    debugPrint('   Total a pagar: $_calculatedTotalToPay');
    debugPrint('   Interés total: $_calculatedInterest');
    debugPrint('   Cuota fija: $_calculatedPaymentAmount');

    _updateDueDate();
  }

  DateTime _calculateDueDate() {
    final now = _startDate;
    int termValue = int.tryParse(_termValueController.text) ?? 0;

    if (termValue == 0) return now;

    switch (_termUnit) {
      case 'Días':
        // Para días, usar la última fecha de pago del cronograma
        return _paymentDates.isNotEmpty ? _paymentDates.last : now.add(Duration(days: termValue));
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

 Future<void> _saveLoan() async {
  if (_formKey.currentState!.validate()) {
    _formKey.currentState!.save();

    debugPrint('🔍 Iniciando guardado de préstamo (INTERÉS ANTICIPADO)...');

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

    // 🔸 CORREGIDO: Preparar días seleccionados para guardar
    final List<bool> daysToSave;
    if (_paymentFrequency == 'Diario') {
      daysToSave = List<bool>.from(_selectedDays);
      debugPrint('📅 Guardando días personalizados: $daysToSave');
    } else {
      daysToSave = _getDefaultDaysForFrequency(_paymentFrequency);
      debugPrint('📅 Guardando días por defecto para $_paymentFrequency: $daysToSave');
    }

    // Forzar cálculo
    _calculateLoanDetails(amount, interestRatePercent, termValue);
    await Future.delayed(const Duration(milliseconds: 100));

    debugPrint('💰 Total a pagar calculado: $_calculatedTotalToPay');

    if (_calculatedTotalToPay == 0.0 || _paymentDates.isEmpty) {
      debugPrint('❌ Error: Cálculos no son válidos.');
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
      remainingBalance: _calculatedTotalToPay,
      totalPaid: widget.loan?.totalPaid ?? 0.0,
      status: 'activo',
      calculatedPaymentAmount: _calculatedPaymentAmount,
      totalAmountToPay: _calculatedTotalToPay,
      paymentDates: _paymentDates,
      selectedDays: daysToSave, // 🔸 CORREGIDO: Incluir días seleccionados
    );

    // 🔸 DEBUG: Verificar que los días se están guardando
    debugPrint('💾 Días que se guardarán en el préstamo: ${newLoan.selectedDays}');
    
    try {
      await _loanRepository.updateLoan(newLoan);
      debugPrint('✅ Préstamo guardado exitosamente - ID: ${newLoan.id}');
      debugPrint('✅ Días guardados: ${newLoan.selectedDays}');

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
                                  Expanded(
                                    child: Text(
                                      'Resumen del Crédito', 
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Colors.blue[700], // 🟦 Cambiado a azul
                                        fontWeight: FontWeight.bold
                                      ) ?? const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                                    ),
                                  ),
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
                                        _summaryRowSmall('Valor total interés', currency.format(totalInterestCents / 100.0)),
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
                              // 🆕 ELIMINADO: Se quitó la fórmula de aquí
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
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue[50], // 🟦 Cambiado a azul
                                    child: Text('${e['index']}', style: TextStyle(color: Colors.blue[700])), // 🟦 Cambiado a azul
                                  ),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.loan == null ? 'Registrar Préstamo' : 'Editar Préstamo'),
        backgroundColor: Colors.blue[700], // 🟦 Cambiado a azul
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
                      
                      // 🔸 CORREGIDO: Actualizar días seleccionados cuando cambia la frecuencia
                      if (newValue != 'Diario') {
                        _selectedDays = _getDefaultDaysForFrequency(newValue);
                      }
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

              // 🆕 NUEVO: Selector de días para frecuencia diaria
              if (_paymentFrequency == 'Diario') ...[
                const SizedBox(height: 16),
                _buildDaySelector(),
              ],

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
                    backgroundColor: Colors.blue[700], // 🟦 Cambiado a azul
                    foregroundColor: Colors.white,
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
                    backgroundColor: Colors.blue[700], // 🟦 Cambiado a azul
                    foregroundColor: Colors.white,
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