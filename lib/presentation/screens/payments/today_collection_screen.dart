//#################################################
//#  Pantalla de Cobros de Hoy - VERSIÓN DEFINITIVA #
//#  Lógica de fechas completamente revisada       #
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
  bool _isLoading = true;
  String? _loadErrorMessage;

  late DateTime _selectedDate;

  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
  
  static const double _residualThreshold = 0.50;
  static const int _shortIdLength = 5;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadDailyLoans();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _loadClientNames(Set<String> clientIds) async {
    if (clientIds.isEmpty) return;

    for (final clientId in clientIds) {
      try {
        final client = await _clientRepository.getClientById(clientId);
        if (client != null) {
          _clientNamesMap[clientId] = '${client.name} ${client.lastName}'.trim();
        } else {
          _clientNamesMap[clientId] = 'Cliente no encontrado';
        }
      } catch (e) {
        _clientNamesMap[clientId] = 'Error al cargar';
      }
    }
  }

  String _getShortLoanId(LoanModel loan) {
    final id = loan.id;
    if (id.isEmpty) return '00000';
    
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '00000';
    
    if (digits.length <= _shortIdLength) {
      return digits.padLeft(_shortIdLength, '0');
    } else {
      return digits.substring(digits.length - _shortIdLength);
    }
  }

  bool _shouldExcludeLoan(LoanModel loan) {
    final status = loan.status.toLowerCase().trim();
    if (status == 'pagado' || status == 'cancelado' || status == 'finalizado') {
      return true;
    }

    final remainingBalance = loan.remainingBalance ?? 0.0;
    if (remainingBalance <= _residualThreshold) {
      return true;
    }

    return false;
  }

  // ✅ CORREGIDO: Verificación de pago por fecha exacta
  bool _hasPaymentForDate(LoanModel loan, DateTime date) {
    if (loan.payments.isEmpty) return false;
    
    final targetDate = _normalizeDate(date);
    
    for (final payment in loan.payments) {
      final paymentDate = _normalizeDate(payment.date);
      if (paymentDate == targetDate) {
        return true; // ✅ Ya hay un pago registrado para esta fecha exacta
      }
    }
    
    return false;
  }

  // ✅ NUEVO: Método para obtener la fecha de cuota específica
  DateTime? _getSpecificInstallmentDate(LoanModel loan, DateTime targetDate) {
    final normalizedTarget = _normalizeDate(targetDate);
    
    // 1. Primero verificar las fechas almacenadas en el préstamo
    for (final paymentDate in loan.paymentDates) {
      final normalizedPaymentDate = _normalizeDate(paymentDate);
      if (normalizedPaymentDate == normalizedTarget) {
        return paymentDate;
      }
    }

    // 2. Si no hay fechas almacenadas, generar la fecha correspondiente
    return _calculateInstallmentDate(loan, normalizedTarget);
  }

  // ✅ NUEVO: Calcular si una fecha específica corresponde a una cuota del préstamo
  DateTime? _calculateInstallmentDate(LoanModel loan, DateTime targetDate) {
    final startDate = _normalizeDate(loan.startDate);
    final frequency = loan.paymentFrequency.toLowerCase();
    final termValue = loan.termValue;

    // Verificar cada cuota posible
    for (int i = 0; i < termValue; i++) {
      DateTime installmentDate;
      
      switch (frequency) {
        case 'diario':
          installmentDate = startDate.add(Duration(days: i));
          break;
        case 'semanal':
          installmentDate = startDate.add(Duration(days: i * 7));
          break;
        case 'quincenal':
          installmentDate = startDate.add(Duration(days: i * 15));
          break;
        case 'mensual':
          int targetMonth = startDate.month + i;
          int targetYear = startDate.year;
          
          while (targetMonth > 12) {
            targetMonth -= 12;
            targetYear += 1;
          }
          
          int day = startDate.day;
          final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
          if (day > lastDay) day = lastDay;
          
          installmentDate = DateTime(targetYear, targetMonth, day);
          break;
        default:
          installmentDate = startDate.add(Duration(days: i * 30));
      }

      if (_normalizeDate(installmentDate) == targetDate) {
        return installmentDate;
      }
    }

    return null;
  }

  // ✅ CORREGIDO: Lógica principal para determinar si un préstamo debe mostrarse hoy
  bool _shouldShowLoanToday(LoanModel loan, DateTime targetDate) {
    // 1. Verificar si el préstamo debe ser excluido
    if (_shouldExcludeLoan(loan)) {
      return false;
    }

    // 2. Obtener la fecha específica de la cuota para hoy
    final installmentDate = _getSpecificInstallmentDate(loan, targetDate);
    if (installmentDate == null) {
      return false; // No hay cuota programada para hoy
    }

    // 3. Verificar si ya se pagó la cuota de hoy
    if (_hasPaymentForDate(loan, installmentDate)) {
      return false; // Ya se pagó la cuota de hoy
    }

    // 4. Verificar que el préstamo aún tenga saldo pendiente
    final remainingBalance = loan.remainingBalance ?? 0.0;
    if (remainingBalance <= 0) {
      return false;
    }

    return true;
  }

  // ✅ NUEVO: Debug detallado
  void _debugLoanStatus(LoanModel loan, DateTime targetDate) {
    debugPrint('🔍 ANALIZANDO PRÉSTAMO: ${loan.clientName}');
    debugPrint('   Fecha objetivo: ${_dateFormatter.format(targetDate)}');
    debugPrint('   Fecha inicio: ${_dateFormatter.format(loan.startDate)}');
    debugPrint('   Frecuencia: ${loan.paymentFrequency}');
    debugPrint('   Cuotas: ${loan.termValue}');
    debugPrint('   Saldo pendiente: ${loan.remainingBalance}');
    
    final installmentDate = _getSpecificInstallmentDate(loan, targetDate);
    debugPrint('   Fecha de cuota calculada: ${installmentDate != null ? _dateFormatter.format(installmentDate) : "NO"}');
    debugPrint('   ¿Tiene pago para esta fecha?: ${_hasPaymentForDate(loan, targetDate)}');
    debugPrint('   ¿Debe excluirse?: ${_shouldExcludeLoan(loan)}');
    debugPrint('   ¿Debe mostrarse hoy?: ${_shouldShowLoanToday(loan, targetDate)}');
    
    // Mostrar todas las fechas de pago del préstamo
    if (loan.paymentDates.isNotEmpty) {
      debugPrint('   Fechas de pago almacenadas:');
      for (int i = 0; i < loan.paymentDates.length; i++) {
        final isToday = _normalizeDate(loan.paymentDates[i]) == _normalizeDate(targetDate);
        debugPrint('     ${i + 1}. ${_dateFormatter.format(loan.paymentDates[i])} ${isToday ? '<-- HOY' : ''}');
      }
    }
    
    // Mostrar pagos realizados
    if (loan.payments.isNotEmpty) {
      debugPrint('   Pagos realizados:');
      for (final payment in loan.payments) {
        final isToday = _normalizeDate(payment.date) == _normalizeDate(targetDate);
        debugPrint('     - ${_dateFormatter.format(payment.date)}: \$${payment.amount} ${isToday ? '<-- HOY' : ''}');
      }
    }
    debugPrint('---');
  }

  Future<void> _loadDailyLoans() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _dailyLoans = [];
      _clientNamesMap.clear();
      _loadErrorMessage = null;
    });

    try {
      final allLoans = await _loanRepository.getAllLoans();
      
      if (!mounted) return;
      
      if (allLoans == null || allLoans.isEmpty) {
        setState(() {
          _isLoading = false;
          _dailyLoans = [];
        });
        return;
      }

      final targetDate = _normalizeDate(_selectedDate);
      final dailyLoans = <LoanModel>[];
      final clientIdsToLoad = <String>{};

      debugPrint('🔄 CARGANDO PRÉSTAMOS PARA: ${_dateFormatter.format(targetDate)}');
      debugPrint('📊 TOTAL DE PRÉSTAMOS A ANALIZAR: ${allLoans.length}');

      for (final loan in allLoans) {
        if (loan == null) continue;
        
        // Debug para cada préstamo
        _debugLoanStatus(loan, targetDate);

        if (_shouldShowLoanToday(loan, targetDate)) {
          dailyLoans.add(loan);
          clientIdsToLoad.add(loan.clientId);
          debugPrint('✅ AGREGADO: ${loan.clientName}');
        } else {
          debugPrint('❌ EXCLUIDO: ${loan.clientName}');
        }
      }

      await _loadClientNames(clientIdsToLoad);

      if (!mounted) return;
      
      setState(() {
        _dailyLoans = dailyLoans;
        _isLoading = false;
      });
      
      debugPrint('🎯 CARGA COMPLETADA: ${dailyLoans.length} préstamos para cobrar');
      
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _loadErrorMessage = 'Error al cargar los cobros: ${e.toString()}';
      });
      
      debugPrint('❌ ERROR: $e');
    }
  }

  Future<void> _handlePaymentSuccess(LoanModel paidLoan) async {
    debugPrint('💾 MANEJANDO PAGO EXITOSO PARA: ${paidLoan.clientName}');
    
    try {
      // Recargar el préstamo actualizado desde la base de datos
      final updatedLoan = await _loanRepository.getLoanById(paidLoan.id);
      if (updatedLoan != null && mounted) {
        
        // Verificar si el préstamo aún debe mostrarse hoy
        final shouldStillShow = _shouldShowLoanToday(updatedLoan, _selectedDate);
        
        if (!shouldStillShow) {
          setState(() {
            _dailyLoans.removeWhere((loan) => loan.id == paidLoan.id);
          });
          debugPrint('🗑️ PRÉSTAMO REMOVIDO: ${paidLoan.clientName}');
        } else {
          final index = _dailyLoans.indexWhere((loan) => loan.id == paidLoan.id);
          if (index >= 0) {
            setState(() {
              _dailyLoans[index] = updatedLoan;
            });
            debugPrint('🔄 PRÉSTAMO ACTUALIZADO: ${paidLoan.clientName}');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ ERROR EN ACTUALIZACIÓN: $e');
      // Si hay error, recargar toda la lista
      if (mounted) {
        await _loadDailyLoans();
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('es', 'ES'),
    );
    
    if (picked != null) {
      final normalized = _normalizeDate(picked);
      if (normalized != _normalizeDate(_selectedDate)) {
        setState(() => _selectedDate = picked);
        await _loadDailyLoans();
      }
    }
  }

  Widget _buildHeader(BuildContext context) {
    final dateLabel = _dateFormatter.format(_selectedDate);
    final totalAmount = _dailyLoans.fold<double>(0.0, (sum, loan) {
      return sum + (loan.calculatedPaymentAmount ?? 0.0);
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fecha de cobro:', 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
              ),
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        dateLabel, 
                        style: const TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold,
                          fontSize: 14
                        )
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(
                    'Préstamos', 
                    _dailyLoans.length.toString(), 
                    Icons.account_balance_wallet,
                    Colors.blue
                  ),
                  _buildSummaryItem(
                    'Total', 
                    _currencyFormatter.format(totalAmount), 
                    Icons.attach_money,
                    Colors.green
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
    final clientName = _clientNamesMap[loan.clientId] ?? 'Cliente no disponible';
    final loanIdDisplay = _getShortLoanId(loan);
    final remainingBalance = loan.remainingBalance ?? 0.0;
    final calculatedPayment = loan.calculatedPaymentAmount ?? 0.0;

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.account_balance_wallet;
    String statusText = 'PENDIENTE';

    if (remainingBalance <= _residualThreshold) {
      statusColor = Colors.orange;
      statusIcon = Icons.info;
      statusText = 'RESIDUAL';
    } else if (remainingBalance <= calculatedPayment) {
      statusColor = Colors.blue;
      statusIcon = Icons.trending_down;
      statusText = 'ÚLTIMA CUOTA';
    } else if (remainingBalance > calculatedPayment * 2) {
      statusColor = Colors.red;
      statusIcon = Icons.warning;
      statusText = 'ALTO SALDO';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(statusIcon, color: statusColor, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                clientName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
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
            const SizedBox(height: 4),
            Text(
              'Préstamo #$loanIdDisplay',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            if (remainingBalance <= _residualThreshold)
              Text(
                'Saldo residual: ${_currencyFormatter.format(remainingBalance)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
            Text(
              'Saldo total: ${_currencyFormatter.format(remainingBalance)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _currencyFormatter.format(calculatedPayment),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: statusColor,
                fontSize: 16,
              ),
            ),
            Text(
              'Hoy',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentFormScreen(loan: loan),
            ),
          );
          
          if (result == true && mounted) {
            await _handlePaymentSuccess(loan);
          }
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
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _loadErrorMessage!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_dailyLoans.isEmpty) {
      return const Center(
        child: Text('No hay cobros para esta fecha'),
      );
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
        title: const Text('Cobros del Día'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadDailyLoans();
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

  Widget _buildSummaryItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}