// lib/presentation/screens/payments/payment_history_screen.dart

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

  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadPaidLoans();
  }

  String _formatIdAsFiveDigits(dynamic rawId) {
    if (rawId == null) return '00000';
    
    final rawString = rawId.toString();
    final digitsOnly = rawString.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (digitsOnly.isEmpty) {
      return '00000';
    } else if (digitsOnly.length <= 5) {
      return digitsOnly.padLeft(5, '0');
    } else {
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

      // ✅ DEBUG: Ver qué préstamos estamos obteniendo
      print('DEBUG: Total de préstamos obtenidos: ${allLoans.length}');
      for (final loan in allLoans) {
        print('DEBUG - Préstamo: id=${loan.id}, clientId=${loan.clientId}, status=${loan.status}');
      }

      // Filtrar préstamos pagados
      final paidLoans = allLoans
          .where((loan) => 
              loan.status != null && 
              loan.status!.toLowerCase() == 'pagado')
          .toList();

      print('DEBUG: Préstamos pagados encontrados: ${paidLoans.length}');

      // ✅ CARGAR NOMBRES DE CLIENTES - MÉTODO MEJORADO
      await _loadClientNames(paidLoans);

      if (mounted) {
        setState(() {
          _paidLoans = paidLoans;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('ERROR en _loadPaidLoans: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadErrorMessage = 'Error al cargar historial: ${e.toString()}';
        });
      }
    }
  }

  // ✅ NUEVO MÉTODO MEJORADO para cargar nombres de clientes
  Future<void> _loadClientNames(List<LoanModel> loans) async {
    for (final loan in loans) {
      final clientId = loan.clientId?.toString().trim();
      
      if (clientId == null || clientId.isEmpty) {
        _clientNamesMap[loan.id] = 'Cliente sin ID';
        continue;
      }

      try {
        print('DEBUG: Buscando cliente con ID: $clientId');
        final client = await _clientRepository.getClientById(clientId);
        
        if (client != null) {
          final name = '${client.name ?? ''} ${client.lastName ?? ''}'.trim();
          _clientNamesMap[loan.id] = name.isNotEmpty ? name : 'Nombre no disponible';
          print('DEBUG: Cliente encontrado - $name');
        } else {
          _clientNamesMap[loan.id] = 'Cliente no encontrado (ID: $clientId)';
          print('DEBUG: Cliente NO encontrado para ID: $clientId');
        }
      } catch (e) {
        print('ERROR buscando cliente $clientId: $e');
        _clientNamesMap[loan.id] = 'Error al cargar cliente';
      }
    }

    // ✅ INTENTAR ALTERNATIVA: Buscar por nombre si está disponible en el loan
    await _tryAlternativeClientLookup(loans);
  }

  // ✅ MÉTODO ALTERNATIVO: Usar clientName del préstamo si está disponible
  Future<void> _tryAlternativeClientLookup(List<LoanModel> loans) async {
    for (final loan in loans) {
      // Si ya tenemos un nombre, no hacer nada
      if (_clientNamesMap[loan.id] != null && 
          !_clientNamesMap[loan.id]!.contains('no encontrado') &&
          !_clientNamesMap[loan.id]!.contains('Error')) {
        continue;
      }

      // Intentar usar clientName del préstamo si está disponible
      if (loan.clientName != null && loan.clientName!.isNotEmpty) {
        _clientNamesMap[loan.id] = loan.clientName!;
        print('DEBUG: Usando clientName del préstamo: ${loan.clientName}');
      }
    }
  }

  Widget _buildLoanTile(LoanModel loan) {
    final clientName = _clientNamesMap[loan.id] ?? 'Cargando...';
    final loanIdDisplay = _formatIdAsFiveDigits(loan.id);
    
    // Obtener fecha del último pago
    DateTime? lastPaymentDate;
    if (loan.payments != null && loan.payments!.isNotEmpty) {
      lastPaymentDate = loan.payments!.reduce((a, b) => a.date.isAfter(b.date) ? a : b).date;
    }
    
    final paidDateText = lastPaymentDate != null 
        ? _dateFormatter.format(lastPaymentDate) 
        : loan.dueDate != null 
            ? _dateFormatter.format(loan.dueDate!) 
            : 'Fecha no registrada';

    final totalPaid = loan.totalAmountToPay ?? loan.amount;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.check, color: Colors.white),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Préstamo #$loanIdDisplay',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            // ✅ MOSTRAR EL CLIENT ID PARA DEBUG
            if (loan.clientId != null)
              Text(
                'ClientID: ${loan.clientId}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              clientName,
              style: TextStyle(
                color: clientName.contains('no encontrado') || 
                       clientName.contains('Error') || 
                       clientName.contains('sin ID')
                    ? Colors.red
                    : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text('Pagado: $paidDateText'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _currencyFormatter.format(totalPaid),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const Text(
              'Pagado',
              style: TextStyle(fontSize: 12, color: Colors.green),
            ),
          ],
        ),
        onTap: () {
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
              Icon(Icons.error, color: Colors.red, size: 50),
              const SizedBox(height: 12),
              Text(_loadErrorMessage!, 
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadPaidLoans, 
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

    return Column(
      children: [
        // ✅ RESUMEN
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      _paidLoans.length.toString(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const Text('Préstamos pagados'),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      _currencyFormatter.format(_paidLoans.fold(0.0, (sum, loan) => sum + (loan.totalAmountToPay ?? loan.amount))),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Text('Total pagado'),
                  ],
                ),
              ],
            ),
          ),
        ),
        // ✅ LISTA
        Expanded(
          child: ListView.builder(
            itemCount: _paidLoans.length,
            itemBuilder: (context, index) => _buildLoanTile(_paidLoans[index]),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Préstamos Pagados'),
        centerTitle: true,
        backgroundColor: const Color(0xFF4CAF50),
        actions: [
          // ✅ BOTÓN DE DEBUG
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPaidLoans,
            tooltip: 'Recargar y mostrar debug',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}