// lib/presentation/screens/summary_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
import 'package:loan_app/data/repositories/payment_repository.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final LoanRepository _loanRepository = LoanRepository();
  final PaymentRepository _paymentRepository = PaymentRepository();
  double _totalLoaned = 0.0;
  double _totalPayments = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummaryData();
  }

  Future<void> _loadSummaryData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final totalLoaned = await _loanRepository.getTotalLoanedAmount();
      final totalPayments = await _paymentRepository.getTotalPaymentsAmount();
      
      setState(() {
        _totalLoaned = totalLoaned;
        _totalPayments = totalPayments;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar el resumen: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen General'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Icon(Icons.money, size: 50, color: Colors.green),
                          const SizedBox(height: 10),
                          Text(
                            'Total Recaudado',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            currencyFormatter.format(_totalPayments),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Icon(Icons.arrow_upward, size: 50, color: Colors.red),
                          const SizedBox(height: 10),
                          Text(
                            'Total Prestado',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            currencyFormatter.format(_totalLoaned),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}