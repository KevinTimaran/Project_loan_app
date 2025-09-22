import 'package:flutter/material.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/presentation/screens/payments/payment_form_screen.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loan_app/domain/entities/payment.dart';
import 'package:loan_app/data/repositories/payment_repository.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
import 'package:loan_app/presentation/screens/loans/loan_edit_screen.dart'; // ✅ Importación agregada

class LoanViewOnlyScreen extends StatefulWidget {
  final LoanModel loan;

  const LoanViewOnlyScreen({super.key, required this.loan});

  @override
  State<LoanViewOnlyScreen> createState() => _LoanViewOnlyScreenState();
}

class _LoanViewOnlyScreenState extends State<LoanViewOnlyScreen> {
  final LoanRepository _loanRepository = LoanRepository();
  final PaymentRepository _paymentRepository = PaymentRepository();
  late Future<LoanModel?> _loanDetailsFuture;

  @override
  void initState() {
    super.initState();
    _loanDetailsFuture = _loadLoanDetails();
  }

  Future<LoanModel?> _loadLoanDetails() async {
    return await _loanRepository.getLoanById(widget.loan.id);
  }

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo realizar la llamada a $phoneNumber')),
        );
      }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo abrir WhatsApp para $whatsappNumber.')),
          );
        }
      }
    }
  }

  // ✅ NUEVA FUNCIÓN: Abrir pantalla de edición
  Future<void> _openEditLoan(LoanModel loan) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoanEditScreen(loan: loan), // ✅ Navega a LoanEditScreen
      ),
    );

    if (!mounted) return;
    if (result == true) {
      setState(() {
        _loanDetailsFuture = _loadLoanDetails();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Préstamo #${widget.loan.id.substring(0, 6)}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: FutureBuilder<LoanModel?>(
        future: _loanDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text('Error al cargar los detalles.'));
          }

          final loan = snapshot.data!;

          // Define colores según estado
          Color statusColor;
          switch (loan.status) {
            case 'pagado':
              statusColor = Colors.green;
              break;
            case 'mora':
              statusColor = Colors.red;
              break;
            default:
              statusColor = Colors.orange;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🎯 SECCIÓN RESUMEN PRINCIPAL
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                loan.status == 'pagado' ? Icons.check_circle : Icons.account_balance_wallet,
                                color: statusColor,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cliente: ${loan.clientName}',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Estado: ${loan.status.toUpperCase()}',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 30, thickness: 1),
                        _buildDetailRow(Icons.attach_money, 'Monto Inicial', currencyFormatter.format(loan.amount)),
                        _buildDetailRow(Icons.percent, 'Tasa Anual', '${(loan.interestRate * 100).toStringAsFixed(2)}%'),
                        _buildDetailRow(Icons.calendar_today, 'Inicio', DateFormat('dd/MM/yyyy').format(loan.startDate)),
                        _buildDetailRow(Icons.calendar_month, 'Vencimiento', DateFormat('dd/MM/yyyy').format(loan.dueDate)),
                        _buildDetailRow(Icons.replay, 'Frecuencia', loan.paymentFrequency),
                        _buildDetailRow(Icons.numbers, 'Plazo', '${loan.termValue} ${loan.termUnit}'),
                        const Divider(height: 20),
                        _buildAmountRow('Total a Pagar', currencyFormatter.format(loan.totalAmountToPay), Colors.blueGrey[800]!),
                        _buildAmountRow('Pagado', currencyFormatter.format(loan.totalPaid), Colors.green[700]!),
                        _buildAmountRow('Pendiente', currencyFormatter.format(loan.remainingBalance), Colors.red[700]!),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 📞 SECCIÓN DE CONTACTO
                if ((loan.phoneNumber?.isNotEmpty == true) || (loan.whatsappNumber?.isNotEmpty == true))
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Contactar al Cliente',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (loan.phoneNumber?.isNotEmpty == true)
                                Flexible(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _makePhoneCall(context, loan.phoneNumber!),
                                    icon: const Icon(Icons.phone, size: 20),
                                    label: const Text('Llamar'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      animationDuration: Duration.zero,
                                    ),
                                  ),
                                ),
                              if (loan.phoneNumber?.isNotEmpty == true && loan.whatsappNumber?.isNotEmpty == true)
                                const SizedBox(width: 12),
                              if (loan.whatsappNumber?.isNotEmpty == true)
                                Flexible(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _launchWhatsApp(context, loan.whatsappNumber!),
                                    icon: const Icon(FontAwesomeIcons.whatsapp, size: 20),
                                    label: const Text('WhatsApp'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[700],
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      animationDuration: Duration.zero,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // 💰 SECCIÓN DE PAGOS
                const Text(
                  'Historial de Pagos',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                if (loan.payments.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'No hay pagos registrados aún.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: loan.payments.length,
                    itemBuilder: (context, index) {
                      final payment = loan.payments[index];
                      return Dismissible(
                        key: ValueKey(payment.id),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20.0),
                          child: const Icon(Icons.delete, color: Colors.white, size: 28),
                        ),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          bool? confirmDelete = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Eliminar Pago'),
                                content: const Text('¿Estás seguro? Esta acción es irreversible.'),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancelar'),
                                    style: TextButton.styleFrom().copyWith(animationDuration: Duration.zero),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red).copyWith(animationDuration: Duration.zero),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (confirmDelete == true) {
                            try {
                              await _paymentRepository.deletePayment(payment.id);
                              setState(() {
                                _loanDetailsFuture = _loadLoanDetails();
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Pago eliminado.')),
                              );
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          }
                          return confirmDelete;
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.payment, color: Colors.blue, size: 20),
                            ),
                            title: Text(
                              currencyFormatter.format(payment.amount),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text(
                              'Pago #${index + 1} • ${DateFormat('dd/MM/yyyy - HH:mm').format(payment.date)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 24),

                // ❌ ELIMINADO: No se puede registrar pago desde aquí
                // if (loan.remainingBalance > 0)
                //   ElevatedButton.icon(...),
              ],
            ),
          );
        },
      ),
      // ✅ BOTÓN FLOTANTE DE EDITAR: solo visible si el préstamo está activo
      floatingActionButton: widget.loan.status == 'activo'
          ? FloatingActionButton(
              backgroundColor: Colors.orange[700],
              onPressed: () => _openEditLoan(widget.loan),
              child: const Icon(Icons.edit, size: 30),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: color),
          ),
        ],
      ),
    );
  }
}