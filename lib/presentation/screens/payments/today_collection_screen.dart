// lib/presentation/screens/payments/today_collection_screen.dart
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
  // ✅ MEJORADO: Generar ID corta y legible
  String _getShortLoanId(LoanModel loan) {
    final id = loan.id;
    if (id.isEmpty) return '00000';
    
    // Extraer solo los números del ID
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (digits.isEmpty) return '00000';
    
    // Usar los últimos 4-5 dígitos para una ID más corta
    if (digits.length <= 4) {
      return digits.padLeft(4, '0');
    } else {
      return digits.substring(digits.length - 4);
    }
  }
  
  // ✅ NUEVO: Constantes para manejo de residuales (igual que en payment_form_screen)
  static const double _residualThreshold = 0.50; // Hasta 50 centavos se considera residual pequeño
  static const double _roundingTolerance = 0.01; // 1 centavo de tolerancia para validación

  @override
  void initState() {
    super.initState();
    _selectedDate = _normalizeDate(DateTime.now());
    _loadDailyLoans();
    
    // ✅ NUEVO: Escuchar cambios cuando se regrese a esta pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRouteObserver();
    });
  }

  // ✅ NUEVO: Configurar observador de rutas para actualización automática
  void _setupRouteObserver() {
    final route = ModalRoute.of(context);
    if (route != null) {
      route.addScopedWillPopCallback(() async {
        // Se ejecuta cuando se va a salir de la pantalla
        return true;
      });
    }
  }

  // ✅ NUEVO: Método para actualizar automáticamente cuando se regrese
  Future<void> _refreshOnReturn() async {
    // Pequeño delay para asegurar que los datos se hayan guardado
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      await _loadDailyLoans();
    }
  }

  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Intenta convertir una entrada (DateTime | String | int) a DateTime o devuelve null.
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
        // intentar parse flex (dd/MM/yyyy)
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

  /// Genera paymentDates si el loan no los tiene (fallback).
  /// Usa frecuencia y termValue para crear una lista de fechas.
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
          // mensual - añadir months de manera segura (evitar overflow de días)
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
      List<LoanModel> dailyLoans = []; 

    try {
      // ✅ MEJORADO: Forzar recarga desde la base de datos
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

      dailyLoans = []; 

      final day = _normalizeDate(_selectedDate);
      final List<LoanModel> found = [];

      for (final loan in allLoans) {
        try {
          if (loan == null) continue;
          final status = loan.status.toLowerCase();
          if (status == 'pagado' || status == 'cancelado') continue;

          // 1) Obtener paymentDates del loan (puede venir como List<DateTime> o List<String>)
          final rawDates = loan.paymentDates;
          List<DateTime> paymentDates = [];
          if (rawDates.isNotEmpty) {
            for (final raw in rawDates) {
              final dt = _toDateSafe(raw);
              if (dt != null) paymentDates.add(dt);
            }
          }

          // 2) Si no hay paymentDates generados, intentar fallback (a veces el modelo no las guardó)
          if (paymentDates.isEmpty) {
            paymentDates = _generatePaymentDatesFallback(loan);
          }

          // 3) Verificar si alguna fecha coincide con el día seleccionado
          bool hasToday = paymentDates.any((pd) => pd.year == day.year && pd.month == day.month && pd.day == day.day);

          // 4) Fallback a dueDate por compatibilidad (último recurso)
          if (!hasToday && loan.dueDate != null) {
            final due = DateTime(loan.dueDate.year, loan.dueDate.month, loan.dueDate.day);
            if (due.year == day.year && due.month == day.month && due.day == day.day) {
              hasToday = true;
            }
          }

          if (hasToday) {
              // ✅ MEJORADO: Aplicar lógica inteligente de residuales
              final cuota = loan.calculatedPaymentAmount ?? 0.0;
              final saldo = loan.remainingBalance ?? 0.0;
              double amount = cuota;

              // ✅ DEBUG: Log para entender el comportamiento
              debugPrint('🔍 LOAN DEBUG - ID: ${loan.id}');
              debugPrint('🔍 LOAN DEBUG - Cuota: $cuota, Saldo: $saldo');
              debugPrint('🔍 LOAN DEBUG - isFullyPaid: ${loan.isFullyPaid}');
              debugPrint('🔍 LOAN DEBUG - Status: ${loan.status}');
              debugPrint('🔍 LOAN DEBUG - Total pagado: ${loan.totalPaid}');
              debugPrint('🔍 LOAN DEBUG - Número de pagos: ${loan.payments.length}');
              debugPrint('🔍 LOAN DEBUG - Monto total a pagar: ${loan.totalAmountToPay}');

              // ✅ MEJORADO: Lógica más robusta para determinar si mostrar el préstamo
              bool shouldShowLoan = true;
              
              // Verificar si está completamente pagado con múltiples criterios
              if (loan.isFullyPaid || 
                  loan.status.toLowerCase() == 'pagado' ||
                  saldo <= 0.01) {
                shouldShowLoan = false;
                debugPrint('🔍 LOAN DEBUG - Préstamo completamente pagado, no mostrando');
              }
              
              // Verificar si el monto a cobrar es válido
              if (shouldShowLoan && amount <= _roundingTolerance) {
                shouldShowLoan = false;
                debugPrint('🔍 LOAN DEBUG - Monto muy pequeño, no mostrando');
              }

              if (shouldShowLoan) {
                debugPrint('🔍 LOAN DEBUG - Agregando préstamo con monto: $amount');
                _amountsDueToday[loan.id!] = amount;
                dailyLoans.add(loan);
              } else {
                debugPrint('🔍 LOAN DEBUG - No agregando préstamo');
              }
          }
        } catch (e) {
          // ignore individual loan errors
          // print('ERR loan check: $e');
          continue;
        }
      }

      // ✅ CORREGIDO: cargar nombres de clientes (únicos)
      final uniqueClientIds = <String>{};
      for (final loan in dailyLoans) {
        final cid = loan.clientId;
        if (cid.isNotEmpty) uniqueClientIds.add(cid);
      }
      
      debugPrint('🔍 CLIENT DEBUG - IDs únicos encontrados: $uniqueClientIds');
      if (uniqueClientIds.isNotEmpty) {
        final futures = uniqueClientIds.map((cid) async {
          try {
            debugPrint('🔍 CLIENT DEBUG - Buscando cliente con ID: $cid');
            final client = await _clientRepository.getClientById(cid);
            final name = '${client?.name ?? ''} ${client?.lastName ?? ''}'.trim();
            debugPrint('🔍 CLIENT DEBUG - Cliente encontrado: $name');
            return MapEntry(cid, name.isNotEmpty ? name : 'Cliente desconocido');
          } catch (e) {
            debugPrint('🔍 CLIENT DEBUG - Error buscando cliente $cid: $e');
            return MapEntry(cid, 'Cliente desconocido');
          }
        }).toList();

        final entries = await Future.wait(futures);
        for (final e in entries) {
          _clientNamesMap[e.key] = e.value;
        }
      }

      if (!mounted) return;
      setState(() {
        _dailyLoans = dailyLoans; // ✅ CORREGIDO: Usar dailyLoans en lugar de found
        _isLoading = false;
      });
      
      // ✅ DEBUG: Resumen final
      debugPrint('📋 RESUMEN FINAL:');
      debugPrint('📋 Préstamos procesados: ${dailyLoans.length}');
      debugPrint('📋 Total a cobrar: ${dailyLoans.fold<double>(0.0, (sum, loan) => sum + (_amountsDueToday[loan.id!] ?? 0.0))}');
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

    // ✅ MEJORADO: Calcular estadísticas adicionales
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

    // ✅ MEJORADO: Usar ID corta y legible
    final loanIdDisplay = _getShortLoanId(loan);

    final dueDateText = loan.dueDate != null ? _dateFormatter.format(loan.dueDate!) : 'Fecha desconocida';
    final key = loan.id?.toString() ?? loan.clientId?.toString() ?? '';
    final amountDueToday = _amountsDueToday[key] ?? 0.0;
    final saldo = loan.remainingBalance ?? 0.0;

    // ✅ MEJORADO: Determinar el tipo de indicador visual
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
        trailing: Column(
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
        onTap: () async {
          // ✅ MEJORADO: Actualización automática sin salir de la pantalla
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PaymentFormScreen(loan: loan)),
          );
          
          // ✅ Actualizar automáticamente si se registró un pago
          if (result == true) {
            // Mostrar indicador de carga mientras se actualiza
            setState(() {
              _isLoading = true;
            });
            
            // ✅ MEJORADO: Esperar un poco más para asegurar que los datos se guarden
            await Future.delayed(const Duration(milliseconds: 1000));
            
            // Recargar datos
            await _loadDailyLoans();
            
            // Mostrar mensaje de confirmación
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
        // ✅ NUEVO: Botón de actualización manual
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
