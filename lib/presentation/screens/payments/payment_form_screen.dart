// lib/presentation/screens/payments/payment_form_screen.dart
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
  final LoanModel? loan; // AHORA ES OPCIONAL: Puede ser nulo
  const PaymentFormScreen({super.key, this.loan}); // El préstamo se pasa aquí

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
    
    // Si se pasa un préstamo, lo usamos directamente
    if (widget.loan != null) {
      _selectedLoan = widget.loan;
      _expectedPaymentAmount = widget.loan!.calculatedPaymentAmount;
      _amountController.text = _expectedPaymentAmount.toStringAsFixed(0);
    } else {
      // Si no se pasa un préstamo, cargamos la lista de clientes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadClients();
      });
    }

    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);

    // Listener para el formato del monto
    _amountController.addListener(() {
      final String text = _amountController.text;
      if (text.isEmpty) {
        return;
      }
      
      final String cleanText = text.replaceAll(RegExp(r'[^\d]'), '');
      if (cleanText.isEmpty) {
        return;
      }

      try {
        final double value = double.parse(cleanText);
        final formatter = NumberFormat.decimalPattern('es_CO');
        final formattedText = formatter.format(value);

        if (text != formattedText) {
          _amountController.value = TextEditingValue(
            text: formattedText,
            selection: TextSelection.collapsed(offset: formattedText.length),
          );
        }
      } catch (e) {
        // Ignorar la excepción
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final clients = await _clientRepository.getClients();
      setState(() {
        _clients = clients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar clientes: $e')),
        );
      }
    }
  }

  Future<void> _loadLoansForClient(String clientId) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final loans = await _loanRepository.getLoansByClientId(clientId);
      setState(() {
        _loans = loans;
        _selectedLoan = null;
        _expectedPaymentAmount = 0.0;
        _amountController.clear();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar préstamos: $e')),
        );
      }
    }
  }

  Future<void> _savePayment() async {
    if (_formKey.currentState!.validate() && _selectedLoan != null) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final String cleanAmountText = _amountController.text.replaceAll(RegExp(r'[^\d]'), '');
        final double amount = double.tryParse(cleanAmountText) ?? 0.0;
        
        final newPayment = Payment(
          id: const Uuid().v4(),
          loanId: _selectedLoan!.id,
          amount: amount,
          date: _selectedDate,
        );

        await _paymentRepository.addPayment(newPayment);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pago registrado exitosamente')),
          );
          Navigator.pop(context, true); // Retorna 'true' para recargar
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al registrar pago: $e')),
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
  }

  String _formatLoanDisplayText(LoanModel loan) {
    final shortId = loan.id.length > 4 ? loan.id.substring(0, 4) : loan.id;
    final formattedExpectedPayment = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    ).format(loan.calculatedPaymentAmount);
    
    return 'Préstamo #$shortId - Cuota: $formattedExpectedPayment';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableWidth = mediaQuery.size.width - 32;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Pago'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (widget.loan == null) ...[ // Mostrar solo si no se ha pasado un préstamo
                      Container(
                        constraints: BoxConstraints(maxWidth: availableWidth),
                        child: DropdownButtonFormField<Client>(
                          value: _selectedClient,
                          decoration: const InputDecoration(
                            labelText: 'Selecciona un cliente',
                            border: OutlineInputBorder(),
                          ),
                          items: _clients.map((client) {
                            return DropdownMenuItem(
                              value: client,
                              child: Text(
                                '${client.name} ${client.lastName}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (client) {
                            if (client != null) {
                              setState(() {
                                _selectedClient = client;
                              });
                              _loadLoansForClient(client.id);
                            }
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Por favor, selecciona un cliente.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Container(
                        constraints: BoxConstraints(maxWidth: availableWidth),
                        child: DropdownButtonFormField<LoanModel>(
                          isExpanded: true,
                          value: _selectedLoan,
                          decoration: const InputDecoration(
                            labelText: 'Selecciona un préstamo',
                            border: OutlineInputBorder(),
                          ),
                          items: _loans.map((loan) {
                            return DropdownMenuItem(
                              value: loan,
                              child: Text(
                                _formatLoanDisplayText(loan),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                          onChanged: _selectedClient == null
                              ? null
                              : (loan) {
                                  if (loan != null) {
                                    setState(() {
                                      _selectedLoan = loan;
                                      _expectedPaymentAmount = loan.calculatedPaymentAmount;
                                      _amountController.text = loan.calculatedPaymentAmount.toStringAsFixed(0);
                                    });
                                  }
                                },
                          validator: (value) {
                            if (value == null) {
                              return 'Por favor, selecciona un préstamo.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    Container(
                      constraints: BoxConstraints(maxWidth: availableWidth),
                      child: TextFormField(
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
                              _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Container(
                      constraints: BoxConstraints(maxWidth: availableWidth),
                      child: TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: _expectedPaymentAmount > 0
                            ? 'Monto del Pago (Cuota esperada: \$${NumberFormat.decimalPattern('es_CO').format(_expectedPaymentAmount)})'
                            : 'Monto del Pago',
                          hintText: 'Ej: 150000',
                          border: const OutlineInputBorder(),
                          prefixText: '\$',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, ingresa el monto.';
                          }
                          final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');
                          if (double.tryParse(cleanValue) == null) {
                            return 'Por favor, ingresa un número válido.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    
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
                        label: Text(_isLoading ? 'Guardando...' : 'Guardar Pago'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}