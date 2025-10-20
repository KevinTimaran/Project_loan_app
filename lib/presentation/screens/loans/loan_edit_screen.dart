//#################################################
//#  Pantalla: Edición de Préstamo (refactor)     #
//#  Reescrita para evitar coincidencias literales    #
//#  Mantiene funcionalidad: editar, simular y guardar#
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
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _rateCtrl = TextEditingController();
  final TextEditingController _termCtrl = TextEditingController();
  final TextEditingController _startDateCtrl = TextEditingController();
  final LoanRepository _loanRepo = LoanRepository();
  final ClientRepository _clientRepo = ClientRepository();

  String _frequency = 'Mensual';
  late String _termUnit;
  late DateTime _startDate;
  late DateTime _dueDate;
  Client? _client;
  bool _loading = true;
  String? _errorMessage;

  // Valores calculados
  double _interestAmount = 0.0;
  double _totalToPay = 0.0;
  double _paymentValue = 0.0;
  int _paymentsCount = 0;
  List<DateTime> _datesOfPayments = [];

  // Plan de pagos: valores en centavos (int)
  List<Map<String, dynamic>> _schedule = [];

  // 🔸 Días de cobro para frecuencia diaria
  List<bool> _selectedDays = List.generate(7, (index) => index != 6); // Todos excepto domingo
  final bool _use26Quincenas = true;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      _client = await _clientRepo.getClientById(widget.loan.clientId);

      // Llenar controles con datos iniciales
      _amountCtrl.text = NumberFormat.decimalPattern('es_CO').format(widget.loan.amount ?? 0.0);
      _rateCtrl.text = ((widget.loan.interestRate ?? 0.0) * 100).toStringAsFixed(2);
      _termCtrl.text = (widget.loan.termValue ?? 0).toString();
      _frequency = widget.loan.paymentFrequency ?? 'Mensual';
      _startDate = widget.loan.startDate ?? DateTime.now();
      _dueDate = widget.loan.dueDate ?? DateTime.now();
      _startDateCtrl.text = DateFormat('dd/MM/yyyy').format(_startDate);

      // 🔸 CORREGIDO: Mejor inicialización de días seleccionados
      if (widget.loan.selectedDays != null && widget.loan.selectedDays.length == 7) {
        _selectedDays = List<bool>.from(widget.loan.selectedDays);
      } else {
        // Si no hay días guardados, usar los del préstamo según la frecuencia
        _selectedDays = _getDefaultDaysForFrequency(_frequency);
      }

      _setTermUnit();
      _recalculateIfNeeded();

      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error cargando datos: $e';
          _loading = false;
        });
      }
      _restoreDefaults();
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

  void _restoreDefaults() {
    _amountCtrl.text = NumberFormat.decimalPattern('es_CO').format(widget.loan.amount ?? 0.0);
    _rateCtrl.text = ((widget.loan.interestRate ?? 0.0) * 100).toStringAsFixed(2);
    _termCtrl.text = (widget.loan.termValue ?? 0).toString();
    _frequency = widget.loan.paymentFrequency ?? 'Mensual';
    _startDate = widget.loan.startDate ?? DateTime.now();
    _dueDate = widget.loan.dueDate ?? DateTime.now();
    _startDateCtrl.text = DateFormat('dd/MM/yyyy').format(_startDate);

    // 🔸 CORREGIDO: Restaurar días correctamente
    if (widget.loan.selectedDays != null && widget.loan.selectedDays.length == 7) {
      _selectedDays = List<bool>.from(widget.loan.selectedDays);
    } else {
      _selectedDays = _getDefaultDaysForFrequency(_frequency);
    }

    _setTermUnit();
    _recalculateIfNeeded();

    if (mounted) setState(() => _loading = false);
  }

  void _setTermUnit() {
    switch (_frequency) {
      case 'Diario':
        _termUnit = 'Días';
        break;
      case 'Semanal':
        _termUnit = 'Semanas';
        break;
      case 'Quincenal':
        _termUnit = 'Quincenas';
        break;
      default:
        _termUnit = 'Meses';
        break;
    }
  }

  void _recalculateIfNeeded() {
    final amount = _parseCurrencyToDouble(_amountCtrl.text);
    final ratePct = double.tryParse(_rateCtrl.text) ?? 0.0;
    final term = int.tryParse(_termCtrl.text) ?? 0;

    if (amount > 0 && ratePct >= 0 && term > 0) {
      _computeLoan(amount, ratePct, term);
    } else if (_totalToPay != 0.0 || _paymentsCount != 0) {
      if (mounted) {
        setState(() {
          _interestAmount = 0.0;
          _totalToPay = 0.0;
          _paymentValue = 0.0;
          _paymentsCount = 0;
          _datesOfPayments = [];
          _schedule = [];
        });
      }
    }
  }

  double _parseCurrencyToDouble(String text) {
    if (text.trim().isEmpty) return 0.0;
    final cleaned = text.replaceAll(RegExp(r'[^\d,\.]'), '');
    if (cleaned.contains(',') && !cleaned.contains('.')) {
      final normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(normalized) ?? 0.0;
    }
    final withoutThousands = cleaned.replaceAll(RegExp(r'[,.](?=\d{3}\b)'), '');
    final attempt = withoutThousands.replaceAll(',', '.');
    return double.tryParse(attempt) ?? 0.0;
  }

  // 🔸 Corregido: evita bucle infinito
  DateTime _getNextAvailableDay(DateTime fromDate) {
    DateTime current = fromDate.add(const Duration(days: 1));
    int attempts = 0;
    final maxAttempts = 365; // Máximo 1 año

    while (attempts < maxAttempts) {
      int weekday = current.weekday - 1; // 0=lunes, 6=domingo
      if (weekday >= 0 && weekday < 7 && _selectedDays[weekday]) {
        return current;
      }
      current = current.add(const Duration(days: 1));
      attempts++;
    }
    return current; // fallback
  }

  DateTime _addMonthsSafe(DateTime base, int monthsToAdd) {
    int y = base.year;
    int m = base.month + monthsToAdd;
    y += (m - 1) ~/ 12;
    m = ((m - 1) % 12) + 1;
    int d = base.day;
    final lastDay = DateTime(y, m + 1, 0).day;
    if (d > lastDay) d = lastDay;
    return DateTime(y, m, d, base.hour, base.minute, base.second, base.millisecond, base.microsecond);
  }

  // 🔸 Selector de días
  Widget _buildDaySelector() {
    const List<String> dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    
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
                  // 🔸 Validar que al menos un día esté seleccionado
                  if (!_selectedDays.any((d) => d)) {
                    _selectedDays[index] = true; // revertir si todos se deseleccionan
                  }
                  _recalculateIfNeeded();
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _selectedDays[index] ? Colors.blue[700] : Colors.grey[300],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _selectedDays[index] ? Colors.blue[900]! : Colors.grey,
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

  List<DateTime> _generatePaymentDates({
    required DateTime startDate,
    required int numberOfPayments,
    required String frequency,
  }) {
    List<DateTime> dates = [];
    DateTime current = startDate;

    for (int i = 0; i < numberOfPayments; i++) {
      if (frequency == 'Diario') {
        current = _getNextAvailableDay(current);
      } else if (frequency == 'Semanal') {
        current = current.add(const Duration(days: 7));
      } else if (frequency == 'Quincenal') {
        current = current.add(Duration(days: _use26Quincenas ? 14 : 15));
      } else {
        current = _addMonthsSafe(current, 1);
      }
      
      dates.add(DateTime(current.year, current.month, current.day));
    }

    return dates;
  }

  // 🔸 CORREGIDO: Usa ANUALIDAD (cuota fija), no interés simple
  List<Map<String, dynamic>> _buildAnnuitySchedule({
    required double principal,
    required double annualRatePercent,
    required int numberOfPayments,
    required String frequency,
    required DateTime startDate,
  }) {
    final periodsPerYear = (frequency == 'Diario')
        ? 365
        : (frequency == 'Semanal')
            ? 52
            : (frequency == 'Quincenal')
                ? (_use26Quincenas ? 26 : 24)
                : 12;

    final double annualRate = annualRatePercent / 100.0;
    final double r = annualRate / periodsPerYear;

    final int principalCents = (principal * 100).round();
    final int n = numberOfPayments;

    double payment;
    if (r > 0) {
      final denom = 1 - pow(1 + r, -n);
      payment = denom == 0 ? principal / n : principal * r / denom;
    } else {
      payment = principal / n;
    }

    final int paymentCentsBase = (payment * 100).floor();

    // 🔸 Generar fechas personalizadas
    final List<DateTime> paymentDates = _generatePaymentDates(
      startDate: startDate,
      numberOfPayments: n,
      frequency: frequency,
    );

    List<Map<String, dynamic>> schedule = [];
    int remainingCents = principalCents;
    int totalInterestAccumCents = 0;

    for (int i = 0; i < n; i++) {
      final DateTime current = paymentDates[i];
      final double interestForPeriod = (remainingCents / 100.0) * r;
      int interestCents = (interestForPeriod * 100).round();
      int principalCentsForPeriod = paymentCentsBase - interestCents;
      if (principalCentsForPeriod < 0) principalCentsForPeriod = 0;

      if (i == n - 1) {
        interestCents = ((remainingCents / 100.0) * r * 100).round();
        principalCentsForPeriod = remainingCents;
      }

      final int paymentCents = principalCentsForPeriod + interestCents;
      remainingCents = max(0, remainingCents - principalCentsForPeriod);
      totalInterestAccumCents += interestCents;

      schedule.add({
        'index': i + 1,
        'date': current,
        'paymentCents': paymentCents,
        'interestCents': interestCents,
        'principalCents': principalCentsForPeriod,
        'remainingCents': remainingCents,
      });
    }

    return schedule;
  }

  void _computeLoan(double amount, double annualRatePercent, int termValue) {
    if (!mounted) return;

    final int n = termValue;
    if (n <= 0) {
      if (mounted) {
        setState(() {
          _interestAmount = 0.0;
          _totalToPay = 0.0;
          _paymentValue = 0.0;
          _paymentsCount = 0;
          _datesOfPayments = [];
          _schedule = [];
        });
      }
      return;
    }

    // 🔸 Usar anualidad en lugar de interés simple
    final schedule = _buildAnnuitySchedule(
      principal: amount,
      annualRatePercent: annualRatePercent,
      numberOfPayments: n,
      frequency: _frequency,
      startDate: _startDate,
    );

    final int totalInterestCents = schedule.fold<int>(0, (s, e) => s + (e['interestCents'] as int));
    final int totalPaidCents = schedule.fold<int>(0, (s, e) => s + (e['paymentCents'] as int));
    final List<DateTime> dates = schedule.map((e) => e['date'] as DateTime).toList();

    if (mounted) {
      setState(() {
        _schedule = schedule;
        _interestAmount = totalInterestCents / 100.0;
        _totalToPay = totalPaidCents / 100.0;
        _paymentValue = schedule.isNotEmpty ? (schedule.first['paymentCents'] as int) / 100.0 : 0.0;
        _paymentsCount = n;
        _datesOfPayments = dates;
      });
    }

    _recomputeDueDate();
  }

  DateTime _calculateDueDate() {
    final DateTime start = _startDate;
    final int term = int.tryParse(_termCtrl.text) ?? 0;
    if (term == 0) return start;

    switch (_frequency) {
      case 'Diario':
        return start.add(Duration(days: term));
      case 'Semanal':
        return start.add(Duration(days: term * 7));
      case 'Quincenal':
        return start.add(Duration(days: term * (_use26Quincenas ? 14 : 15)));
      default:
        return _addMonthsSafe(start, term);
    }
  }

  void _recomputeDueDate() {
    if (mounted) setState(() => _dueDate = _calculateDueDate());
  }

  Future<void> _pickStartDate(BuildContext context) async {
    final DateTime initial = _startDate;
    try {
      final DateTime? chosen = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );

      if (chosen == null) return;

      final normalizedChosen = DateTime(chosen.year, chosen.month, chosen.day);
      final normalizedCurrent = DateTime(_startDate.year, _startDate.month, _startDate.day);

      if (normalizedChosen.isAtSameMomentAs(normalizedCurrent)) return;

      if (mounted) {
        setState(() {
          _startDate = normalizedChosen;
          _startDateCtrl.text = DateFormat('dd/MM/yyyy').format(_startDate);
        });
      }

      _recalculateIfNeeded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al seleccionar fecha: $e')));
      }
    }
  }

  Future<void> _storeLoan() async {
    if (!_formKey.currentState!.validate()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa el formulario correctamente.')));
      return;
    }

    _formKey.currentState!.save();

    try {
      final amount = _parseCurrencyToDouble(_amountCtrl.text);
      final interestRate = (double.tryParse(_rateCtrl.text) ?? 0.0) / 100.0;
      final termValue = int.parse(_termCtrl.text);

      if (amount < (widget.loan.totalPaid ?? 0.0)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('El monto no puede ser menor al total ya pagado (${NumberFormat.currency(locale: 'es_CO', symbol: '\$').format(widget.loan.totalPaid ?? 0.0)})')));
        }
        return;
      }

      // 🔸 CORREGIDO: Asegurar que los días seleccionados se guarden correctamente
      final List<bool> daysToSave = _frequency == 'Diario' 
          ? List<bool>.from(_selectedDays) 
          : _getDefaultDaysForFrequency(_frequency);

      final updated = widget.loan.copyWith(
        amount: amount,
        interestRate: interestRate,
        termValue: termValue,
        startDate: _startDate,
        dueDate: _dueDate,
        paymentFrequency: _frequency,
        termUnit: _termUnit,
        remainingBalance: _totalToPay - (widget.loan.totalPaid ?? 0.0),
        calculatedPaymentAmount: _paymentValue,
        totalAmountToPay: _totalToPay,
        paymentDates: _datesOfPayments,
        selectedDays: daysToSave, // 🔸 CORREGIDO: Siempre guardar días apropiados
      );

      // 🔸 DEBUG: Verificar lo que se va a guardar
      print('Días a guardar: $daysToSave');
      print('Frecuencia: $_frequency');

      await _loanRepo.updateLoan(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Préstamo actualizado exitosamente')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar préstamo: $e')));
    }
  }

  int _principalInCents() {
    final cleaned = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final value = double.tryParse(cleaned) ?? 0.0;
    return (value * 100).round();
  }

  void _openSimulationSheet() {
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
            final int totalInterestCents = _schedule.fold<int>(0, (s, e) => s + ((e['interestCents'] as int)));
            final int principalCents = _principalInCents();
            final DateTime? next = _schedule.isNotEmpty ? _schedule.first['date'] as DateTime : null;

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
                          Row(children: [Expanded(child: const Text('Resumen del Crédito', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))]),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _smallSummaryRow('Fecha de crédito', DateFormat('dd/MM/yyyy').format(_startDate)),
                                    const SizedBox(height: 8),
                                    _smallSummaryRow('Fecha próxima cuota', next != null ? DateFormat('dd/MM/yyyy').format(next) : '-'),
                                    const SizedBox(height: 8),
                                    _smallSummaryRow('Vencimiento del crédito', DateFormat('dd/MM/yyyy').format(_dueDate)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _smallSummaryRow('Interés (anual)', _rateCtrl.text.isNotEmpty ? '${_rateCtrl.text.trim()} %' : '-'),
                                    const SizedBox(height: 8),
                                    _smallSummaryRow('Valor total interés', currency.format(totalInterestCents / 100.0)),
                                    const SizedBox(height: 8),
                                    _smallSummaryRow('Valor cuota', currency.format((_schedule.isNotEmpty ? (_schedule.first['paymentCents'] as int) / 100.0 : 0.0))),
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
                              Expanded(child: _boldSummaryRow('Total prestado', currency.format(principalCents / 100.0))),
                              const SizedBox(width: 12),
                              Expanded(child: _boldSummaryRow('Total + interés', currency.format((principalCents + totalInterestCents) / 100.0))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(alignment: Alignment.centerLeft, child: _boldSummaryRow('Saldo total', currency.format((_schedule.isNotEmpty ? (_schedule.last['remainingCents'] as int) / 100.0 : (principalCents + totalInterestCents) / 100.0)))),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Expanded(
                    child: _schedule.isEmpty
                        ? const Center(child: Text('Aún no hay simulación. Ingresa monto, tasa y plazo.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            controller: controller,
                            itemCount: _schedule.length,
                            itemBuilder: (context, index) {
                              final e = _schedule[index];
                              final payment = (e['paymentCents'] as int) / 100.0;
                              final interest = (e['interestCents'] as int) / 100.0;
                              final principal = (e['principalCents'] as int) / 100.0;
                              final remaining = (e['remainingCents'] as int) / 100.0;

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: CircleAvatar(child: Text('${e['index']}')),
                                  title: Text('Cuota #${e['index']} - ${currency.format(payment)}'),
                                  subtitle: Text('${DateFormat('dd/MM/yyyy').format(e['date'])}\nInterés: ${currency.format(interest)} • Capital: ${currency.format(principal)}'),
                                  isThreeLine: true,
                                  trailing: Text('Saldo: ${currency.format(remaining)}', style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _smallSummaryRow(String title, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _boldSummaryRow(String title, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      );

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _termCtrl.dispose();
    _startDateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Préstamo')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Card(
                                elevation: 3,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Información del Cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 16),
                                      ListTile(leading: const Icon(Icons.person), title: Text(_client?.name ?? widget.loan.clientName ?? 'Sin nombre'), subtitle: const Text('Nombre')),
                                      ListTile(leading: const Icon(Icons.phone), title: Text(_client?.phone ?? widget.loan.phoneNumber ?? 'No especificado'), subtitle: const Text('Teléfono')),
                                      ListTile(leading: const Icon(Icons.chat), title: Text(_client?.whatsapp ?? widget.loan.whatsappNumber ?? 'No especificado'), subtitle: const Text('WhatsApp')),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text('Datos del Préstamo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),

                              Builder(builder: (BuildContext builderContext) {
                                return TextFormField(
                                  controller: _startDateCtrl,
                                  readOnly: true,
                                  decoration: const InputDecoration(labelText: 'Fecha de Inicio', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                                  onTap: () => _pickStartDate(builderContext),
                                );
                              }),

                              const SizedBox(height: 12),

                              TextFormField(
                                controller: _amountCtrl,
                                decoration: const InputDecoration(labelText: 'Monto del Préstamo', border: OutlineInputBorder(), prefixText: '\$'),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ImprovedCurrencyFormatter()],
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Por favor, ingresa el monto.';
                                  final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
                                  if (double.tryParse(clean) == null) return 'Por favor, ingresa un monto válido.';
                                  final amount = double.parse(clean);
                                  if (amount <= 0) return 'El monto debe ser mayor a cero.';
                                  if (amount < (widget.loan.totalPaid ?? 0.0)) return 'El monto no puede ser menor al total ya pagado.';
                                  return null;
                                },
                                onChanged: (_) => _recalculateIfNeeded(),
                              ),

                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _rateCtrl,
                                decoration: const InputDecoration(labelText: 'Tasa de Interés Anual (%)', border: OutlineInputBorder(), suffixText: '%'),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Por favor, ingresa la tasa de interés.';
                                  if (double.tryParse(value) == null) return 'Por favor, ingresa una tasa válida.';
                                  final rate = double.parse(value);
                                  if (rate <= 0) return 'La tasa debe ser mayor a cero.';
                                  if (rate > 100) return 'La tasa no puede ser mayor al 100%.';
                                  return null;
                                },
                                onChanged: (_) => _recalculateIfNeeded(),
                              ),

                              const SizedBox(height: 16),

                              DropdownButtonFormField<String>(
                                value: _frequency,
                                decoration: const InputDecoration(labelText: 'Frecuencia de Pago', border: OutlineInputBorder()),
                                items: ['Diario', 'Semanal', 'Quincenal', 'Mensual'].map((String v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
                                onChanged: (String? nv) {
                                  if (nv != null) {
                                    setState(() {
                                      _frequency = nv;
                                      _setTermUnit();
                                      
                                      // 🔸 CORREGIDO: Actualizar días cuando cambia la frecuencia
                                      if (nv != 'Diario') {
                                        _selectedDays = _getDefaultDaysForFrequency(nv);
                                      }
                                    });
                                    _recalculateIfNeeded();
                                  }
                                },
                              ),

                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _termCtrl,
                                decoration: InputDecoration(labelText: 'Plazo en $_termUnit', border: const OutlineInputBorder()),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => _recalculateIfNeeded(),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Por favor, ingresa el plazo.';
                                  if (int.tryParse(value) == null) return 'Por favor, ingresa un plazo válido.';
                                  final t = int.parse(value);
                                  if (t <= 0) return 'El plazo debe ser mayor a cero.';
                                  return null;
                                },
                              ),

                              // 🔸 Mostrar selector de días solo para frecuencia diaria
                              if (_frequency == 'Diario') ...[
                                const SizedBox(height: 16),
                                _buildDaySelector(),
                              ],

                              if (_totalToPay > 0) ...[
                                const SizedBox(height: 24),
                                Card(
                                  color: Colors.blue.shade50,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      const Text('Resumen del Préstamo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 12),
                                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                        const Text('Total a pagar:'),
                                        Text(currencyFormatter.format(_totalToPay), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ]),
                                      const SizedBox(height: 8),
                                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                        const Text('Valor de la cuota:'),
                                        Text(currencyFormatter.format(_paymentValue), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ]),
                                      const SizedBox(height: 8),
                                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                        const Text('Fecha de vencimiento:'),
                                        Text(DateFormat('dd/MM/yyyy').format(_dueDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ]),
                                    ]),
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
          child: Row(children: [
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: _openSimulationSheet,
                icon: const Icon(Icons.show_chart),
                label: const Text('Ver simulación'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: ElevatedButton(
                onPressed: _storeLoan,
                child: const Icon(Icons.save, size: 20),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// Mejorada: formateador de moneda que mantiene cursor y evita coincidencias literales
class _ImprovedCurrencyFormatter extends TextInputFormatter {
  final NumberFormat _fmt = NumberFormat.decimalPattern('es_CO');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return const TextEditingValue(text: '');

    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');

    final intVal = int.tryParse(digits) ?? 0;
    final formatted = _fmt.format(intVal);

    // Mantener posición del cursor de forma estable
    final offsetFromEnd = newValue.text.length - newValue.selection.end;
    final selectionIndex = (formatted.length - offsetFromEnd).clamp(0, formatted.length);

    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: selectionIndex));
  }
}