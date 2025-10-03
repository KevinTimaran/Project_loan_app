import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/presentation/providers/loan_provider.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/presentation/screens/clients/client_list_screen.dart';
import 'package:loan_app/presentation/screens/loans/loan_form_screen.dart';

class LoanListScreen extends StatefulWidget {
  const LoanListScreen({super.key});

  @override
  State<LoanListScreen> createState() => _LoanListScreenState();
}

class _LoanListScreenState extends State<LoanListScreen> {
  Map<String, Client> _clientCache = {};
  bool _isLoadingClients = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    try {
      final clientRepository = ClientRepository();
      final clients = await clientRepository.getAllClients();
      
      setState(() {
        _clientCache = {for (var client in clients) client.id: client};
        _isLoadingClients = false;
      });
    } catch (e) {
      print('Error loading clients: $e');
      setState(() {
        _isLoadingClients = false;
      });
    }
  }

  Future<void> _clearAllLoans(BuildContext context) async {
    await Hive.deleteBoxFromDisk('loans');
    Provider.of<LoanProvider>(context, listen: false).loadLoans();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Todos los préstamos han sido borrados!')),
    );
  }

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo realizar la llamada a $phoneNumber')),
      );
    }
  }

  Future<void> _launchWhatsApp(BuildContext context, String whatsappNumber) async {
    final Uri whatsappUri = Uri.parse('whatsapp://send?phone=$whatsappNumber');
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri);
    } else {
      // ✅ URL CORREGIDA: Sin espacios en blanco
      final Uri webWhatsappUri = Uri.parse('https://wa.me/$whatsappNumber');
      if (await canLaunchUrl(webWhatsappUri)) {
        await launchUrl(webWhatsappUri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir WhatsApp para $whatsappNumber. Asegúrate de tener la app o de que el número sea correcto (ej. +57XXXXXXXXXX).')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = const Color(0xFF212121);
    final Color primaryBlue = const Color(0xFF1E88E5);
    final Color mainGreen = const Color(0xFF43A047);
    final Color alertRed = const Color(0xFFE53935);
    final Color warningOrange = const Color(0xFFFB8C00);
    final Color iconColor = const Color(0xFF424242);
    final Color alternateRowColor = const Color(0xFFFAFAFA);

    final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lista de Préstamos',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.people, color: Colors.white),
            tooltip: 'Gestión de Clientes',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ClientListScreen()),
              );
              // Recargar clientes al regresar
              await _loadClients();
              Provider.of<LoanProvider>(context, listen: false).loadLoans();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            tooltip: 'Borrar Todos los Préstamos (¡Solo pruebas!)',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirmar Borrado General'),
                  content: const Text('¡ADVERTENCIA! ¿Estás seguro de que quieres borrar TODOS los préstamos? Esta acción es irreversible y solo para pruebas.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _clearAllLoans(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: alertRed,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Borrar Todo'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<LoanProvider>(
        builder: (context, loanProvider, child) {
          if (loanProvider.isLoading || _isLoadingClients) {
            return Center(
              child: CircularProgressIndicator(color: primaryBlue),
            );
          }
          if (loanProvider.errorMessage != null) {
            return Center(
              child: Text(
                'Error: ${loanProvider.errorMessage}',
                style: TextStyle(color: alertRed, fontSize: 14, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            );
          }

          // ✅ Filtrar solo préstamos con saldo pendiente > 0
          final activeLoans = loanProvider.loans.where((loan) => loan.remainingBalance > 0).toList();

          if (activeLoans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.money_off, size: 80, color: iconColor.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No hay préstamos activos.\n¡Agrega el primero!',
                    style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.7)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: activeLoans.length,
            itemBuilder: (context, index) {
              final loan = activeLoans[index];
              final bool isEvenRow = index % 2 == 0;
              final Color rowBackgroundColor = isEvenRow ? Colors.white : alternateRowColor;

              String paymentLabel = 'Pago ';
              switch (loan.paymentFrequency) {
                case 'Diario':
                  paymentLabel += 'Diario:';
                  break;
                case 'Semanal':
                  paymentLabel += 'Semanal:';
                  break;
                case 'Quincenal':
                  paymentLabel += 'Quincenal:';
                  break;
                case 'Mensual':
                default:
                  paymentLabel += 'Mensual:';
                  break;
              }

              // Obtener información del cliente desde el cache
              final client = _clientCache[loan.clientId];
              String clientName = client != null ? 
                '${client.name} ${client.lastName}' : 'Cliente no encontrado';
              String? clientPhone = client?.phone;
              String? clientWhatsapp = client?.whatsapp;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: rowBackgroundColor,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Stack(
                  children: [
                    ListTile(
                      leading: Icon(Icons.account_balance_wallet, color: iconColor),
                      title: Text(
                        'Cliente: $clientName',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monto: ${currencyFormatter.format(loan.amount)}',
                            style: TextStyle(fontSize: 14, color: textColor),
                          ),
                          Text(
                            'Tasa: ${(loan.interestRate * 100).toStringAsFixed(2)}%',
                            style: TextStyle(fontSize: 14, color: textColor),
                          ),
                          Text(
                            'Plazo: ${loan.termValue} ${loan.termUnit}',
                            style: TextStyle(fontSize: 14, color: textColor),
                          ),
                          Text(
                            'Frecuencia: ${loan.paymentFrequency}',
                            style: TextStyle(fontSize: 14, color: textColor),
                          ),
                          Text(
                            'Estado: ${loan.status.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: loan.isFullyPaid
                                  ? mainGreen
                                  : (loan.status == 'atrasado'
                                      ? alertRed
                                      : warningOrange),
                            ),
                          ),
                          Text(
                            '$paymentLabel ${currencyFormatter.format(loan.calculatedPaymentAmount)}',
                            style: TextStyle(fontSize: 14, color: textColor),
                          ),
                          Text(
                            'Vencimiento: ${DateFormat('dd/MM/yyyy').format(loan.dueDate)}',
                            style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.7)),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                if (clientPhone != null && clientPhone.isNotEmpty)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _makePhoneCall(context, clientPhone!),
                                      icon: const Icon(Icons.phone, size: 18),
                                      label: const Text('Llamar'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                      ),
                                    ),
                                  ),
                                if (clientPhone != null && clientPhone.isNotEmpty && clientWhatsapp != null && clientWhatsapp.isNotEmpty)
                                  const SizedBox(width: 8),
                                if (clientWhatsapp != null && clientWhatsapp.isNotEmpty)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _launchWhatsApp(context, clientWhatsapp!),
                                      icon: const Icon(FontAwesomeIcons.whatsapp, size: 18),
                                      label: const Text('WhatsApp'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8.0,
                      right: 8.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryBlue,
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Text(
                          'ID: ${loan.id.replaceAll(RegExp(r'[^0-9]'), '').substring(0, min(5, loan.id.length))}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const LoanFormScreen()),
          );
          // Recargar la lista de préstamos y clientes al regresar
          Provider.of<LoanProvider>(context, listen: false).loadLoans();
          await _loadClients();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Préstamo'),
      ),
    );
  }
}