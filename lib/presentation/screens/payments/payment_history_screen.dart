import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
import 'package:loan_app/presentation/screens/loans/loan_detail_screen.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final ClientRepository _clientRepository = ClientRepository();
  final LoanRepository _loanRepository = LoanRepository();

  List<LoanModel> _paidLoans = [];
  final Map<String, String> _clientNamesMap = {};
  bool _isLoading = true;
  String? _loadErrorMessage;

  static const Color _primaryBlue = Color(0xFF1E88E5);
  static const Color _secondaryGreen = Color(0xFF43A047);

  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadPaidLoans();
  }

  String _getShortLoanId(LoanModel loan) {
    final id = loan.id ?? '';
    if (id.isEmpty) return '00000';
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '00000';
    if (digits.length <= 5) {
      return digits.padLeft(5, '0');
    } else {
      return digits.substring(digits.length - 5);
    }
  }

  Future<void> _loadPaidLoans() async {
    setState(() {
      _isLoading = true;
      _paidLoans = [];
      _clientNamesMap.clear();
      _loadErrorMessage = null;
    });

    try {
      final allLoans = await _loanRepository.getAllLoans();
      if (allLoans == null || allLoans.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _paidLoans = [];
        });
        return;
      }

      // Manejo robusto de nulos y estado
      final paidLoans = allLoans
          .where((loan) =>
              (loan.status ?? '').toLowerCase().trim() == 'pagado' ||
              (loan.remainingBalance ?? 0.0) <= 0.01)
          .toList();

      // ORDENAR por fecha de último pago (más reciente primero)
      paidLoans.sort((a, b) {
        DateTime aDate;
        DateTime bDate;

        if (a.payments != null && a.payments!.isNotEmpty) {
          aDate = a.payments!.reduce((x, y) => x.date.isAfter(y.date) ? x : y).date;
        } else if (a.dueDate != null) {
          aDate = a.dueDate!;
        } else {
          aDate = a.startDate ?? DateTime(2000);
        }

        if (b.payments != null && b.payments!.isNotEmpty) {
          bDate = b.payments!.reduce((x, y) => x.date.isAfter(y.date) ? x : y).date;
        } else if (b.dueDate != null) {
          bDate = b.dueDate!;
        } else {
          bDate = b.startDate ?? DateTime(2000);
        }

        // Más recientes primero
        return bDate.compareTo(aDate);
      });

      await _loadClientNames(paidLoans);

      if (!mounted) return;
      setState(() {
        _paidLoans = paidLoans;
        _isLoading = false;
      });

      debugPrint('🎯 RESUMEN HISTORIAL: ${paidLoans.length} préstamos pagados');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadErrorMessage = 'Error al cargar historial: $e';
      });
      debugPrint('❌ ERROR cargando historial: $e');
    }
  }

  Future<void> _loadClientNames(List<LoanModel> loans) async {
    final clientIds = <String>{};
    for (final loan in loans) {
      final cid = loan.clientId?.toString().trim();
      if (cid != null && cid.isNotEmpty) clientIds.add(cid);
    }

    if (clientIds.isEmpty) return;

    for (final clientId in clientIds) {
      try {
        final client = await _clientRepository.getClientById(clientId);
        if (client != null) {
          final name = '${client.name ?? ''} ${client.lastName ?? ''}'.trim();
          _clientNamesMap[clientId] = name.isNotEmpty ? name : 'Cliente desconocido';
        } else {
          _clientNamesMap[clientId] = 'Cliente no encontrado';
        }
      } catch (e) {
        _clientNamesMap[clientId] = 'Error al cargar';
      }
    }
  }

  Widget _buildLoanTile(LoanModel loan) {
    final clientKey = loan.clientId?.toString() ?? '';
    String clientName = _clientNamesMap[clientKey] ?? 'Cliente no disponible';

    // Mejora: Si el cliente no existe, muestra un mensaje más amigable y un ícono de advertencia
    bool clienteDesconocido = clientName == 'Cliente no encontrado' || clientName == 'Cliente desconocido' || clientName == 'Cliente no disponible';
    if (clienteDesconocido) {
      clientName = 'Cliente eliminado';
    }

    // Mostrar monto del préstamo en vez de ID si lo prefieres
    final loanAmountDisplay = loan.amount != null
        ? _currencyFormatter.format(loan.amount)
        : 'Monto desconocido';

    DateTime? lastPaymentDate;
    if (loan.payments != null && loan.payments!.isNotEmpty) {
      lastPaymentDate = loan.payments!.reduce((a, b) => a.date.isAfter(b.date) ? a : b).date;
    }

    // Si no hay pagos ni dueDate, muestra la fecha de creación como último recurso
    final paidDateText = lastPaymentDate != null
        ? _dateFormatter.format(lastPaymentDate)
        : loan.dueDate != null
            ? _dateFormatter.format(loan.dueDate!)
            : loan.startDate != null
                ? _dateFormatter.format(loan.startDate!)
                : 'Fecha no registrada';

    final totalPaid = loan.totalAmountToPay ?? loan.amount ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: clienteDesconocido
            ? const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32)
            : Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.check_circle, color: _primaryBlue, size: 22),
              ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                clientName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: clienteDesconocido ? Colors.orange : Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _secondaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _secondaryGreen.withOpacity(0.3)),
              ),
              child: const Text(
                'PAGADO',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _secondaryGreen),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // Muestra el monto del préstamo y la fecha de pago
            Text('Préstamo: $loanAmountDisplay • Pagado: $paidDateText'),
            Text(
              'Monto: ${_currencyFormatter.format(totalPaid)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _currencyFormatter.format(totalPaid),
              style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryBlue, fontSize: 16),
            ),
            const Text(
              'Pagado',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        onTap: () {
          // Verifica que el préstamo aún existe antes de navegar
          if (loan.id != null && loan.id.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LoanDetailScreen(loan: loan)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se puede mostrar el detalle de este préstamo.')),
            );
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
              const Icon(Icons.error_outline, color: Colors.red, size: 50),
              const SizedBox(height: 12),
              Text(_loadErrorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadPaidLoans,
                style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_paidLoans.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 50, color: Colors.grey),
            SizedBox(height: 12),
            Text('No hay préstamos pagados aún.'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 16.0),
      itemCount: _paidLoans.length,
      itemBuilder: (context, index) => _buildLoanTile(_paidLoans[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Préstamos Pagados'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }
}