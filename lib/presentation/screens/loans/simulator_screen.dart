// lib/presentation/screens/loans/simulator_screen.dart
// Simulador con Sistema Francés (cuota fija)
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

  /// SISTEMA FRANCÉS - Cuota fija
  /// Fórmula: Cuota = P * i * (1+i)^n / ((1+i)^n - 1)
  Map<String, dynamic> _generateFrenchSystemSchedule({
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

    // Calcular tasa periódica según frecuencia
    double periodRate;
    Duration periodDuration;

    switch (frequency.toLowerCase()) {
      case 'diario':
        periodRate = (annualRatePercent / 100) / 365;
        periodDuration = const Duration(days: 1);
        break;
      case 'semanal':
        periodRate = (annualRatePercent / 100) / 52;
        periodDuration = const Duration(days: 7);
        break;
      case 'quincenal':
        periodRate = (annualRatePercent / 100) / 24;
        periodDuration = const Duration(days: 15);
        break;
      case 'mensual':
      default:
        periodRate = (annualRatePercent / 100) / 12;
        periodDuration = const Duration(days: 30);
        break;
    }

    // Calcular cuota fija usando la fórmula del sistema francés
    final double numerator = periodRate * pow(1 + periodRate, term);
    final double denominator = pow(1 + periodRate, term) - 1;
    final double fixedPayment = amount * (numerator / denominator);

    // Trabajar en centavos para precisión
    int remainingCents = (amount * 100).round();
    final int fixedPaymentCents = (fixedPayment * 100).round();
    int totalPaidCents = 0;

    for (int i = 0; i < term; i++) {
      // Calcular fecha
      DateTime date;
      if (frequency.toLowerCase() == 'mensual') {
        // Respetar días reales del mes
        int year = startDate.year;
        int month = startDate.month + i;
        year += (month - 1) ~/ 12;
        month = ((month - 1) % 12) + 1;
        int day = startDate.day;
        final int lastDay = DateTime(year, month + 1, 0).day;
        if (day > lastDay) day = lastDay;
        date = DateTime(year, month, day);
      } else {
        date = startDate.add(periodDuration * i);
      }
      final normalizedDate = DateTime(date.year, date.month, date.day);
      dates.add(normalizedDate);

      // Calcular interés del período sobre saldo actual
      final double interestRaw = remainingCents * periodRate;
      final int interestCents = interestRaw.round();

      // Calcular abono a capital
      int principalCents = fixedPaymentCents - interestCents;
      
      // Ajustar última cuota para que no quede saldo negativo
      if (i == term - 1) {
        principalCents = remainingCents;
      }

      // Asegurar que no exceda el saldo restante
      principalCents = principalCents.clamp(0, remainingCents);
      
      final int paymentCents = principalCents + interestCents;

      // Actualizar saldo
      remainingCents -= principalCents;
      if (remainingCents < 0) remainingCents = 0;

      totalPaidCents += paymentCents;

      // Guardar valores (convertir a pesos)
      installments.add(paymentCents / 100.0);
      interests.add(interestCents / 100.0);
      principals.add(principalCents / 100.0);
      remainings.add(remainingCents / 100.0);
    }

    final double totalToPay = totalPaidCents / 100.0;
    return {
      'dates': dates,
      'installments': installments,
      'interests': interests,
      'principals': principals,
      'remainings': remainings,
      'total': totalToPay,
      'fixedPayment': fixedPayment
    };
  }

  void _simulate() {
    if (!_formKey.currentState!.validate()) return;

    // Parsear monto: extraer dígitos y construir double de pesos
    final amountDigits = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final principal = double.tryParse(amountDigits) ?? 0.0;

    final rate = double.tryParse(_rateCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final term = int.tryParse(_termCtrl.text) ?? 0;

    if (principal <= 0 || term <= 0) return;

    final res = _generateFrenchSystemSchedule(
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
            Text('Resumen - Sistema Francés', 
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
                Expanded(child: _summarySmall('Sistema', 'Francés')),
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
            'Tabla de Amortización (${_schedule.length} cuotas)',
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
                  child: Text('${e['index']}', style: const TextStyle(color: Colors.blue)),
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
        title: const Text('Simulador - Sistema Francés'),
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
                              onChanged: (v) => setState(() => _frequency = v ?? 'Mensual'),
                            ),
                          ),
                        ],
                      ),
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