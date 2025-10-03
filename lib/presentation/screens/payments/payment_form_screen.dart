// lib/presentation/screens/payments/payment_form_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
import 'package:loan_app/data/repositories/payment_repository.dart';
import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/domain/entities/payment.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class PaymentFormScreen extends StatefulWidget {
  final LoanModel? loan;
  const PaymentFormScreen({super.key, this.loan});
  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ClientRepository _clientRepository = ClientRepository();
  final LoanRepository _loanRepository = LoanRepository();
  final PaymentRepository _paymentRepository = PaymentRepository();

  List<Client> _clients = [];
  List<LoanModel> _loans = [];
  Client? _selectedClient;
  LoanModel? _selectedLoan;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  double _expectedPaymentAmount = 0.0;

  @override
  void initState() {
    super.initState();

    if (widget.loan != null) {
      _selectedLoan = widget.loan;

      if (_selectedLoan!.isFullyPaid) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Este préstamo ya está completamente pagado')),
          );
          Navigator.pop(context);
        });
      } else {
        final remainingPesos = (_selectedLoan!.remainingBalance ?? 0).round();
        final cuotaPesos = (_selectedLoan!.calculatedPaymentAmount ?? 0).round();
        final expected = remainingPesos < cuotaPesos ? remainingPesos : cuotaPesos;
        _expectedPaymentAmount = expected.toDouble();
        _amountController.text = NumberFormat.decimalPattern('es_CO').format(expected);
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadClients();
      });
    }

    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
    _amountController.addListener(_formatAmount);
  }

  void _formatAmount() {
    final text = _amountController.text;
    if (text.isEmpty) return;
    final cleanText = text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanText.isEmpty) return;
    final valueInt = int.tryParse(cleanText);
    if (valueInt == null) return;
    final formatter = NumberFormat.decimalPattern('es_CO');
    final formattedText = formatter.format(valueInt);
    if (text != formattedText) {
      _amountController.value = TextEditingValue(
        text: formattedText,
        selection: TextSelection.collapsed(offset: formattedText.length),
      );
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_formatAmount);
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final clients = await _clientRepository.getClients();
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar clientes: $e')),
      );
    }
  }

  Future<void> _loadLoansForClient(String clientId) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final loans = await _loanRepository.getLoansByClientId(clientId);
      final activeLoans = loans.where((loan) => !loan.isFullyPaid).toList();
      if (!mounted) return;
      setState(() {
        _loans = activeLoans;
        _selectedLoan = null;
        _expectedPaymentAmount = 0.0;
        _amountController.clear();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar préstamos: $e')),
      );
    }
  }

  // ---------- SAVE PAYMENT ----------
  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLoan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un préstamo.')),
      );
      return;
    }
    if (_selectedLoan!.isFullyPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este préstamo ya está completamente pagado')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cleanAmountText = _amountController.text.replaceAll(RegExp(r'[^\d]'), '');
      final amountPesos = int.tryParse(cleanAmountText) ?? 0;

      if (amountPesos <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El monto debe ser mayor a cero')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final remainingPesos = (_selectedLoan!.remainingBalance ?? 0).round();
      if (amountPesos > remainingPesos) {
        final formattedRemaining = NumberFormat.decimalPattern('es_CO').format(remainingPesos);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('El monto no puede ser mayor al saldo pendiente: \$${formattedRemaining}')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final loanIdToUse = _selectedLoan!.id ?? const Uuid().v4();

      final newPayment = Payment(
        id: const Uuid().v4(),
        loanId: loanIdToUse,
        amount: amountPesos.toDouble(),
        date: _selectedDate,
      );

      // Actualizar en memoria
      _selectedLoan!.registerPayment(newPayment);

      // Persistir en repositorios
      await _paymentRepository.addPayment(newPayment);
      await _loanRepository.updateLoan(_selectedLoan!);

      // Confirmar leyendo desde Hive
    final persisted = await _loanRepositoryGetter(_selectedLoan!.id);
    print(
        '>>> Pago guardado. loanId=${persisted?.id} remaining=${persisted?.remainingBalance} payments=${persisted?.payments?.length ?? 0}');


      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago registrado exitosamente')),
      );

      // ✅ Devolver true para indicar que se guardó
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar pago: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper para acceder al repositorio con seguridad (evita errores de tipo)
  Future<LoanModel?> _loanRepositoryGetter(String? id) async {
  if (id == null || id.isEmpty) return null;
  try {
    return await _loanRepository.getLoanById(id);
  } catch (_) {
    return null;
  }
}


  String _formatLoanDisplayText(LoanModel loan) {
    final idSafe = loan.id ?? '';
    final shortId = idSafe.length > 4 ? idSafe.substring(0, 4) : idSafe;
    final cuota = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0)
        .format((loan.calculatedPaymentAmount ?? 0).round());
    final saldo = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0)
        .format((loan.remainingBalance ?? 0).round());
    return 'Préstamo #$shortId - Cuota: $cuota - Saldo: $saldo';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableWidth = max(0.0, mediaQuery.size.width - 32.0);
    final currencyFormatter = NumberFormat.decimalPattern('es_CO');

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Pago')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (widget.loan == null) ...[
                      DropdownButtonFormField<Client>(
                        value: _selectedClient,
                        decoration: const InputDecoration(
                          labelText: 'Selecciona un cliente',
                          border: OutlineInputBorder(),
                        ),
                        items: _clients
                            .map((client) => DropdownMenuItem(
                                  value: client,
                                  child: Text('${client.name} ${client.lastName}'),
                                ))
                            .toList(),
                        onChanged: (client) {
                          if (client != null) {
                            setState(() => _selectedClient = client);
                            _loadLoansForClient(client.id);
                          }
                        },
                        validator: (value) => value == null
                            ? 'Por favor, selecciona un cliente.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<LoanModel>(
                        isExpanded: true,
                        value: _selectedLoan,
                        decoration: const InputDecoration(
                          labelText: 'Selecciona un préstamo',
                          border: OutlineInputBorder(),
                        ),
                        items: _loans
                            .map((loan) => DropdownMenuItem(
                                  value: loan,
                                  child: Text(_formatLoanDisplayText(loan),
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: _selectedClient == null
                            ? null
                            : (loan) {
                                if (loan != null) {
                                  setState(() {
                                    _selectedLoan = loan;
                                    final remainingPesos = (loan.remainingBalance ?? 0).round();
                                    final cuotaPesos = (loan.calculatedPaymentAmount ?? 0).round();
                                    final expected = remainingPesos < cuotaPesos ? remainingPesos : cuotaPesos;
                                    _expectedPaymentAmount = expected.toDouble();
                                    _amountController.text = currencyFormatter.format(expected);
                                  });
                                }
                              },
                        validator: (value) => value == null
                            ? 'Por favor, selecciona un préstamo.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Fecha del Pago',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: () async {
                        final selectedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2101),
                        );
                        if (selectedDate != null) {
                          setState(() {
                            _selectedDate = selectedDate;
                            _dateController.text =
                                DateFormat('dd/MM/yyyy').format(_selectedDate);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: _selectedLoan != null
                            ? 'Monto del Pago (Cuota: \$${NumberFormat.decimalPattern('es_CO').format(((_selectedLoan?.calculatedPaymentAmount ?? 0).round()))} - Saldo: \$${NumberFormat.decimalPattern('es_CO').format(((_selectedLoan?.remainingBalance ?? 0).round()))})'
                            : 'Monto del Pago',
                        border: const OutlineInputBorder(),
                        prefixText: '\$',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa el monto.';
                        }
                        final cleanValue =
                            value.replaceAll(RegExp(r'[^\d]'), '');
                        final amountPesos = int.tryParse(cleanValue);
                        if (amountPesos == null) {
                          return 'Por favor, ingresa un número válido.';
                        }
                        if (amountPesos <= 0) {
                          return 'El monto debe ser mayor a cero.';
                        }
                        if (_selectedLoan != null) {
                          final remainingPesos = (_selectedLoan!.remainingBalance ?? 0).round();
                          if (amountPesos > remainingPesos) {
                            return 'El monto no puede ser mayor al saldo pendiente.';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    if (_selectedLoan == null || !(_selectedLoan!.isFullyPaid))
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _savePayment,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                              _isLoading ? 'Guardando...' : 'Guardar Pago'),
                          style: ElevatedButton.styleFrom(
                            animationDuration: Duration.zero, // ✅ Evita errores de animación
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
