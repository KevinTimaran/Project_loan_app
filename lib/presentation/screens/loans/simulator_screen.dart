// lib/presentation/screens/loans/simulator_screen.dart
// Simulador que reutiliza la lógica de LoanFormScreen para generar el calendario de pagos.
// - Formateo de monto con separador de miles (es_CO).
// - Permite elegir fecha de inicio del crédito (desde cuándo empiezan los cobros).
// - Resumen profesional con fecha de inicio/fin, totales y conteo de cuotas.

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

  // Formatters
  final NumberFormat _currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  final NumberFormat _decimalPattern = NumberFormat.decimalPattern('es_CO');
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    // Listener para formatear el monto con separadores de miles automáticamente
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
  // Nota: este formateo deja el valor como entero (pesos). Si quieres permitir centavos, habría que
  // adaptar el parsing y el formateador para conservar parte decimal.
  void _formatAmountWithThousandsSeparator() {
    final text = _amountCtrl.text;
    if (text.isEmpty) return;

    // Dejar sólo dígitos (el usuario puede pegar texto)
    final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      _amountCtrl.value = TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
      return;
    }

    // Parsear a int y formatear
    final value = int.tryParse(digitsOnly) ?? 0;
    final formatted = _decimalPattern.format(value);

    // Evitar loops infinitos si ya está formateado
    if (formatted != text) {
      _amountCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  // Periodos por año según frecuencia
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

  // Añadir meses evitando overflow en días (ej. 31 de ene + 1 mes -> 28/29 feb)
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

  /// Igual lógica de LoanFormScreen: construcción de cronograma con interés simple
  List<Map<String, dynamic>> buildSimpleInterestSchedule({
    required double principal,
    required double annualRatePercent,
    required int numberOfPayments,
    required String frequency,
    required DateTime startDate,
  }) {
    int periodsPerYear = _periodsPerYear(frequency);
    final double annualRate = annualRatePercent / 100.0;
    final double timeInYears = numberOfPayments / periodsPerYear;

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
      if (frequency == 'Diario') {
        current = current.add(const Duration(days: 1));
      } else if (frequency == 'Semanal') {
        current = current.add(const Duration(days: 7));
      } else if (frequency == 'Quincenal') {
        current = current.add(const Duration(days: 15));
      } else {
        current = addMonthsSafe(current, 1);
      }

      int principalPortionCents = principalPerPaymentCents;
      int interestPortionCents = interestPerPaymentCents;

      if (i == numberOfPayments - 1) {
        // Añadir residuos al último pago para cuadrar
        principalPortionCents += principalRemainder;
        interestPortionCents += interestRemainder;
      }

      final int paymentCents = principalPortionCents + interestPortionCents;
      remainingCents = max(0, remainingCents - principalPortionCents);

      schedule.add({
        'index': i + 1,
        'date': current,
        'paymentCents': paymentCents,
        'payment': paymentCents / 100.0,
        'interest': interestPortionCents / 100.0,
        'principal': principalPortionCents / 100.0,
        'remaining': remainingCents / 100.0,
      });
    }

    return schedule;
  }

  void _simulate() {
    if (!_formKey.currentState!.validate()) return;

    // Parsear monto como entero (pesos)
    final amountDigits = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final principal = double.tryParse(amountDigits) ?? 0.0;

    final rate = double.tryParse(_rateCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final term = int.tryParse(_termCtrl.text) ?? 0;

    if (principal <= 0 || term <= 0) return;

    final schedule = buildSimpleInterestSchedule(
      principal: principal,
      annualRatePercent: rate,
      numberOfPayments: term,
      frequency: _frequency,
      startDate: _startDate,
    );

    final totalInterest = schedule.fold<double>(0.0, (s, e) => s + (e['interest'] as double));
    final totalPaid = schedule.fold<double>(0.0, (s, e) => s + (e['payment'] as double));

    setState(() {
      _schedule = schedule;
      _totalInterest = totalInterest;
      _totalPaid = totalPaid;
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
    });
  }

  // Resumen profesional con toda la info solicitada
  Widget _summaryCard() {
    if (_schedule.isEmpty) return const SizedBox.shrink();

    final firstPaymentDate = _schedule.first['date'] as DateTime;
    final lastPaymentDate = _schedule.last['date'] as DateTime;
    final firstPayment = _schedule.first['payment'] as double;
    final lastPayment = _schedule.last['payment'] as double;
    final avgPayment = _schedule.fold<double>(0.0, (s, e) => s + (e['payment'] as double)) / _schedule.length;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Resumen', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Row principal con métricas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summaryMetric('Principal', _currency.format((_amountCtrl.text.isEmpty ? 0 : double.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0))),
                _summaryMetric('Intereses', _currency.format(_totalInterest)),
                _summaryMetric('Total a pagar', _currency.format(_totalPaid)),
              ],
            ),
            const SizedBox(height: 12),

            // Segunda fila
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summaryMetric('Cuotas', '${_schedule.length}'),
                _summaryMetric('Cuota (1ª)', _currency.format(firstPayment)),
                _summaryMetric('Cuota (prom.)', _currency.format(avgPayment)),
              ],
            ),
            const SizedBox(height: 12),

            // Fechas y frecuencia
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
                Expanded(child: _summarySmall('Tasa anual', '${_rateCtrl.text.isEmpty ? ' - ' : _rateCtrl.text + ' %'}')),
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

  // Lista de amortización
  Widget _scheduleList() {
    if (_schedule.isEmpty) {
      return Center(child: Text('Sin simulación. Completa los datos y presiona "Calcular".', style: TextStyle(color: Colors.grey[700])));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _schedule.length,
      itemBuilder: (context, index) {
        final e = _schedule[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: CircleAvatar(child: Text('${e['index']}')),
            title: Text('${_currency.format(e['payment'])}  •  ${_dateFormat.format(e['date'])}'),
            subtitle: Text('Capital: ${_currency.format(e['principal'])} • Interés: ${_currency.format(e['interest'])}'),
            trailing: Text('Saldo: ${_currency.format(e['remaining'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  // UI principal
  @override
  Widget build(BuildContext context) {
    final InputDecoration numberField = const InputDecoration(border: OutlineInputBorder());

    return Scaffold(
      appBar: AppBar(title: const Text('Simulador de Pagos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Formulario
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Monto con formateo automático
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: numberField.copyWith(labelText: 'Monto (principal)'),
                        validator: (v) {
                          final digits = v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                          final val = double.tryParse(digits) ?? 0;
                          if (val <= 0) return 'Ingresa un monto válido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Tasa anual
                      TextFormField(
                        controller: _rateCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: numberField.copyWith(labelText: 'Tasa anual (%)'),
                        validator: (v) {
                          final val = double.tryParse((v ?? '').replaceAll(',', '.'));
                          if (val == null || val < 0) return 'Ingresa una tasa válida';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Plazo y frecuencia
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _termCtrl,
                              keyboardType: TextInputType.number,
                              decoration: numberField.copyWith(labelText: 'Número de cuotas'),
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

                      // Fecha de inicio para comenzar los cobros
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
                          Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.calculate), label: const Text('Calcular'), onPressed: _simulate)),
                          const SizedBox(width: 12),
                          Expanded(child: OutlinedButton(child: const Text('Limpiar'), onPressed: _reset)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Resumen completo
            _summaryCard(),

            const SizedBox(height: 8),

            // Tabla de amortización
            _scheduleList(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

