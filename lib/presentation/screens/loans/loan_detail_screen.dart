//#################################################
//#  Pantalla de Vista Detallada del Préstamo    #//
//#  Muestra detalles completos de un préstamo,   #//
//#  incluyendo historial de pagos y plan.        #//
//#################################################

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/presentation/screens/payments/payment_form_screen.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loan_app/domain/entities/payment.dart';
import 'package:loan_app/data/repositories/payment_repository.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';

class LoanDetailScreen extends StatefulWidget {
  final LoanModel loan;
  const LoanDetailScreen({super.key, required this.loan});

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  final LoanRepository _loanRepository = LoanRepository();
  final PaymentRepository _paymentRepository = PaymentRepository();
  late Future<LoanModel?> _loanDetailsFuture;
  List<Map<String, dynamic>> _computedSchedule = [];

  /// Formatea un ID (UUID o numérico) en 5 dígitos numéricos
  String _formatIdAsFiveDigits(dynamic rawId) {
    if (rawId == null) return '00000';
    
    final rawString = rawId.toString();
    final digitsOnly = rawString.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (digitsOnly.isEmpty) {
      return '00000';
    } else if (digitsOnly.length <= 5) {
      return digitsOnly.padLeft(5, '0');
    } else {
      return digitsOnly.substring(digitsOnly.length - 5);
    }
  }

  @override
  void initState() {
    super.initState();
    _loanDetailsFuture = _loadLoanDetails();
  }

  Future<LoanModel?> _loadLoanDetails() async {
    final loan = await _loanRepository.getLoanById(widget.loan.id);
    if (loan != null) {
      _computedSchedule = buildAnnuitySchedule(
        principal: loan.amount ?? 0.0,
        annualRatePercent: (loan.interestRate ?? 0.0) * 100,
        numberOfPayments: loan.termValue ?? 0,
        frequency: loan.paymentFrequency ?? 'Mensual',
        startDate: loan.startDate ?? DateTime.now(),
      ).where((e) => (e['paymentCents'] as int) > 0).toList();
    }
    return loan;
  }

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo realizar la llamada a $phoneNumber')),
        );
      }
    }
  }

  Future<void> _launchWhatsApp(BuildContext context, String whatsappNumber) async {
    // ✅ Corregido: eliminar espacio en la URL de WhatsApp
    final cleanNumber = whatsappNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri webWhatsappUri = Uri.parse('https://wa.me/$cleanNumber');
    if (await canLaunchUrl(webWhatsappUri)) {
      await launchUrl(webWhatsappUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir WhatsApp para $whatsappNumber')),
        );
      }
    }
  }

  Future<void> _openRegisterPayment(LoanModel loan) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PaymentFormScreen(loan: loan)),
    );

    if (!mounted) return;
    if (result == true) {
      setState(() {
        _loanDetailsFuture = _loadLoanDetails();
      });
    }
  }

  // ---------- FUNCIÓN CORREGIDA PARA CRONOGRAMA ----------
  List<Map<String, dynamic>> buildAnnuitySchedule({
    required double principal,
    required double annualRatePercent,
    required int numberOfPayments,
    required String frequency,
    required DateTime startDate,
  }) {
    final periodsPerYear = _periodsPerYearForFrequency(frequency);
    final annualRate = annualRatePercent / 100.0;
    final r = (periodsPerYear > 0) ? (annualRate / periodsPerYear) : 0.0;

    final principalCents = (principal * 100).round();
    final n = numberOfPayments;
    if (n <= 0) return [];

    double payment;
    if (r > 0) {
      final denom = 1 - pow(1 + r, -n);
      payment = denom == 0 ? principal / n : principal * r / denom;
    } else {
      payment = principal / n;
    }

    final paymentCentsBase = (payment * 100).floor();

    List<Map<String, dynamic>> schedule = [];
    DateTime current = startDate;
    int remainingCents = principalCents;
    int totalInterestAccumCents = 0;
    int sumPaymentsCents = 0;

    for (int i = 0; i < n; i++) {
      if (frequency.toLowerCase() == 'diario') {
        current = current.add(const Duration(days: 1));
      } else if (frequency.toLowerCase() == 'semanal') {
        current = current.add(const Duration(days: 7));
      } else if (frequency.toLowerCase() == 'quincenal') {
        current = current.add(const Duration(days: 15));
      } else {
        current = DateTime(current.year, current.month + 1, current.day);
      }

      final double interestForPeriod = (remainingCents / 100.0) * r;
      int interestCents = (interestForPeriod * 100).round();
      int principalCentsForPeriod = paymentCentsBase - interestCents;
      if (principalCentsForPeriod < 0) principalCentsForPeriod = 0;

      if (i == n - 1) {
        interestCents = ((remainingCents / 100.0) * r * 100).round();
        principalCentsForPeriod = remainingCents;
      }

      final paymentCents = principalCentsForPeriod + interestCents;
      remainingCents = max(0, remainingCents - principalCentsForPeriod);
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
    }

    final expectedTotalPaid = principalCents + totalInterestAccumCents;
    final delta = expectedTotalPaid - sumPaymentsCents;
    if (delta != 0 && schedule.isNotEmpty) {
      final last = schedule.last;
      last['principalCents'] = (last['principalCents'] as int) + delta;
      last['paymentCents'] = (last['paymentCents'] as int) + delta;
      last['remainingCents'] = 0;
    }

    return schedule;
  }

  int _periodsPerYearForFrequency(String freq) {
    switch (freq.toLowerCase()) {
      case 'diario':
        return 365;
      case 'semanal':
        return 52;
      case 'quincenal':
        return 24;
      default:
        return 12;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Formatear el ID del préstamo para mostrar en el título
    final loanIdDisplay = _formatIdAsFiveDigits(widget.loan.id);
    final currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles del Préstamo #$loanIdDisplay'), // ✅ Corregido: ya no muestra "null"
      ),
      body: FutureBuilder<LoanModel?>(
        future: _loanDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text('Error al cargar los detalles del préstamo.'));
          }

          final loan = snapshot.data!;

          // >>> Normalizamos valores que pueden ser null para evitar errores en operaciones
          final double amount = (loan.amount ?? 0.0);
          final double totalAmountToPay = (loan.totalAmountToPay ?? 0.0);
          final double calculatedPaymentAmount = (loan.calculatedPaymentAmount ?? 0.0);
          final double totalPaid = (loan.totalPaid ?? 0.0);
          final double remainingBalance = (loan.remainingBalance ?? (totalAmountToPay - totalPaid));
          final double totalInterest = (totalAmountToPay - amount);

          final payments = loan.payments ?? <Payment>[];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ===== TARJETA PRINCIPAL DEL PRÉSTAMO =====
                Card(
                  color: Colors.deepPurple.shade50,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cliente: ${loan.clientName}', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text('Fecha de crédito: ${DateFormat('dd/MM/yyyy').format(loan.startDate ?? DateTime.now())}'),
                        Text('Próxima cuota: ${_computedSchedule.isNotEmpty ? DateFormat('dd/MM/yyyy').format(_computedSchedule.first['date']) : '-'}'),
                        Text('Vencimiento: ${DateFormat('dd/MM/yyyy').format(loan.dueDate ?? DateTime.now())}'),
                        Text('Interés: ${( (loan.interestRate ?? 0.0) * 100 ).toStringAsFixed(2)}%'),
                        Text('Valor total interés: ${currency.format(totalInterest)}'),
                        Text('Valor cuota: ${currency.format(calculatedPaymentAmount)}'),
                        Text('Total prestado: ${currency.format(amount)}'),
                        Text('Total + interés: ${currency.format(totalAmountToPay)}'),
                        Text('Saldo total: ${currency.format(remainingBalance)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ===== LISTA DE CUOTAS CALCULADAS =====
                const Text('Plan de Pagos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _computedSchedule.isEmpty
                    ? const Center(child: Text('No hay cuotas para mostrar.'))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _computedSchedule.length,
                        itemBuilder: (context, index) {
                          final e = _computedSchedule[index];
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
                const SizedBox(height: 20),

                // ===== HISTORIAL DE PAGOS =====
                const Text('Historial de Pagos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                payments.isEmpty
                    ? const Center(child: Text('No hay pagos registrados.'))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: payments.length,
                        itemBuilder: (context, index) {
                          final payment = payments[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: const Icon(Icons.receipt),
                              title: Text('Pago de: ${currency.format(payment.amount)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Fecha: ${DateFormat('dd/MM/yyyy').format(payment.date)}'),
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 20),

                if (remainingBalance > 0)
                  ElevatedButton.icon(
                    onPressed: () => _openRegisterPayment(loan),
                    icon: const Icon(Icons.add_task),
                    label: const Text('Registrar Pago'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}