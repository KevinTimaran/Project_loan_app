//#################################################
//#  Pantalla de Cobros de Hoy                   #//
//#  Muestra préstamos activos con vencimiento    #//
//#  en la fecha seleccionada (por defecto hoy).  #//
//#  Incluye resumen, selección de fecha, manejo  #//
//#  defensivo y presentación de IDs en 5 dígitos.#//
//#################################################

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';

class TodayCollectionScreen extends StatefulWidget {
  const TodayCollectionScreen({super.key});

  @override
  State<TodayCollectionScreen> createState() => _TodayCollectionScreenState();
}

class _TodayCollectionScreenState extends State<TodayCollectionScreen> {
  // Repositorios
  final ClientRepository _clientRepository = ClientRepository();
  final LoanRepository _loanRepository = LoanRepository();

  // Estado
  List<LoanModel> _dailyLoans = [];
  final Map<String, String> _clientNamesMap = {};
  bool _isLoading = true;
  String? _loadErrorMessage;

  // Fecha seleccionada (normalizada a 00:00)
  late DateTime _selectedDate;

  // Formateadores / constantes
  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
  static const int _expectedIdDigits = 5;

  @override
  void initState() {
    super.initState();
    _selectedDate = _normalizeDate(DateTime.now());
    _loadDailyLoans();
  }

  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadDailyLoans() async {
    setState(() {
      _isLoading = true;
      _dailyLoans = [];
      _clientNamesMap.clear();
      _loadErrorMessage = null;
    });

    try {
      final allLoans = await _loanRepository.getAllLoans();
      if (allLoans == null || allLoans.isEmpty) {
        if (!mounted) return;
        setState(() {
          _dailyLoans = [];
          _isLoading = false;
        });
        return;
      }

      final startOfDay = _normalizeDate(_selectedDate);

      final dailyLoans = <LoanModel>[];
      for (final loan in allLoans) {
        try {
          if (loan == null) continue;
          // 👇 Solo excluir préstamos que NO deben cobrarse
          if (loan.status == 'pagado' || loan.status == 'cancelado') continue;

          bool hasToday = false;

          // Verificar en paymentDates si existe
          final paymentDates = loan.paymentDates;
          if (paymentDates != null) {
            hasToday = paymentDates.any((pd) {
              if (pd == null) return false;
              return _normalizeDate(pd) == startOfDay;
            });
          }

          // Si aún no se encontró, usar dueDate como fallback
          if (!hasToday && loan.dueDate != null) {
            hasToday = _normalizeDate(loan.dueDate!) == startOfDay;
          }

          if (hasToday) {
            dailyLoans.add(loan);
          }
        } catch (_) {
          // Ignorar préstamos malformados
          continue;
        }
      }

      // Cargar nombres de clientes únicos
      final uniqueClientIds = <String>{};
      for (final loan in dailyLoans) {
        final cid = loan.clientId?.toString() ?? '';
        if (cid.isNotEmpty) uniqueClientIds.add(cid);
      }

      final clientFutures = uniqueClientIds.map((cid) async {
        try {
          final client = await _clientRepository.getClientById(cid);
          final name = '${client?.name ?? ''} ${client?.lastName ?? ''}'.trim();
          return MapEntry(cid, name.isNotEmpty ? name : 'Cliente desconocido');
        } catch (_) {
          return MapEntry(cid, 'Cliente desconocido');
        }
      }).toList();

      final clientEntries = await Future.wait(clientFutures);
      for (final entry in clientEntries) {
        _clientNamesMap[entry.key] = entry.value;
      }

      if (!mounted) return;
      setState(() {
        _dailyLoans = dailyLoans;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final errorMessage = 'Error al cargar los préstamos: $e';
      setState(() {
        _isLoading = false;
        _loadErrorMessage = errorMessage;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  /// Formatea un ID en 5 dígitos
  String _formatIdAsFiveDigits(dynamic rawId) {
    if (rawId == null) return '00000';

    final rawString = rawId.toString().trim();

    try {
      final idInt = int.parse(rawString);
      if (idInt < 0) return '00000';
      if (idInt > 99999) return '99999';
      return idInt.toString().padLeft(_expectedIdDigits, '0');
    } catch (_) {
      final digitsOnly = rawString.replaceAll(RegExp(r'[^0-9]'), '');
      if (digitsOnly.isEmpty) {
        if (rawString.length >= _expectedIdDigits) {
          return rawString.substring(rawString.length - _expectedIdDigits);
        } else {
          return rawString.padRight(_expectedIdDigits, '0');
        }
      } else {
        if (digitsOnly.length > _expectedIdDigits) {
          return digitsOnly.substring(digitsOnly.length - _expectedIdDigits);
        } else {
          return digitsOnly.padLeft(_expectedIdDigits, '0');
        }
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final normalized = _normalizeDate(picked);
      if (normalized != _selectedDate) {
        setState(() => _selectedDate = normalized);
        await _loadDailyLoans();
      }
    }
  }

  Widget _buildHeader(BuildContext context) {
    final dateLabel = _dateFormatter.format(_selectedDate);
    final totalAmount = _dailyLoans.fold<double>(0.0, (sum, loan) => sum + (loan.remainingBalance ?? 0.0));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Fecha:', style: TextStyle(fontSize: 16)),
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(dateLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
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
                  _buildSummaryItem('Préstamos Vencidos', _dailyLoans.length.toString(), Icons.account_balance_wallet),
                  _buildSummaryItem('Total a Cobrar', _currencyFormatter.format(totalAmount), Icons.attach_money),
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

    final loanIdDisplay = _formatIdAsFiveDigits(loan.id);
    final dueDateText = loan.dueDate != null ? _dateFormatter.format(loan.dueDate!) : 'Fecha desconocida';
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
        trailing: Text(_currencyFormatter.format(remaining), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        onTap: () {
          // Navegación a detalle del préstamo (opcional)
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
              ElevatedButton(onPressed: _loadDailyLoans, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    if (_dailyLoans.isEmpty) {
      return const Center(child: Text('No hay cobros programados para esta fecha.'));
    }

    return ListView.builder(
      itemCount: _dailyLoans.length,
      itemBuilder: (context, index) => _buildLoanTile(_dailyLoans[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobros de Hoy'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E88E5),
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
        Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}