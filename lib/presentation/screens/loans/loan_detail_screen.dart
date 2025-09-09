// lib/presentation/screens/loans/loan_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/presentation/screens/payments/payment_form_screen.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loan_app/domain/entities/payment.dart';
import 'package:loan_app/data/repositories/payment_repository.dart';

class LoanDetailScreen extends StatefulWidget {
  final LoanModel loan;
  const LoanDetailScreen({super.key, required this.loan});

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  final PaymentRepository _paymentRepository = PaymentRepository();
  List<Payment> _payments = [];
  bool _isLoadingPayments = true;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  void _loadPayments() async {
    setState(() {
      _isLoadingPayments = true;
    });
    final loadedPayments = await _paymentRepository.getPaymentsByLoanId(widget.loan.id);
    loadedPayments.sort((a, b) => a.date.compareTo(b.date));
    setState(() {
      _payments = loadedPayments;
      _isLoadingPayments = false;
    });
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
          SnackBar(content: Text('No se pudo abrir WhatsApp para $whatsappNumber. Asegúrate de tener la app o de que el número sea correcto.')),
        );
      }
    }
  }

  double get totalAmountPaid => _payments.fold(0.0, (sum, item) => sum + item.amount);
  double get remainingBalance => widget.loan.totalAmountToPay - totalAmountPaid;

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles del Préstamo #${widget.loan.id.substring(0, 4)}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cliente: ${widget.loan.clientName}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text('Monto: ${currencyFormatter.format(widget.loan.amount)}'),
                    Text('Interés: ${(widget.loan.interestRate * 100).toStringAsFixed(2)}%'),
                    Text('Plazo: ${widget.loan.termValue} ${widget.loan.termUnit}'),
                    Text('Frecuencia: ${widget.loan.paymentFrequency}'),
                    Text('Total a pagar: ${currencyFormatter.format(widget.loan.totalAmountToPay)}'),
                    Text('Cuota: ${currencyFormatter.format(widget.loan.calculatedPaymentAmount)}'),
                    Text('Fecha de inicio: ${DateFormat('dd/MM/yyyy').format(widget.loan.startDate)}'),
                    Text('Fecha de vencimiento: ${DateFormat('dd/MM/yyyy').format(widget.loan.dueDate)}'),
                    const Divider(height: 20),
                    Text(
                      'Saldo Pagado: ${currencyFormatter.format(totalAmountPaid)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    Text(
                      'Saldo Pendiente: ${currencyFormatter.format(remainingBalance)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Botones de contacto
            if (widget.loan.phoneNumber != null || widget.loan.whatsappNumber != null)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Opciones de Contacto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          if (widget.loan.phoneNumber != null && widget.loan.phoneNumber!.isNotEmpty)
                            ElevatedButton.icon(
                              onPressed: () => _makePhoneCall(context, widget.loan.phoneNumber!),
                              icon: const Icon(Icons.phone),
                              label: const Text('Llamar'),
                            ),
                          if (widget.loan.whatsappNumber != null && widget.loan.whatsappNumber!.isNotEmpty)
                            ElevatedButton.icon(
                              onPressed: () => _launchWhatsApp(context, widget.loan.whatsappNumber!),
                              icon: const Icon(FontAwesomeIcons.whatsapp),
                              label: const Text('WhatsApp'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // Historial de pagos
            const Text('Historial de Pagos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _isLoadingPayments
                ? const Center(child: CircularProgressIndicator())
                : _payments.isEmpty
                    ? const Center(child: Text('No hay pagos registrados.'))
                    : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Total de pagos: ${currencyFormatter.format(totalAmountPaid)}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _payments.length,
                          itemBuilder: (context, index) {
                            final payment = _payments[index];
                            return Dismissible(
                              key: Key(payment.id),
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20.0),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) async {
                                bool? confirmDelete = await showDialog<bool>(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Confirmar Eliminación'),
                                      content: const Text(
                                          '¿Estás seguro de que deseas eliminar este pago? Esta acción es irreversible.'),
                                      actions: <Widget>[
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text('Cancelar'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.of(context).pop(true),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          child: const Text('Eliminar'),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (confirmDelete == true) {
                                  await _paymentRepository.deletePayment(payment.id);
                                  _loadPayments(); // Recargar pagos
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Pago eliminado exitosamente.')),
                                    );
                                  }
                                }
                                return confirmDelete;
                              },
                              child: Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: const Icon(Icons.receipt),
                                  title: Text(
                                    'Pago de: ${currencyFormatter.format(payment.amount)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'Fecha: ${DateFormat('dd/MM/yyyy').format(payment.date)}',
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentFormScreen(loan: widget.loan),
                  ),
                );
                _loadPayments();
              },
              icon: const Icon(Icons.add_task),
              label: const Text('Registrar Pago'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}