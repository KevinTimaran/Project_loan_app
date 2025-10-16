// lib/presentation/screens/clients/client_history_screen.dart
//#################################################
//#  Historial de Préstamos de un Cliente         #//
//#  Muestra préstamos con paginación y nombres   #//
//#  reales de clientes.                          #//
//#################################################

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
import 'package:loan_app/data/repositories/client_repository.dart'; // ✅ NUEVO: Para cargar nombres
import 'package:loan_app/presentation/screens/loans/loan_view_only_screen.dart';
import 'package:loan_app/presentation/screens/loans/loan_form_screen.dart';
import 'package:loan_app/domain/entities/client.dart'; // ✅ NUEVO: Para el modelo Client

class ClientHistoryScreen extends StatefulWidget {
  final String clientId;

  const ClientHistoryScreen({
    super.key,
    required this.clientId,
  });

  @override
  State<ClientHistoryScreen> createState() => _ClientHistoryScreenState();
}

class _ClientHistoryScreenState extends State<ClientHistoryScreen> {
  final LoanRepository _loanRepository = LoanRepository();
  final ClientRepository _clientRepository = ClientRepository(); // ✅ NUEVO

  List<LoanModel> _allClientLoans = []; // ✅ CAMBIADO: Almacenar todos los préstamos
  List<LoanModel> _visibleLoans = []; // ✅ NUEVO: Préstamos visibles en la página actual
  final Map<String, String> _clientNamesMap = {}; // ✅ NUEVO: Mapa para nombres de clientes
  bool _isLoading = true;
  String? _loadErrorMessage;

  // ✅ NUEVO: Variables para paginación
  int _currentPage = 0;
  static const int _itemsPerPage = 10; // Número de préstamos por página
  bool _hasMore = true; // Indica si hay más préstamos por cargar

  @override
  void initState() {
    super.initState();
    _loadClientLoans(); // ✅ CARGA INICIAL
  }

  String _getShortLoanId(LoanModel loan) {
    final id = loan.id;
    if (id.isEmpty) return '00000';

    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '00000';

    if (digits.length <= 5) {
      return digits.padLeft(5, '0');
    } else {
      return digits.substring(digits.length - 5);
    }
  }

  /// ✅ NUEVO: Cargar nombres de clientes para una lista de préstamos
  Future<void> _loadClientNames(List<LoanModel> loans) async {
    final clientIds = <String>{};
    for (final loan in loans) {
      if (loan.clientId.isNotEmpty) {
        clientIds.add(loan.clientId);
      }
    }

    if (clientIds.isEmpty) return;

    for (final clientId in clientIds) {
      if (!_clientNamesMap.containsKey(clientId)) { // Solo cargar si no está ya en el mapa
        try {
          final client = await _clientRepository.getClientById(clientId);
          final name = '${client?.name ?? ''} ${client?.lastName ?? ''}'.trim();
          _clientNamesMap[clientId] = name.isNotEmpty ? name : 'Cliente desconocido';
        } catch (e) {
          _clientNamesMap[clientId] = 'Error al cargar';
          debugPrint('❌ Error cargando cliente $clientId: $e');
        }
      }
    }
  }

  Future<void> _loadClientLoans() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _loadErrorMessage = null;
    });

    try {
      // ✅ CARGAR TODOS los préstamos del cliente
      final loans = await _loanRepository.getLoansByClientId(widget.clientId);
      if (!mounted) return;

      // ✅ ORDENARLOS (por ejemplo, más recientes primero)
      // Ajusta la lógica de orden según tus necesidades (fecha de inicio, estado, etc.)
      loans?.sort((a, b) => b.startDate.compareTo(a.startDate)); 

      setState(() {
        _allClientLoans = loans ?? [];
        _currentPage = 0; // Reiniciar a la primera página
        _hasMore = true; // Reiniciar indicador de más préstamos
        _visibleLoans = []; // Limpiar lista visible
      });

      // ✅ CARGAR NOMBRES de clientes para todos los préstamos
      await _loadClientNames(_allClientLoans);

      // ✅ CARGAR PRIMERA PÁGINA
      await _loadMoreLoans();

    } catch (e) {
      debugPrint('❌ Error al cargar los préstamos del cliente: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadErrorMessage = 'Error al cargar los préstamos: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar los préstamos: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// ✅ NUEVO: Cargar más préstamos para la página actual
  Future<void> _loadMoreLoans() async {
    if (!_hasMore || _allClientLoans.isEmpty) return;

    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;

    if (startIndex >= _allClientLoans.length) {
      setState(() {
        _hasMore = false; // No hay más elementos
      });
      return;
    }

    final newLoans = _allClientLoans.sublist(
      startIndex,
      endIndex > _allClientLoans.length ? _allClientLoans.length : endIndex,
    );

    // Cargar nombres para los nuevos préstamos si no están
    await _loadClientNames(newLoans);

    setState(() {
      _visibleLoans.addAll(newLoans);
      _currentPage++;
      // Verificar si hay más elementos después de esta carga
      _hasMore = endIndex < _allClientLoans.length;
    });
  }

  Future<void> _deleteLoan(LoanModel loan) async {
    final bool confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Estás seguro de que deseas eliminar el préstamo #${_getShortLoanId(loan)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed && mounted) {
      try {
        await _loanRepository.deleteLoan(loan.id);
        debugPrint('✅ Préstamo ${loan.id} eliminado.');
        
        // ✅ ACTUALIZAR LISTAS LOCALES
        setState(() {
          _allClientLoans.removeWhere((l) => l.id == loan.id);
          _visibleLoans.removeWhere((l) => l.id == loan.id);
          // Re-calcular si hay más elementos
          final expectedTotalPages = (_allClientLoans.length / _itemsPerPage).ceil();
          _hasMore = _currentPage < expectedTotalPages;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Préstamo #${_getShortLoanId(loan)} eliminado.')),
          );
        }
      } catch (e) {
        debugPrint('❌ Error al eliminar préstamo: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar el préstamo: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Préstamos del Cliente'),
      ),
      body: _isLoading && _visibleLoans.isEmpty // Mostrar spinner solo si no hay datos
          ? const Center(child: CircularProgressIndicator())
          : _loadErrorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadErrorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadClientLoans,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _visibleLoans.isEmpty
                  ? const Center(
                      child: Text('Este cliente no tiene préstamos registrados.'),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _visibleLoans.length + (_hasMore ? 1 : 0), // +1 para el botón "Ver más"
                            itemBuilder: (context, index) {
                              // ✅ Manejar el botón "Ver más"
                              if (index == _visibleLoans.length) {
                                return _hasMore
                                    ? Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Center(
                                          child: ElevatedButton.icon(
                                            onPressed: _loadMoreLoans,
                                            icon: const Icon(Icons.expand_more),
                                            label: const Text('Ver más'),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(); // No debería llegar aquí, pero por si acaso
                              }

                              final loan = _visibleLoans[index];
                              // ✅ USAR NOMBRE REAL DEL CLIENTE
                              final clientName = _clientNamesMap[loan.clientId] ?? 'Cliente desconocido';
                              final bool isPaid = loan.status == 'pagado';
                              final bool isOverdue = loan.status == 'mora';

                              Color cardColor;
                              Color statusColor;
                              IconData statusIcon;

                              if (isPaid) {
                                cardColor = Colors.green.shade50;
                                statusColor = Colors.green;
                                statusIcon = Icons.check_circle_outline;
                              } else if (isOverdue) {
                                cardColor = Colors.red.shade50;
                                statusColor = Colors.red;
                                statusIcon = Icons.warning_amber;
                              } else {
                                cardColor = Colors.white;
                                statusColor = Colors.blue;
                                statusIcon = Icons.account_balance_wallet_outlined;
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8.0),
                                elevation: 2,
                                color: cardColor,
                                child: InkWell(
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => isPaid
                                            ? LoanViewOnlyScreen(loan: loan)
                                            : LoanFormScreen(loan: loan),
                                      ),
                                    );
                                    if (result == true && mounted) {
                                      _loadClientLoans(); // Recargar todo si se editó
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        // Leading icon with status dot
                                        Stack(
                                          children: [
                                            Icon(
                                              statusIcon,
                                              color: statusColor,
                                              size: 32,
                                            ),
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: statusColor,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: cardColor,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),
                                        // Main content
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      'Préstamo #${_getShortLoanId(loan)}',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                  // Delete button
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                                    onPressed: () => _deleteLoan(loan),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(
                                                      minWidth: 30,
                                                      minHeight: 30,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              // ✅ MOSTRAR NOMBRE REAL DEL CLIENTE
                                              Text(
                                                clientName, // ✅ USAR clientName cargado
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                'Monto: ${currencyFormatter.format(loan.amount)}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Estado: ${loan.status}',
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                isPaid
                                                    ? 'Pagado: ${currencyFormatter.format(loan.totalAmountToPay)}'
                                                    : 'Saldo: ${currencyFormatter.format(loan.remainingBalance)}',
                                              ),
                                              Text(
                                                isPaid
                                                    ? 'Finalizado: ${dateFormatter.format(loan.dueDate)}'
                                                    : 'Inicio: ${dateFormatter.format(loan.startDate)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Arrow icon
                                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadClientLoans,
        tooltip: 'Refrescar historial',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}