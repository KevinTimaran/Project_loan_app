// lib/presentation/screens/loans/simulator_screen.dart
// Simulador con Sistema de Interés Anticipado
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _rateCtrl = TextEditingController();
  final TextEditingController _termCtrl = TextEditingController();
  DateTime _startDate = DateTime.now();

  // UI state
  String _frequency = 'Mensual';
  final List<String> _frequencies = ['Diario', 'Semanal', 'Quincenal', 'Mensual'];
  
  List<bool> _selectedDays = List.generate(7, (index) => index != 6); // Todos excepto domingo

  List<Map<String, dynamic>> _schedule = [];
  double _totalInterest = 0.0;
  double _totalPaid = 0.0;
  double _fixedPayment = 0.0;

  // Formatters
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 2);
  final NumberFormat _decimalPattern = NumberFormat.decimalPattern('es_CO');
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_formatAmountWithThousandsSeparator);
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_formatAmountWithThousandsSeparator);
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _termCtrl.dispose();
    super.dispose();
  }

  // Formatea el texto del monto para mostrar separador de miles (es_CO).
  void _formatAmountWithThousandsSeparator() {
    final text = _amountCtrl.text;
    if (text.isEmpty) return;

    final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      _amountCtrl.value = TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
      return;
    }

    final value = int.tryParse(digitsOnly) ?? 0;
    final formatted = _decimalPattern.format(value);

    if (formatted != text) {
      _amountCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  int _periodsPerYear(String freq) {
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
        current = current.add(const Duration(days: 15));
      } else {
        current = addMonthsSafe(current, 1);
      }
      
      dates.add(DateTime(current.year, current.month, current.day));
    }

    return dates;
  }

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
                  _simulate(); // Recalcular cuando cambian los días
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _selectedDays[index] ? Colors.blue[700] : Colors.grey[300],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _selectedDays[index] ? Colors.blue[900]! : Colors.grey[500]!
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
  /// Fórmula: Monto final = Principal + (Principal × Tasa)
  Map<String, dynamic> _generateAnticipatedInterestSchedule({
    required double amount,
    required double annualRatePercent,
    required int term,
    required DateTime startDate,
    required String frequency,
  }) {
    final List<DateTime> dates = [];
    final List<double> installments = [];
    final List<double> interests = [];
    final List<double> principals = [];
    final List<double> remainings = [];
    
    if (term <= 0) {
      return {
        'dates': dates, 
        'installments': installments, 
        'interests': interests,
        'principals': principals,
        'remainings': remainings,
        'total': 0.0,
        'fixedPayment': 0.0
      };
    }

    //  CÁLCULO DE INTERÉS ANTICIPADO
    final double interestAmount = amount * (annualRatePercent / 100);
    final double totalToPay = amount + interestAmount;
    final double paymentAmount = totalToPay / term;

    //  MODIFICADO: Usar el nuevo método para generar fechas
    final List<DateTime> paymentDates = _generatePaymentDates(
      startDate: startDate,
      numberOfPayments: term,
      frequency: frequency,
    );

    for (int i = 0; i < term; i++) {
      final DateTime paymentDate = paymentDates[i];

      // EN INTERÉS ANTICIPADO: cada cuota paga la misma cantidad de capital e interés
      final double principalPortion = amount / term;
      final double interestPortion = interestAmount / term;
      
      // Calcular saldo restante (solo capital)
      final double remainingPrincipal = amount - (principalPortion * (i + 1));
      
      // Convertir a centavos para precisión
      final int paymentCents = (paymentAmount * 100).round();
      final int interestCents = (interestPortion * 100).round();
      final int principalCents = (principalPortion * 100).round();
      final int remainingCents = (remainingPrincipal * 100).round();

      dates.add(paymentDate);
      installments.add(paymentCents / 100.0);
      interests.add(interestCents / 100.0);
      principals.add(principalCents / 100.0);
      remainings.add(remainingCents / 100.0);
    }

    final double totalToPayCalculated = paymentAmount * term;
    return {
      'dates': dates,
      'installments': installments,
      'interests': interests,
      'principals': principals,
      'remainings': remainings,
      'total': totalToPayCalculated,
      'fixedPayment': paymentAmount
    };
  }

  DateTime addMonthsSafe(DateTime date, int monthsToAdd) {
    int year = date.year;
    int month = date.month + monthsToAdd;
    year += (month - 1) ~/ 12;
    month = ((month - 1) % 12) + 1;
    int day = date.day;
    int lastDayOfMonth = DateTime(year, month + 1, 0).day;
    if (day > lastDayOfMonth) day = lastDayOfMonth;
    return DateTime(year, month, day);
  }

  void _simulate() {
    if (!_formKey.currentState!.validate()) return;

    // Parsear monto: extraer dígitos y construir double de pesos
    final amountDigits = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final principal = double.tryParse(amountDigits) ?? 0.0;

    final rate = double.tryParse(_rateCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final term = int.tryParse(_termCtrl.text) ?? 0;

    if (principal <= 0 || term <= 0) return;

    //  Generar cronograma usando interés anticipado
    final res = _generateAnticipatedInterestSchedule(
      amount: principal,
      annualRatePercent: rate,
      term: term,
      startDate: DateTime(_startDate.year, _startDate.month, _startDate.day),
      frequency: _frequency,
    );

    final List<DateTime> dates = (res['dates'] as List<DateTime>);
    final List<double> installments = (res['installments'] as List<double>);
    final List<double> interests = (res['interests'] as List<double>);
    final List<double> principals = (res['principals'] as List<double>);
    final List<double> remainings = (res['remainings'] as List<double>);
    final double totalToPay = (res['total'] as double);
    final double fixedPayment = (res['fixedPayment'] as double);

    // Construir estructura de schedule
    final List<Map<String, dynamic>> schedule = [];
    for (int i = 0; i < installments.length; i++) {
      schedule.add({
        'index': i + 1,
        'date': dates[i],
        'payment': installments[i],
        'interest': interests[i],
        'principal': principals[i],
        'remaining': remainings[i],
      });
    }

    final totalInterest = totalToPay - principal;
    setState(() {
      _schedule = schedule;
      _totalInterest = totalInterest;
      _totalPaid = totalToPay;
      _fixedPayment = fixedPayment;
    });
  }

  void _reset() {
    setState(() {
      _amountCtrl.clear();
      _rateCtrl.clear();
      _termCtrl.clear();
      _frequency = 'Mensual';
      _startDate = DateTime.now();
      _selectedDays = List.generate(7, (index) => index != 6); // Resetear días
      _schedule = [];
      _totalInterest = 0.0;
      _totalPaid = 0.0;
      _fixedPayment = 0.0;
    });
  }

  Widget _summaryCard() {
    if (_schedule.isEmpty) return const SizedBox.shrink();

    final firstPaymentDate = _schedule.first['date'] as DateTime;
    final lastPaymentDate = _schedule.last['date'] as DateTime;

    final amountDigits = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final principal = double.tryParse(amountDigits) ?? 0.0;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Resumen del Préstamo', 
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700]
                )),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summaryMetric('Principal', _currency.format(principal)),
                _summaryMetric('Intereses', _currency.format(_totalInterest)),
                _summaryMetric('Total a pagar', _currency.format(_totalPaid)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summaryMetric('Cuotas', '${_schedule.length}'),
                _summaryMetric('Cuota Fija', _currency.format(_fixedPayment)),
                _summaryMetric('TEA', '${_rateCtrl.text}%'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month),
                    title: const Text('Inicio de cobros'),
                    subtitle: Text(_dateFormat.format(firstPaymentDate)),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Última cuota'),
                    subtitle: Text(_dateFormat.format(lastPaymentDate)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _summarySmall('Frecuencia', _frequency)),
                Expanded(child: _summarySmall('Periodos/año', '${_periodsPerYear(_frequency)}')),
                // ELIMINADO: No mostrar el sistema específico
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryMetric(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _summarySmall(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _scheduleList() {
    if (_schedule.isEmpty) {
      return Center(
        child: Text(
          'Sin simulación. Completa los datos y presiona "Calcular".', 
          style: TextStyle(color: Colors.grey[700])
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Cronograma de Pagos (${_schedule.length} cuotas)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _schedule.length,
          itemBuilder: (context, index) {
            final e = _schedule[index];
            final payment = e['payment'] as double;
            final date = e['date'] as DateTime;
            final remaining = e['remaining'] as double;
            final principal = e['principal'] as double;
            final interest = e['interest'] as double;
            
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[50],
                  child: Text('${e['index']}', style: TextStyle(color: Colors.blue[700])),
                ),
                title: Text(
                  '${_currency.format(payment)} • ${_dateFormat.format(date)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Capital: ${_currency.format(principal)} • Interés: ${_currency.format(interest)}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currency.format(remaining),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: remaining == 0 ? Colors.green : Colors.grey[700],
                        fontSize: 12
                      ),
                    ),
                    if (remaining == 0) 
                      Text('Saldo cero', style: TextStyle(color: Colors.green, fontSize: 10)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final InputDecoration numberField = const InputDecoration(border: OutlineInputBorder());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulador de Préstamos'),
        backgroundColor: Colors.blue[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: numberField.copyWith(
                          labelText: 'Monto del préstamo',
                          hintText: 'Ej: 1.000.000'
                        ),
                        validator: (v) {
                          final digits = v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                          final val = double.tryParse(digits) ?? 0;
                          if (val <= 0) return 'Ingresa un monto válido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _rateCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: numberField.copyWith(
                          labelText: 'Tasa de interés anual (%)',
                          hintText: 'Ej: 25.0'
                        ),
                        validator: (v) {
                          final val = double.tryParse((v ?? '').replaceAll(',', '.'));
                          if (val == null || val < 0) return 'Ingresa una tasa válida';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _termCtrl,
                              keyboardType: TextInputType.number,
                              decoration: numberField.copyWith(
                                labelText: 'Número de cuotas',
                                hintText: 'Ej: 12'
                              ),
                              validator: (v) {
                                final val = int.tryParse(v ?? '');
                                if (val == null || val <= 0) return 'Plazo inválido';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _frequency,
                              decoration: numberField.copyWith(labelText: 'Frecuencia'),
                              items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                              onChanged: (v) {
                                setState(() => _frequency = v ?? 'Mensual');
                                _simulate(); // Recalcular al cambiar frecuencia
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      //Sección de días para frecuencia diaria
                      if (_frequency == 'Diario') ...[
                        const SizedBox(height: 12),
                        _buildDaySelector(),
                      ],
                      
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today),
                        title: Text('Fecha inicio de cobros: ${_dateFormat.format(_startDate)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                            );
                            if (picked != null) {
                              setState(() => _startDate = DateTime(picked.year, picked.month, picked.day));
                              _simulate(); // Recalcular al cambiar fecha
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.calculate), 
                              label: const Text('Calcular'), 
                              onPressed: _simulate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              child: const Text('Limpiar'), 
                              onPressed: _reset
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _summaryCard(),
            const SizedBox(height: 8),
            _scheduleList(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}