//#################################################
//#  Pantalla de Cobros de la Semana            #//
//#  Muestra préstamos activos con vencimiento    #//
//#  dentro de la semana actual.                  #//
//#  Incluye resumen y lista detallada.           #//
//#################################################

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';

class WeeklyPaymentsScreen extends StatefulWidget {
  const WeeklyPaymentsScreen({super.key});

  @override
  State<WeeklyPaymentsScreen> createState() => _WeeklyPaymentsScreenState();
}

class _WeeklyPaymentsScreenState extends State<WeeklyPaymentsScreen> {
  // Repositorios
  final ClientRepository _clientRepository = ClientRepository();
  final LoanRepository _loanRepository = LoanRepository();

  // Estado de la pantalla
  List<LoanModel> _weeklyLoans = [];
  final Map<String, String> _clientNamesMap = {};
  bool _isLoading = true;
  String? _loadErrorMessage;

  // Rango de la semana (se inicializa en initState)
  late final DateTime _startOfWeek;
  late final DateTime _endOfWeek;

  // Formateadores
  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
  final DateFormat _weekLabelFormatter = DateFormat('dd/MM');

  // Constantes
  static const int _expectedIdDigits = 5;

  @override
  void initState() {
    super.initState();
    _initializeWeekRange();
    _loadWeeklyLoans();
  }

  void _initializeWeekRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day); // limpia horas
    // Inicio de semana = lunes
    _startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    // Fin exclusivo = siguiente lunes (no incluye ese día)
    _endOfWeek = _startOfWeek.add(const Duration(days: 7));
  }

  Future<void> _loadWeeklyLoans() async {
    setState(() {
      _isLoading = true;
      _weeklyLoans = [];
      _clientNamesMap.clear();
      _loadErrorMessage = null;
    });

    try {
      final allLoans = await _loanRepository.getAllLoans();

      // 👇 CORRECCIÓN LÓGICA 1 y 2: Incluir paymentDates y estados relevantes
      final weeklyLoans = <LoanModel>[];
      for (final loan in allLoans) {
        if (loan == null) continue;
        // Excluir solo préstamos no cobrables
        if (loan.status == 'pagado' || loan.status == 'cancelado') continue;

        bool inWeek = false;

        // Verificar en paymentDates
        final paymentDates = loan.paymentDates;
        if (paymentDates != null) {
          inWeek = paymentDates.any((pd) {
            if (pd == null) return false;
            return !pd.isBefore(_startOfWeek) && pd.isBefore(_endOfWeek);
          });
        }

        // Si no se encontró en paymentDates, verificar dueDate
        if (!inWeek && loan.dueDate != null) {
          final due = loan.dueDate!;
          inWeek = !due.isBefore(_startOfWeek) && due.isBefore(_endOfWeek);
        }

        if (inWeek) {
          weeklyLoans.add(loan);
        }
      }

      // Cargar nombres de clientes en paralelo (pero tolerante a fallos individuales)
      final futures = weeklyLoans.map((loan) async {
        try {
          final client = await _clientRepository.getClientById(loan.clientId);
          final key = loan.clientId?.toString() ?? '';
          final name = '${client?.name ?? ''} ${client?.lastName ?? ''}'.trim();
          _clientNamesMap[key] = name.isNotEmpty ? name : 'Cliente desconocido';
        } catch (_) {
          final key = loan.clientId?.toString() ?? '';
          _clientNamesMap[key] = 'Cliente desconocido';
        }
      }).toList();

      await Future.wait(futures);

      if (!mounted) return;
      setState(() {
        _weeklyLoans = weeklyLoans;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // 👇 CORRECCIÓN LÓGICA 5: usar variable local
      final errorMessage = 'Error al cargar los préstamos: $e';
      setState(() {
        _isLoading = false;
        _loadErrorMessage = errorMessage;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  // Formatea el ID como 5 dígitos numéricos si es posible. Si no, devuelve fallback.
  String _formatIdAsFiveDigits(dynamic rawId) {
    if (rawId == null) return '00000';
    final rawString = rawId.toString();

    try {
      final idInt = int.parse(rawString);
      if (idInt < 0) return '00000';
      if (idInt > 99999) return '99999'; // 👈 CORRECCIÓN LÓGICA 3
      return idInt.toString().padLeft(_expectedIdDigits, '0');
    } catch (_) {
      final digitsOnly = rawString.replaceAll(RegExp(r'[^0-9]'), '');
      if (digitsOnly.isEmpty) {
        return '00000'; // 👈 Solo dígitos válidos; si no, 00000
      } else {
        if (digitsOnly.length > _expectedIdDigits) {
          return digitsOnly.substring(digitsOnly.length - _expectedIdDigits);
        } else {
          return digitsOnly.padLeft(_expectedIdDigits, '0');
        }
      }
    }
  }

  Widget _buildHeader(BuildContext context) {
    final weekLabel =
        '${_weekLabelFormatter.format(_startOfWeek)} - ${_weekLabelFormatter.format(_endOfWeek.subtract(const Duration(days: 1)))}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Semana:', style: TextStyle(fontSize: 16)),
              Text(weekLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(
                    'Préstamos Activos',
                    _weeklyLoans.length.toString(),
                    Icons.account_balance_wallet,
                  ),
                  _buildSummaryItem(
                    'Total a Cobrar',
                    _currencyFormatter.format(
                      _weeklyLoans.fold<double>(
                        0.0,
                        (sum, loan) => sum + (loan.remainingBalance ?? 0.0),
                      ),
                    ),
                    Icons.attach_money,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanTile(LoanModel loan) {
    final clientKey = loan.clientId?.toString() ?? '';
    final clientName = _clientNamesMap[clientKey] ?? 'Cliente desconocido';

    final rawId = loan.id;
    final loanIdDisplay = _formatIdAsFiveDigits(rawId);

    final dueDateText = loan.dueDate != null ? _dateFormatter.format(loan.dueDate) : 'Fecha desconocida';
    final remaining = loan.remainingBalance ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: const Icon(Icons.account_balance_wallet, color: Colors.white),
        ),
        title: Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Préstamo #$loanIdDisplay • Vence: $dueDateText'),
        trailing: Text(
          _currencyFormatter.format(remaining),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        onTap: () {
          // Si deseas navegar al detalle del préstamo, añade la ruta aquí.
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadErrorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadWeeklyLoans,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_weeklyLoans.isEmpty) {
      return const Center(child: Text('No hay préstamos con vencimiento esta semana.'));
    }

    return ListView.builder(
      itemCount: _weeklyLoans.length,
      itemBuilder: (context, index) => _buildLoanTile(_weeklyLoans[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobros de la Semana'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Theme.of(context).primaryColor),
        const SizedBox(height: 6),
        Text(title, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}