// lib/presentation/screens/payments/payment_history_screen.dart
//#################################################
//#  Pantalla de Historial de Préstamos Pagados   #
//#  Muestra SOLO préstamos con estado 'pagado'.  #
//#  Incluye resumen, manejo defensivo y formato  #
//#  de IDs en 5 dígitos (heredado de tu estilo). #
//#################################################

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
// ✅ Importar la pantalla de detalle
import 'package:loan_app/presentation/screens/loans/loan_detail_screen.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  // Repositorios
  final ClientRepository _clientRepository = ClientRepository();
  final LoanRepository _loanRepository = LoanRepository();

  // Estado
  List<LoanModel> _paidLoans = [];
  final Map<String, String> _clientNamesMap = {};
  bool _isLoading = true;
  String? _loadErrorMessage;

  // Formateadores / constantes (mantenidos de tu estilo)
  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
  static const int _expectedIdDigits = 5;

  @override
  void initState() {
    super.initState();
    _loadPaidLoans();
  }

  /// Formatea un ID en 5 dígitos (igual que en tu código original)
  String _formatIdAsFiveDigits(dynamic rawId) {
    if (rawId == null) return '00000';
    
    final rawString = rawId.toString();
    // Extraer SOLO los dígitos
    final digitsOnly = rawString.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (digitsOnly.isEmpty) {
      // Si no hay dígitos, usar 00000
      return '00000';
    } else if (digitsOnly.length <= 5) {
      // Completar con ceros a la izquierda
      return digitsOnly.padLeft(5, '0');
    } else {
      // Tomar los últimos 5 dígitos
      return digitsOnly.substring(digitsOnly.length - 5);
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
      if (allLoans == null) {
        throw Exception('Respuesta nula de la base de datos');
      }

      // ✅ FILTRO ROBUSTO: solo préstamos NO NULOS y con status 'pagado'
      final paidLoans = allLoans
          .where((loan) => 
              loan != null && 
              loan.status != null && 
              loan.status == 'pagado')
          .toList();

      // Cargar nombres de clientes
      final uniqueClientIds = <String>{};
      for (final loan in paidLoans) {
        final cid = loan.clientId?.toString()?.trim();
        if (cid != null && cid.isNotEmpty) {
          uniqueClientIds.add(cid);
        }
      }

      if (uniqueClientIds.isNotEmpty) {
        final clientFutures = uniqueClientIds.map((cid) async {
          try {
            final client = await _clientRepository.getClientById(cid);
            final name = '${client?.name ?? ''} ${client?.lastName ?? ''}'.trim();
            return MapEntry(cid, name.isEmpty ? 'Cliente desconocido' : name);
          } catch (_) {
            return MapEntry(cid, 'Cliente desconocido');
          }
        });

        final clientEntries = await Future.wait(clientFutures);
        for (final entry in clientEntries) {
          _clientNamesMap[entry.key] = entry.value;
        }
      }

      if (mounted) {
        setState(() {
          _paidLoans = paidLoans;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = 'Error al cargar historial: ${e.toString()}';
        setState(() {
          _isLoading = false;
          _loadErrorMessage = msg;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Widget _buildLoanTile(LoanModel loan) {
    final clientKey = loan.clientId?.toString() ?? '';
    final clientName = _clientNamesMap[clientKey] ?? 'Cliente desconocido';

    // ✅ Usar ID del préstamo (no del cliente) y formatear a 5 dígitos
    final loanIdDisplay = _formatIdAsFiveDigits(loan.id);
    
    // ✅ Obtener la fecha REAL del último pago (más precisa que dueDate)
    DateTime? lastPaymentDate;
    if (loan.payments != null && loan.payments!.isNotEmpty) {
      lastPaymentDate = loan.payments!.reduce((a, b) => a.date.isAfter(b.date) ? a : b).date;
    }
    final paidDateText = lastPaymentDate != null 
        ? _dateFormatter.format(lastPaymentDate) 
        : loan.dueDate != null 
            ? _dateFormatter.format(loan.dueDate!) 
            : 'Fecha no registrada';

    final totalPaid = loan.totalAmountToPay ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.check, color: Colors.white),
        ),
        title: Text(
          'Préstamo #$loanIdDisplay',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$clientName\nPagado: $paidDateText',
          maxLines: 2,
        ),
        trailing: Text(
          _currencyFormatter.format(totalPaid),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
        ),
        onTap: () {
          // ✅ Navegar al detalle del préstamo
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => LoanDetailScreen(loan: loan)),
          );
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
              ElevatedButton(onPressed: _loadPaidLoans, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    if (_paidLoans.isEmpty) {
      return const Center(child: Text('No hay préstamos pagados aún.'));
    }

    return ListView.builder(
      itemCount: _paidLoans.length,
      itemBuilder: (context, index) => _buildLoanTile(_paidLoans[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Préstamos'),
        centerTitle: true,
        backgroundColor: const Color(0xFF4CAF50), // ✅ Verde para historial
      ),
      body: _buildBody(),
    );
  }
}