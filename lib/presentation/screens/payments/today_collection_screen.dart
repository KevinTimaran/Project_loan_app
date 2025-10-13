// lib/presentation/screens/payments/today_collection_screen.dart
//#################################################
//#  Pantalla de Cobros de Hoy (con reordenamiento)
//#################################################

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final Map<String, double> _amountsDueToday = {};
  bool _isLoading = true;
  String? _loadErrorMessage;

  late DateTime _selectedDate;

  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');

  // Persistence key prefix para guardar orden por fecha
  static const String _prefsOrderKeyPrefix = 'today_collection_order_';

  // ✅ MEJORADO: Generar ID corta y legible
  String _getShortLoanId(LoanModel loan) {
    final id = loan.id ?? '';
    if (id.isEmpty) return '00000';

    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '00000';
    if (digits.length <= 4) return digits.padLeft(4, '0');
    return digits.substring(digits.length - 4);
  }

  // ✅ NUEVO: Constantes para manejo de residuales (igual que en payment_form_screen)
  static const double _residualThreshold = 0.50; // Hasta 50 centavos se considera residual pequeño
  static const double _roundingTolerance = 0.01; // 1 centavo de tolerancia para validación

  @override
  void initState() {
    super.initState();
    _selectedDate = _normalizeDate(DateTime.now());
    _loadDailyLoans();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRouteObserver();
    });
  }

  // Observador de rutas mínimo (puede ampliarse)
  void _setupRouteObserver() {
    final route = ModalRoute.of(context);
    if (route != null) {
      route.addScopedWillPopCallback(() async {
        return true;
      });
    }
  }

  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime? _toDateSafe(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return DateTime(v.year, v.month, v.day);
    if (v is int) {
      try {
        final dt = DateTime.fromMillisecondsSinceEpoch(v);
        return DateTime(dt.year, dt.month, dt.day);
      } catch (_) {
        return null;
      }
    }
    if (v is String) {
      try {
        final dt = DateTime.parse(v);
        return DateTime(dt.year, dt.month, dt.day);
      } catch (_) {
        try {
          final parts = v.split(RegExp(r'[/\-]'));
          if (parts.length >= 3) {
            final d = int.parse(parts[0]);
            final m = int.parse(parts[1]);
            final y = int.parse(parts[2]);
            return DateTime(y, m, d);
          }
        } catch (_) {}
      }
    }
    return null;
  }

  List<DateTime> _generatePaymentDatesFallback(LoanModel loan) {
    final start = loan.startDate;
    final int n = loan.termValue;
    final freq = loan.paymentFrequency.toLowerCase();
    if (n <= 0) return [];

    List<DateTime> dates = [];
    DateTime cur = DateTime(start.year, start.month, start.day);
    for (int i = 0; i < n; i++) {
      if (i > 0) {
        if (freq == 'diario') cur = cur.add(const Duration(days: 1));
        else if (freq == 'semanal') cur = cur.add(const Duration(days: 7));
        else if (freq == 'quincenal') cur = cur.add(const Duration(days: 15));
        else {
          int year = cur.year;
          int month = cur.month + 1;
          year += (month - 1) ~/ 12;
          month = ((month - 1) % 12) + 1;
          int day = cur.day;
          int lastDayOfMonth = DateTime(year, month + 1, 0).day;
          if (day > lastDayOfMonth) day = lastDayOfMonth;
          cur = DateTime(year, month, day);
        }
      }
      dates.add(DateTime(cur.year, cur.month, cur.day));
    }
    return dates;
  }

  Future<void> _loadDailyLoans() async {
    setState(() {
      _isLoading = true;
      _dailyLoans = [];
      _clientNamesMap.clear();
      _amountsDueToday.clear();
      _loadErrorMessage = null;
    });

    try {
      debugPrint('🔄 Cargando préstamos desde la base de datos...');
      final allLoans = await _loanRepository.getAllLoans();
      debugPrint('📊 Total de préstamos encontrados: ${allLoans?.length ?? 0}');

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
          final status = loan.status.toLowerCase();
          if (status == 'pagado' || status == 'cancelado') continue;

          final rawDates = loan.paymentDates;
          List<DateTime> paymentDates = [];
          if (rawDates.isNotEmpty) {
            for (final raw in rawDates) {
              final dt = _toDateSafe(raw);
              if (dt != null) paymentDates.add(dt);
            }
          }

          if (paymentDates.isEmpty) {
            paymentDates = _generatePaymentDatesFallback(loan);
          }

          bool hasToday = paymentDates.any((pd) => pd.year == day.year && pd.month == day.month && pd.day == day.day);

          if (!hasToday && loan.dueDate != null) {
            final due = DateTime(loan.dueDate.year, loan.dueDate.month, loan.dueDate.day);
            if (due.year == day.year && due.month == day.month && due.day == day.day) {
              hasToday = true;
            }
          }

          if (hasToday) {
            final cuota = loan.calculatedPaymentAmount ?? 0.0;
            final saldo = loan.remainingBalance ?? 0.0;
            double amount = cuota;

            bool shouldShowLoan = true;
            if (loan.isFullyPaid || loan.status.toLowerCase() == 'pagado' || saldo <= 0.01) {
              shouldShowLoan = false;
            }
            if (shouldShowLoan && amount <= _roundingTolerance) {
              shouldShowLoan = false;
            }

            if (shouldShowLoan) {
              _amountsDueToday[loan.id ?? loan.clientId ?? UniqueKey().toString()] = amount;
              dailyLoans.add(loan);
            }
          }
        } catch (e) {
          continue;
        }
      }

      // cargar nombres de clientes (únicos)
      final uniqueClientIds = <String>{};
      for (final loan in dailyLoans) {
        final cid = loan.clientId ?? '';
        if (cid.isNotEmpty) uniqueClientIds.add(cid);
      }

      if (uniqueClientIds.isNotEmpty) {
        final futures = uniqueClientIds.map((cid) async {
          try {
            final client = await _clientRepository.getClientById(cid);
            final name = '${client?.name ?? ''} ${client?.lastName ?? ''}'.trim();
            return MapEntry(cid, name.isNotEmpty ? name : 'Cliente desconocido');
          } catch (e) {
            return MapEntry(cid, 'Cliente desconocido');
          }
        }).toList();

        final entries = await Future.wait(futures);
        for (final e in entries) {
          _clientNamesMap[e.key] = e.value;
        }
      }

      // Aplicar orden guardado (si existe)
      final ordered = await _applySavedOrder(dailyLoans);

      if (!mounted) return;
      setState(() {
        _dailyLoans = ordered;
        _isLoading = false;
      });

      debugPrint('📋 RESUMEN FINAL:');
      debugPrint('📋 Préstamos procesados: ${ordered.length}');
      debugPrint('📋 Total a cobrar: ${ordered.fold<double>(0.0, (sum, loan) => sum + (_amountsDueToday[loan.id ?? loan.clientId ?? ''] ?? 0.0))}');
    } catch (e) {
      if (!mounted) return;
      final msg = 'Error al cargar cobros: $e';
      setState(() {
        _isLoading = false;
        _loadErrorMessage = msg;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<List<LoanModel>> _applySavedOrder(List<LoanModel> loans) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _prefsOrderKeyPrefix + _dateFormatter.format(_selectedDate);
      final saved = prefs.getStringList(key);
      if (saved == null || saved.isEmpty) return loans;

      // Crear mapa id -> loan
      final map = {for (var l in loans) (l.id ?? l.clientId ?? l.hashCode.toString()): l};

      final List<LoanModel> ordered = [];
      for (final id in saved) {
        if (map.containsKey(id)) {
          ordered.add(map[id]!);
          map.remove(id);
        }
      }
      // Añadir los que no están en saved al final, en su orden original
      ordered.addAll(map.values);
      return ordered;
    } catch (e) {
      debugPrint('Error aplicando orden guardado: $e');
      return loans;
    }
  }

  Future<void> _saveCurrentOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _prefsOrderKeyPrefix + _dateFormatter.format(_selectedDate);
      final ids = _dailyLoans.map((l) => l.id ?? l.clientId ?? l.hashCode.toString()).toList();
      await prefs.setStringList(key, ids);
      debugPrint('Orden guardado para $key -> $ids');
    } catch (e) {
      debugPrint('Error guardando orden: $e');
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
    final totalAmount = _dailyLoans.fold<double>(0.0, (sum, loan) {
      final key = loan.id?.toString() ?? loan.clientId?.toString() ?? '';
      return sum + (_amountsDueToday[key] ?? 0.0);
    });

    final residualLoans = _dailyLoans.where((loan) => (loan.remainingBalance ?? 0) <= _residualThreshold).length;
    final almostPaidLoans = _dailyLoans.where((loan) {
      final saldo = loan.remainingBalance ?? 0;
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
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('Préstamos Vencidos', _dailyLoans.length.toString(), Icons.account_balance_wallet),
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

  Widget _buildLoanTile(LoanModel loan) {
    final clientKey = loan.clientId?.toString() ?? '';
    final clientName = _clientNamesMap[clientKey] ?? 'Cliente desconocido';
    final loanIdDisplay = _getShortLoanId(loan);
    final dueDateText = loan.dueDate != null ? _dateFormatter.format(loan.dueDate!) : 'Fecha desconocida';
    final key = loan.id?.toString() ?? loan.clientId?.toString() ?? '';
    final amountDueToday = _amountsDueToday[key] ?? 0.0;
    final saldo = loan.remainingBalance ?? 0.0;

    Color? cardColor;
    IconData statusIcon = Icons.account_balance_wallet;
    String statusText = '';

    if (loan.isFullyPaid) {
      cardColor = Colors.green[50];
      statusIcon = Icons.check_circle;
      statusText = 'PAGADO';
    } else if (saldo <= _residualThreshold) {
      cardColor = Colors.orange[50];
      statusIcon = Icons.info;
      statusText = 'RESIDUAL';
    } else if (saldo <= 1.0) {
      cardColor = Colors.blue[50];
      statusIcon = Icons.trending_down;
      statusText = 'CASI PAGADO';
    }

    return Card(
      key: ValueKey(key), // IMPORTANTE: cada elemento necesita una Key para reordenamiento
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: cardColor,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Icon(statusIcon, color: Colors.white),
        ),
        title: Row(
          children: [
            Expanded(child: Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold))),
            if (statusText.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Préstamo #$loanIdDisplay • Vence: $dueDateText'),
            if (saldo <= _residualThreshold)
              Text(
                'Saldo residual: ${_currencyFormatter.format(saldo)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicador de monto
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _currencyFormatter.format(amountDueToday),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                if (saldo <= _residualThreshold)
                  Text(
                    'Residual',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            // Handle para arrastrar (mejor experiencia que long-press en algunos casos)
            ReorderableDragStartListener(
              index: _dailyLoans.indexOf(loan),
              child: const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Icon(Icons.drag_handle),
              ),
            ),
          ],
        ),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PaymentFormScreen(loan: loan)),
          );

          if (result == true) {
            setState(() {
              _isLoading = true;
            });

            await Future.delayed(const Duration(milliseconds: 1000));
            await _loadDailyLoans();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Lista actualizada automáticamente'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
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
    if (_dailyLoans.isEmpty) return const Center(child: Text('No hay cobros programados para esta fecha.'));

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: _dailyLoans.length,
      onReorder: (oldIndex, newIndex) async {
        setState(() {
          if (oldIndex < newIndex) newIndex -= 1;
          final item = _dailyLoans.removeAt(oldIndex);
          _dailyLoans.insert(newIndex, item);
        });
        await _saveCurrentOrder();
      },
      buildDefaultDragHandles: false, // usamos nuestro propio ReorderableDragStartListener
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });
              await _loadDailyLoans();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔄 Lista actualizada'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
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
        Text(title, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 6),
        Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
