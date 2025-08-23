// lib/presentation/screens/loans/loan_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/presentation/providers/loan_provider.dart';
import 'package:loan_app/presentation/screens/loans/add_loan_screen.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/domain/entities/client.dart';

class LoanListScreen extends StatelessWidget {
  const LoanListScreen({super.key});

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
          if (loanProvider.isLoading) {
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
          if (loanProvider.loans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.money_off, size: 80, color: iconColor.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No hay préstamos registrados.\n¡Agrega el primero!',
                    style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.7)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: loanProvider.loans.length,
            itemBuilder: (context, index) {
              final loan = loanProvider.loans[index];
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

              return FutureBuilder<Client?>(
                future: ClientRepository().getClientById(loan.clientId),
                builder: (context, snapshot) {
                  String clientName = 'Cargando...';
                  if (snapshot.connectionState == ConnectionState.done) {
                    if (snapshot.hasData && snapshot.data != null) {
                      final client = snapshot.data!;
                      clientName = '${client.name} ${client.lastName}';
                    } else {
                      clientName = 'Cliente no encontrado';
                    }
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: rowBackgroundColor,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    // 💡 Usar un Stack para superponer la ID
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
                                    if (loan.phoneNumber != null && loan.phoneNumber!.isNotEmpty)
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _makePhoneCall(context, loan.phoneNumber!),
                                          icon: const Icon(Icons.phone, size: 18),
                                          label: const Text('Llamar'),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                          ),
                                        ),
                                      ),
                                    if (loan.phoneNumber != null && loan.phoneNumber!.isNotEmpty && loan.whatsappNumber != null && loan.whatsappNumber!.isNotEmpty)
                                      const SizedBox(width: 8),
                                    if (loan.whatsappNumber != null && loan.whatsappNumber!.isNotEmpty)
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _launchWhatsApp(context, loan.whatsappNumber!),
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
                        // 💡 Agregamos la ID en la esquina superior derecha
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddLoanScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniStartFloat,
    );
  }
}