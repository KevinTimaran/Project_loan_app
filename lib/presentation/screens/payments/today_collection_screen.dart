// lib/presentation/screens/payments/today_collection_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
import 'package:loan_app/presentation/screens/payments/payment_form_screen.dart';

class TodayCollectionScreen extends StatefulWidget {
  const TodayCollectionScreen({super.key});

  @override
  State<TodayCollectionScreen> createState() => _TodayCollectionScreenState();
}

class _TodayCollectionScreenState extends State<TodayCollectionScreen> {
  final ClientRepository _clientRepository = ClientRepository();
  final LoanRepository _loanRepository = LoanRepository();

  List<LoanModel> _dailyLoans = [];
  final Map<String, String> _clientNamesMap = {};
  bool _isLoading = true;
  String? _loadErrorMessage;

  final DateTime _selectedDate = DateTime.now();
  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
  static const double _residualThreshold = 0.50;

  @override
  void initState() {
    super.initState();
    _loadDailyLoans();
  }

  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadDailyLoans() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _loadErrorMessage = null;
    });

    try {
      debugPrint('🔄 Cargando préstamos para: ${_dateFormatter.format(_selectedDate)}');
      final allLoans = await _loanRepository.getAllLoans();
      
      if (allLoans == null || allLoans.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _dailyLoans = [];
        });
        return;
      }

      final day = _normalizeDate(_selectedDate);
      final List<LoanModel> dailyLoans = [];

      for (final loan in allLoans) {
        try {
          if (loan == null) continue;
          
          final currentStatus = loan.status?.toLowerCase() ?? '';
          if (currentStatus == 'pagado' || currentStatus == 'cancelado') continue;
          if (loan.isFullyPaid) continue;
          if (!loan.hasPaymentDueOn(day)) continue;

          final amountDueToday = loan.getAmountDueToday();
          if (amountDueToday <= 0.01) continue;
          if (loan.remainingBalance <= 0.01) continue;

          dailyLoans.add(loan);
        } catch (e) {
          continue;
        }
      }

      await _loadClientNames(dailyLoans);

      if (!mounted) return;
      setState(() {
        _dailyLoans = dailyLoans;
        _isLoading = false;
      });
      
    } catch (e) {
      debugPrint('❌ ERROR en _loadDailyLoans: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadErrorMessage = 'Error al cargar cobros: ${e.toString()}';
      });
    }
  }

  Future<void> _loadClientNames(List<LoanModel> loans) async {
    _clientNamesMap.clear();
    
    final uniqueClientIds = <String>{};
    for (final loan in loans) {
      final cid = loan.clientId ?? '';
      if (cid.isNotEmpty) uniqueClientIds.add(cid);
    }

    if (uniqueClientIds.isEmpty) return;

    for (final cid in uniqueClientIds) {
      try {
        final client = await _clientRepository.getClientById(cid);
        final name = '${client?.name ?? ''} ${client?.lastName ?? ''}'.trim();
        _clientNamesMap[cid] = name.isNotEmpty ? name : 'Cliente desconocido';
      } catch (e) {
        _clientNamesMap[cid] = 'Cliente desconocido';
      }
    }
  }

  Future<void> _handlePayment(LoanModel loan) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PaymentFormScreen(loan: loan)),
    );

    if (result == true) {
      await _loadDailyLoans();
    }
  }

  void _handleReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final LoanModel item = _dailyLoans.removeAt(oldIndex);
      _dailyLoans.insert(newIndex, item);
    });
  }

  Widget _buildHeader(BuildContext context) {
    final dateLabel = _dateFormatter.format(_selectedDate);
    
    final totalAmount = _dailyLoans.fold<double>(0.0, (sum, loan) {
      return sum + loan.getAmountDueToday();
    });

    final residualLoans = _dailyLoans.where((loan) => (loan.remainingBalance ) <= _residualThreshold).length;
    final almostPaidLoans = _dailyLoans.where((loan) {
      final saldo = loan.remainingBalance ;
      return saldo > _residualThreshold && saldo <= 1.0;
    }).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Fecha:', style: TextStyle(fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  dateLabel, 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('Préstamos', _dailyLoans.length.toString(), Icons.account_balance_wallet),
                      _buildSummaryItem('Total a Cobrar', _currencyFormatter.format(totalAmount), Icons.attach_money),
                    ],
                  ),
                  if (residualLoans > 0 || almostPaidLoans > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        if (residualLoans > 0)
                          _buildSummaryItem('Residuales', residualLoans.toString(), Icons.info, Colors.orange),
                        if (almostPaidLoans > 0)
                          _buildSummaryItem('Casi Pagados', almostPaidLoans.toString(), Icons.trending_down, Colors.blue),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanTile(LoanModel loan, {Key? key}) {
    final clientName = _clientNamesMap[loan.clientId ?? ''] ?? 'Cliente desconocido';
    final loanIdDisplay = _getShortLoanId(loan);
    final dueDateText = loan.dueDate != null ? _dateFormatter.format(loan.dueDate!) : 'Fecha desconocida';
    
    final amountDueToday = loan.getAmountDueToday();
    final saldo = loan.remainingBalance ;

    Color? cardColor;
    IconData statusIcon = Icons.account_balance_wallet;
    String statusText = '';
    Color statusColor = Theme.of(context).primaryColor;

    if (loan.isFullyPaid) {
      cardColor = Colors.green[50];
      statusIcon = Icons.check_circle;
      statusText = 'PAGADO';
      statusColor = Colors.green;
    } else if (saldo <= _residualThreshold) {
      cardColor = Colors.orange[50];
      statusIcon = Icons.info;
      statusText = 'RESIDUAL';
      statusColor = Colors.orange;
    } else if (saldo <= 1.0) {
      cardColor = Colors.blue[50];
      statusIcon = Icons.trending_down;
      statusText = 'CASI PAGADO';
      statusColor = Colors.blue;
    }

    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: cardColor,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.drag_handle, color: Colors.grey[400], size: 18),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: statusColor,
              child: Icon(statusIcon, color: Colors.white, size: 18),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                clientName, 
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (statusText.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Préstamo #$loanIdDisplay • Vence: $dueDateText'),
            Text(
              'Saldo: ${_currencyFormatter.format(saldo)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (saldo <= _residualThreshold)
              Text(
                '⚠️ Saldo residual',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _currencyFormatter.format(amountDueToday),
              style: const TextStyle(
                fontWeight: FontWeight.bold, 
                color: Colors.red,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Cuota hoy',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
            if (saldo <= _residualThreshold)
              Text(
                'Pago final',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.orange[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        onTap: () => _handlePayment(loan),
      ),
    );
  }

  String _getShortLoanId(LoanModel loan) {
    final id = loan.id ?? '';
    if (id.isEmpty) return '00000';

    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '00000';
    if (digits.length <= 4) return digits.padLeft(4, '0');
    return digits.substring(digits.length - 4);
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando préstamos del día...'),
          ],
        ),
      );
    }
    
    if (_loadErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 50),
              const SizedBox(height: 12),
              Text(
                _loadErrorMessage!, 
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadDailyLoans, 
                child: const Text('Reintentar')
              ),
            ],
          ),
        ),
      );
    }
    
    if (_dailyLoans.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 50, color: Colors.green),
            SizedBox(height: 12),
            Text(
              'No hay cobros pendientes para hoy',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Todos los préstamos están al día',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ReorderableListView(
      onReorder: _handleReorder,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (int index = 0; index < _dailyLoans.length; index++)
          _buildLoanTile(
            _dailyLoans[index],
            key: Key('loan_${_dailyLoans[index].id}_$index'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobros de Hoy'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E88E5),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadDailyLoans().then((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🔄 Lista actualizada'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              });
            },
            tooltip: 'Actualizar lista',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon, [Color? iconColor]) {
    return Column(
      children: [
        Icon(icon, size: 28, color: iconColor ?? Theme.of(context).primaryColor),
        const SizedBox(height: 6),
        Text(
          title, 
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value, 
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}