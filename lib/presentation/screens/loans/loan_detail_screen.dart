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
  late LoanModel _currentLoan;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentLoan = widget.loan;
    _loadLoanDetails();
  }

  Future<void> _loadLoanDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final updatedLoan = await _loanRepository.getLoanById(_currentLoan.id);
      if (updatedLoan != null && mounted) {
        // ⚠️ Validar si el préstamo ya está pagado
        if (updatedLoan.isFullyPaid || updatedLoan.remainingBalance <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Este préstamo ya está totalmente pagado')),
          );
          Navigator.pop(context, true); // Cerramos esta pantalla
          return;
        }

        setState(() {
          _currentLoan = updatedLoan;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar detalles: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  Future<void> _openRegisterPayment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentFormScreen(loan: _currentLoan),
      ),
    );

    if (!mounted) return;

    if (result != null && result is Map && result['refresh'] == true) {
      final updatedLoanFromForm = result['updatedLoan'];
      if (updatedLoanFromForm != null && updatedLoanFromForm is LoanModel) {
        if (updatedLoanFromForm.isFullyPaid || updatedLoanFromForm.remainingBalance <= 0) {
          Navigator.pop(context, true); // se cerrará si quedó en 0 tras registrar pago
          return;
        }
        setState(() {
          _currentLoan = updatedLoanFromForm;
        });
        return;
      }
      await _loadLoanDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    final payments = _currentLoan.payments ?? <Payment>[];

    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles del Préstamo #${_currentLoan.id.substring(0, 4)}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                            'Cliente: ${_currentLoan.clientName}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          Text('Monto: ${currencyFormatter.format(_currentLoan.amount)}'),
                          Text('Interés: ${(_currentLoan.interestRate * 100).toStringAsFixed(2)}%'),
                          Text('Plazo: ${_currentLoan.termValue} ${_currentLoan.termUnit}'),
                          Text('Frecuencia: ${_currentLoan.paymentFrequency}'),
                          Text('Total a pagar: ${currencyFormatter.format(_currentLoan.totalAmountToPay)}'),
                          Text('Cuota: ${currencyFormatter.format(_currentLoan.calculatedPaymentAmount)}'),
                          Text('Fecha de inicio: ${DateFormat('dd/MM/yyyy').format(_currentLoan.startDate)}'),
                          Text('Fecha de vencimiento: ${DateFormat('dd/MM/yyyy').format(_currentLoan.dueDate)}'),
                          const Divider(height: 20),
                          Text(
                            'Saldo Pagado: ${currencyFormatter.format(_currentLoan.totalPaid)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          Text(
                            'Saldo Pendiente: ${currencyFormatter.format(_currentLoan.remainingBalance)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if ((_currentLoan.phoneNumber != null && _currentLoan.phoneNumber!.isNotEmpty) ||
                      (_currentLoan.whatsappNumber != null && _currentLoan.whatsappNumber!.isNotEmpty))
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
                                if (_currentLoan.phoneNumber != null && _currentLoan.phoneNumber!.isNotEmpty)
                                  ElevatedButton.icon(
                                    onPressed: () => _makePhoneCall(context, _currentLoan.phoneNumber!),
                                    icon: const Icon(Icons.phone),
                                    label: const Text('Llamar'),
                                  ),
                                if (_currentLoan.whatsappNumber != null && _currentLoan.whatsappNumber!.isNotEmpty)
                                  ElevatedButton.icon(
                                    onPressed: () => _launchWhatsApp(context, _currentLoan.whatsappNumber!),
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
                                  try {
                                    await _paymentRepository.deletePayment(payment.id);
                                    await _loadLoanDetails();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Pago eliminado exitosamente.')),
                                      );
                                    }
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
                  ElevatedButton.icon(
                    onPressed: _openRegisterPayment,
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
