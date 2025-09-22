import 'package:flutter/material.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/presentation/screens/payments/payment_form_screen.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loan_app/domain/entities/payment.dart';
import 'package:loan_app/data/repositories/payment_repository.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';

class LoanDetailScreen extends StatefulWidget {
  final LoanModel loan;
  const LoanDetailScreen({super.key, required this.loan});

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
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
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
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
            SnackBar(content: Text('No se pudo abrir WhatsApp para $whatsappNumber. Asegúrate de tener la app o de que el número sea correcto.')),
          );
        }
      }
    }
  }
  
  // ✅ NUEVA FUNCIÓN para abrir la pantalla de edición
 Future<void> _openRegisterPayment(LoanModel loan) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PaymentFormScreen(loan: loan)),
    );

    if (!mounted) return;
    if (result == true) {
      setState(() {
        _loanDetailsFuture = _loadLoanDetails();
      });
    }
  }

  // ❌ ELIMINADA: Ya no se usa _openEditLoan

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles del Préstamo #${widget.loan.loanNumber}'),
      ),
      body: FutureBuilder<LoanModel?>(
        future: _loanDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text('Error al cargar los detalles del préstamo.'));
          }

          final loan = snapshot.data!;
          final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
          final payments = loan.payments;

          return SingleChildScrollView(
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
                          'Cliente: ${loan.clientName}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        Text('Monto: ${currencyFormatter.format(loan.amount)}'),
                        Text('Interés: ${(loan.interestRate * 100).toStringAsFixed(2)}%'),
                        Text('Plazo: ${loan.termValue} ${loan.termUnit}'),
                        Text('Frecuencia: ${loan.paymentFrequency}'),
                        Text('Total a pagar: ${currencyFormatter.format(loan.totalAmountToPay)}'),
                        Text('Cuota: ${currencyFormatter.format(loan.calculatedPaymentAmount)}'),
                        Text('Fecha de inicio: ${DateFormat('dd/MM/yyyy').format(loan.startDate)}'),
                        Text('Fecha de vencimiento: ${DateFormat('dd/MM/yyyy').format(loan.dueDate)}'),
                        const Divider(height: 20),
                        Text(
                          'Saldo Pagado: ${currencyFormatter.format(loan.totalPaid)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        Text(
                          'Saldo Pendiente: ${currencyFormatter.format(loan.remainingBalance)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if ((loan.phoneNumber != null && loan.phoneNumber!.isNotEmpty) ||
                    (loan.whatsappNumber != null && loan.whatsappNumber!.isNotEmpty))
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
                              if (loan.phoneNumber != null && loan.phoneNumber!.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: () => _makePhoneCall(context, loan.phoneNumber!),
                                  icon: const Icon(Icons.phone),
                                  label: const Text('Llamar'),
                                  style: ElevatedButton.styleFrom(animationDuration: Duration.zero),
                                ),
                              if (loan.whatsappNumber != null && loan.whatsappNumber!.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: () => _launchWhatsApp(context, loan.whatsappNumber!),
                                  icon: const Icon(FontAwesomeIcons.whatsapp),
                                  label: const Text('WhatsApp'),
                                  style: ElevatedButton.styleFrom(animationDuration: Duration.zero),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const Text('Historial de Pagos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                payments.isEmpty
                    ? const Center(child: Text('No hay pagos registrados.'))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: payments.length,
                        itemBuilder: (context, index) {
                          final payment = payments[index];
                          return Dismissible(
                            key: ValueKey(payment.id),
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
                                    content: const Text('¿Estás seguro de que deseas eliminar este pago? Esta acción es irreversible.'),
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
                                    const SnackBar(content: Text('Pago eliminado exitosamente.')),
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error al eliminar pago: $e')),
                                    );
                                  }
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
                const SizedBox(height: 20),
                // ✅ AGREGADO: Ahora se puede registrar pago desde aquí
                if (loan.remainingBalance > 0)
                  ElevatedButton.icon(
                    onPressed: () => _openRegisterPayment(loan),
                    icon: const Icon(Icons.add_task),
                    label: const Text('Registrar Pago'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Theme.of(context).primaryColor,
                      animationDuration: Duration.zero,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      // ❌ ELIMINADO: No se puede editar préstamo desde aquí
      // floatingActionButton: widget.loan.status == 'activo'
      //     ? FloatingActionButton(...)
      //     : null,
    );
  }
}