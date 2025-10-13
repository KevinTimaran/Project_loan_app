//#################################################
//#  Pantalla de Cobros de Hoy - VERSIÓN DEFINITIVA #
//#  Lógica de fechas completamente revisada       #
//#  + Botones de llamada y WhatsApp               #
//#################################################

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
import 'package:loan_app/presentation/screens/payments/payment_form_screen.dart';
// ✅ NUEVO: Importar url_launcher para llamadas y WhatsApp
import 'package:url_launcher/url_launcher.dart';

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

  final NumberFormat _currency_formatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');

  static const double _residualThreshold = 0.50; // si queda <= esto, considerarlo residual y no mostrar
  static const int _shortIdLength = 5;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadDailyLoans();
  }

  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

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
    if (digits.isEmpty) return id.length <= _shortIdLength ? id : id.substring(0, _shortIdLength);
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
    // si queda menos o igual que el threshold (ej: centavos residuales), no mostrar
    if (remainingBalance <= _residualThreshold) {
      return true;
    }

    return false;
  }

  bool _hasPaymentForDate(LoanModel loan, DateTime date) {
    if (loan.payments.isEmpty) return false;
    final target = _normalizeDate(date);
    for (final p in loan.payments) {
      if (_normalizeDate(p.date) == target) return true;
    }
    return false;
  }

  // Si paymentDates explícitas contienen la fecha, la devuelve; si no, intenta calcularla
  DateTime? _getSpecificInstallmentDate(LoanModel loan, DateTime targetDate) {
    final normalizedTarget = _normalizeDate(targetDate);

    // 1) buscar en paymentDates guardadas (si existen)
    for (final pd in loan.paymentDates) {
      if (_normalizeDate(pd) == normalizedTarget) return pd;
    }

    // 2) calcular (iterando por las cuotas)
    return _calculateInstallmentDate(loan, normalizedTarget);
  }

  DateTime? _calculateInstallmentDate(LoanModel loan, DateTime targetDate) {
    final start = _normalizeDate(loan.startDate);
    final freq = loan.paymentFrequency.toLowerCase();
    final term = loan.termValue;

    for (int i = 0; i < term; i++) {
      DateTime candidate;
      switch (freq) {
        case 'diario':
          candidate = start.add(Duration(days: i));
          break;
        case 'semanal':
          candidate = start.add(Duration(days: i * 7));
          break;
        case 'quincenal':
          candidate = start.add(Duration(days: i * 15));
          break;
        case 'mensual':
          final int monthsToAdd = i;
          int year = start.year + ((start.month - 1 + monthsToAdd) ~/ 12);
          int month = ((start.month - 1 + monthsToAdd) % 12) + 1;
          int day = start.day;
          final lastDay = DateTime(year, month + 1, 0).day;
          if (day > lastDay) day = lastDay;
          candidate = DateTime(year, month, day);
          break;
        default:
          candidate = start.add(Duration(days: i * 30));
      }
      if (_normalizeDate(candidate) == targetDate) return candidate;
    }

    return null;
  }

  bool _shouldShowLoanToday(LoanModel loan, DateTime targetDate) {
    if (_shouldExcludeLoan(loan)) return false;

    final installmentDate = _getSpecificInstallmentDate(loan, targetDate);
    if (installmentDate == null) return false;

    // si ya existe un pago para esa fecha (exacta), no mostrar
    if (_hasPaymentForDate(loan, installmentDate)) return false;

    final remaining = loan.remainingBalance ?? 0.0;
    if (remaining <= 0.0) return false;

    return true;
  }

  void _debugLoanStatus(LoanModel loan, DateTime targetDate) {
    debugPrint('🔍 ANALIZANDO PRÉSTAMO: ${loan.clientName} (${loan.id})');
    debugPrint('   Fecha objetivo: ${_dateFormatter.format(targetDate)}');
    debugPrint('   Inicio: ${_dateFormatter.format(loan.startDate)}, Frec: ${loan.paymentFrequency}, Cuotas: ${loan.termValue}');
    debugPrint('   Remaining: ${loan.remainingBalance}  CalcCuota: ${loan.calculatedPaymentAmount}');
    final installmentDate = _getSpecificInstallmentDate(loan, targetDate);
    debugPrint('   Fecha cuota encontrada: ${installmentDate != null ? _dateFormatter.format(installmentDate) : "NINGUNA"}');
    debugPrint('   Pagos en la fecha: ${_hasPaymentForDate(loan, targetDate)}');
    debugPrint('   Excluir?: ${_shouldExcludeLoan(loan)}');
    debugPrint('   Mostrar hoy?: ${_shouldShowLoanToday(loan, targetDate)}');
    if (loan.paymentDates.isNotEmpty) {
      debugPrint('   paymentDates registrados:');
      for (final d in loan.paymentDates) debugPrint('     - ${_dateFormatter.format(d)}');
    }
    if (loan.payments.isNotEmpty) {
      debugPrint('   pagos realizados:');
      for (final p in loan.payments) debugPrint('     - ${_dateFormatter.format(p.date)} -> ${p.amount}');
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
      final allLoans = await _loan_repository_getAll();
      if (!mounted) return;

      if (allLoans == null || allLoans.isEmpty) {
        setState(() {
          _isLoading = false;
          _dailyLoans = [];
        });
        return;
      }

      final target = _normalizeDate(_selectedDate);
      final List<LoanModel> daily = [];
      final Set<String> clientIds = {};

      debugPrint('🔄 Analizando ${allLoans.length} préstamos para ${_dateFormatter.format(target)}');

      for (final loan in allLoans) {
        if (loan == null) continue;
        _debugLoanStatus(loan, target);
        if (_shouldShowLoanToday(loan, target)) {
          daily.add(loan);
          clientIds.add(loan.clientId);
          debugPrint('✅ Incluido: ${loan.clientName}');
        } else {
          debugPrint('❌ Excluido: ${loan.clientName}');
        }
      }

      await _loadClientNames(clientIds);

      if (!mounted) return;
      setState(() {
        _dailyLoans = daily;
        _isLoading = false;
      });

      debugPrint('🎯 Resultado: ${daily.length} préstamos para cobrar');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadErrorMessage = 'Error al cargar los cobros: $e';
      });
      debugPrint('❌ ERROR cargando préstamos: $e');
    }
  }

  // wrapper seguro para obtener todos los loans (nombre no cambiado)
  Future<List<LoanModel>?> _loan_repository_getAll() async {
    try {
      return await _loanRepository.getAllLoans();
    } catch (e) {
      debugPrint('Error repo getAllLoans: $e');
      return null;
    }
  }

  // wrapper seguro para obtener por id (nombre no cambiado)
  Future<LoanModel?> _loan_repository_getById(String? id) async {
    if (id == null) return null;
    try {
      return await _loanRepository.getLoanById(id);
    } catch (e) {
      debugPrint('Error repo getLoanById: $e');
      return null;
    }
  }

  Future<void> _handlePaymentSuccess(LoanModel paidLoan) async {
    debugPrint('💾 Pago registrado, actualizando lista para: ${paidLoan.clientName}');
    try {
      final updated = await _loan_repository_getById(paidLoan.id);
      if (updated != null && mounted) {
        final shouldShow = _shouldShowLoanToday(updated, _selectedDate);
        if (!shouldShow) {
          setState(() => _dailyLoans.removeWhere((l) => l.id == paidLoan.id));
          debugPrint('🗑️ Removido después de pago: ${paidLoan.clientName}');
        } else {
          final idx = _dailyLoans.indexWhere((l) => l.id == paidLoan.id);
          if (idx >= 0) {
            setState(() => _dailyLoans[idx] = updated);
            debugPrint('🔄 Actualizado en lista: ${paidLoan.clientName}');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error en handlePaymentSuccess: $e');
      if (mounted) await _loadDailyLoans();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
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

  // ✅ NUEVO: Método para llamar al cliente
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint('No se pudo llamar al número $phoneNumber');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('No se puede realizar la llamada a $phoneNumber')),
         );
      }
    }
  }

  // ✅ NUEVO: Método para enviar mensaje por WhatsApp
  Future<void> _sendWhatsAppMessage(String phoneNumber, String message) async {
    final Uri launchUri = Uri.parse(
      'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint('No se pudo abrir WhatsApp con $phoneNumber');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('WhatsApp no está disponible o el número es incorrecto.')),
         );
      }
    }
  }

  Widget _buildHeader(BuildContext context) {
    final dateLabel = _dateFormatter.format(_selectedDate);
    final totalAmount = _dailyLoans.fold<double>(0.0, (s, l) => s + (l.calculatedPaymentAmount ?? 0.0));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Fecha de cobro:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          InkWell(
            onTap: () => _selectDate(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(dateLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
            ),
          )
        ]),
        const SizedBox(height: 16),
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _buildSummaryItem('Préstamos', _dailyLoans.length.toString(), Icons.account_balance_wallet, Colors.blue),
              _buildSummaryItem('Total', _currency_formatter.format(totalAmount), Icons.attach_money, Colors.green),
            ]),
          ),
        )
      ]),
    );
  }

  Widget _buildLoanTile(LoanModel loan) {
    final clientName = _clientNamesMap[loan.clientId] ?? 'Cliente no disponible';
    final loanIdDisplay = _getShortLoanId(loan);
    final remaining = loan.remainingBalance ?? 0.0;
    final calcPayment = loan.calculatedPaymentAmount ?? 0.0;

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.account_balance_wallet;
    String statusText = 'PENDIENTE';

    if (remaining <= _residualThreshold) {
      statusColor = Colors.orange;
      statusIcon = Icons.info;
      statusText = 'RESIDUAL';
    } else if (remaining <= calcPayment) {
      statusColor = Colors.blue;
      statusIcon = Icons.trending_down;
      statusText = 'ÚLTIMA CUOTA';
    } else if (remaining > calcPayment * 2) {
      statusColor = Colors.red;
      statusIcon = Icons.warning;
      statusText = 'ALTO SALDO';
    }

    return Card(
      key: ValueKey(loan.id),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(22)),
          child: Icon(statusIcon, color: statusColor, size: 22),
        ),
        title: Row(children: [
          Expanded(
            child: Text(clientName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withOpacity(0.3))),
            child: Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
          ),
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 4),
          Text('Préstamo #$loanIdDisplay', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          if (remaining <= _residualThreshold)
            Text('Saldo residual: ${_currency_formatter.format(remaining)}', style: TextStyle(fontSize: 12, color: Colors.orange[800], fontWeight: FontWeight.w500)),
          Text('Saldo total: ${_currency_formatter.format(remaining)}', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ]),
        // ✅ CORREGIDO: Reemplazado trailing anterior por un Row para evitar overflow
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Contenedor para el monto y la etiqueta "Hoy"
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currency_formatter.format(calcPayment),
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
            // Espaciado entre texto y botones
            const SizedBox(width: 8),
            // Contenedor para los botones de acción
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.phone, color: Colors.green),
                  onPressed: () => _makePhoneCall('3206451037'), // Reemplaza con el número real del cliente
                ),
                IconButton(
                  icon: const Icon(Icons.chat, color: Colors.green),
                  onPressed: () => _sendWhatsAppMessage('3206451037', 'Hola, ¿cómo va el pago del préstamo #${_getShortLoanId(loan)}?'), // Reemplaza con número real
                ),
              ],
            ),
          ],
        ),
        onTap: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentFormScreen(loan: loan)));
          if (result == true && mounted) {
            await _handlePaymentSuccess(loan);
          }
        },
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _dailyLoans.removeAt(oldIndex);
      _dailyLoans.insert(newIndex, item);
    });
    // Si quieres persistir el orden, podemos guardar un campo en LoanModel o en otro storage.
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_loadErrorMessage != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text(_loadErrorMessage!, textAlign: TextAlign.center)));
    }

    if (_dailyLoans.isEmpty) {
      return const Center(child: Text('No hay cobros para esta fecha'));
    }

    return ReorderableListView.builder(
      onReorder: _onReorder,
      itemCount: _dailyLoans.length,
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) {
        final loan = _dailyLoans[index];
        return _buildLoanTile(loan);
      },
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
      body: Column(children: [
        _buildHeader(context),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon, Color color) {
    return Column(children: [
      Icon(icon, size: 32, color: color),
      const SizedBox(height: 8),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
    ]);
  }
}
