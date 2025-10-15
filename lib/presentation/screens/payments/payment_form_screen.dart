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

  static const double _residualThreshold = 0.50;
  static const double _roundingTolerance = 0.01;

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
        _updateExpectedAmount();
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadClients();
      });
    }

    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
    _amountController.addListener(_formatAmount);
  }

  void _updateExpectedAmount() {
    if (_selectedLoan == null) return;
    
    final remaining = _selectedLoan!.remainingBalance;
    final cuota = _selectedLoan!.calculatedPaymentAmount ?? 0.0;
    
    if (remaining <= _residualThreshold) {
      _expectedPaymentAmount = remaining;
    } else if (remaining < cuota) {
      _expectedPaymentAmount = remaining;
    } else {
      _expectedPaymentAmount = cuota;
    }
    
    _amountController.text = _formatCurrency(_expectedPaymentAmount);
  }

  double _parseAmount(String amountText) {
    if (amountText.isEmpty) return 0.0;
    
    String cleanAmountText = amountText.trim();
    
    if (cleanAmountText.contains(',')) {
      final parts = cleanAmountText.split(',');
      if (parts.length == 2) {
        final integerPart = parts[0].replaceAll('.', '');
        final decimalPart = parts[1];
        cleanAmountText = '$integerPart.$decimalPart';
      }
    } else {
      cleanAmountText = cleanAmountText.replaceAll('.', '');
    }
    
    final parsed = double.tryParse(cleanAmountText);
    return parsed ?? 0.0;
  }

  String _formatCurrency(double value) {
    return NumberFormat('#,##0.00', 'es_CO').format(value);
  }

  void _formatAmount() {
    final text = _amountController.text;
    if (text.isEmpty) return;
    
    final cleanText = text.replaceAll(RegExp(r'[^\d.,]'), '');
    
    if (cleanText.contains(',')) {
      final parts = cleanText.split(',');
      if (parts.length == 2) {
        final integerPart = int.tryParse(parts[0].replaceAll('.', '')) ?? 0;
        final decimalPart = parts[1];
        
        final limitedDecimal = decimalPart.length > 2 ? decimalPart.substring(0, 2) : decimalPart;
        
        final formatter = NumberFormat('#,##0', 'es_CO');
        final formattedInteger = formatter.format(integerPart);
        final formattedText = '$formattedInteger,$limitedDecimal';
        
        if (text != formattedText) {
          _amountController.value = TextEditingValue(
            text: formattedText,
            selection: TextSelection.collapsed(offset: formattedText.length),
          );
        }
      }
    } else {
      final valueInt = int.tryParse(cleanText.replaceAll('.', '')) ?? 0;
      final formatter = NumberFormat('#,##0', 'es_CO');
      final formattedText = formatter.format(valueInt);
      
      if (text != formattedText) {
        _amountController.value = TextEditingValue(
          text: formattedText,
          selection: TextSelection.collapsed(offset: formattedText.length),
        );
      }
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

  // ✅ CORREGIDO: Save Payment adaptado a tu entidad Payment
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
      // ✅ OBTENER PRÉSTAMO ACTUALIZADO DE LA BASE DE DATOS
      final currentLoan = await _loanRepository.getLoanById(_selectedLoan!.id);
      if (currentLoan == null) {
        throw Exception('No se pudo encontrar el préstamo en la base de datos');
      }

      if (currentLoan.isFullyPaid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este préstamo ya está completamente pagado')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final amountText = _amountController.text;
      
      if (amountText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor ingresa un monto válido')),
        );
        setState(() => _isLoading = false);
        return;
      }
      
      final inputAmount = _parseAmount(amountText);

      if (inputAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El monto debe ser mayor a cero')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final remainingBalance = currentLoan.remainingBalance;
      
      if (inputAmount > remainingBalance + _roundingTolerance) {
        final formattedRemaining = _formatCurrency(remainingBalance);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('El monto no puede ser mayor al saldo pendiente: \$$formattedRemaining')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // ✅ CREAR EL PAGO CON TU ESTRUCTURA ACTUAL (sin note ni createdAt)
      final newPayment = Payment(
        id: const Uuid().v4(),
        loanId: currentLoan.id,
        amount: inputAmount,
        date: _selectedDate,
      );

      debugPrint('💰 Registrando pago de ${inputAmount} para préstamo ${currentLoan.id}');

      // ✅ REGISTRAR PAGO EN EL MODELO
      currentLoan.registerPayment(newPayment);
      
      debugPrint('✅ Pago registrado. Nuevo estado: ${currentLoan.toDebugMap()}');

      // ✅ GUARDAR EN LOS REPOSITORIOS
      await _paymentRepository.addPayment(newPayment);
      await _loanRepository.updateLoan(currentLoan);

      // ✅ VERIFICAR QUE SE GUARDÓ CORRECTAMENTE
      final verifiedLoan = await _loanRepository.getLoanById(currentLoan.id);
      debugPrint('🔍 Verificación post-pago: ${verifiedLoan?.toDebugMap()}');

      if (!mounted) return;
      
      // ✅ MOSTRAR CONFIRMACIÓN Y RETORNAR ÉXITO
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Pago registrado exitosamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // ✅ RETORNAR true PARA QUE TodayCollectionScreen ACTUALICE LA LISTA
      Navigator.pop(context, true);

    } catch (e) {
      debugPrint('❌ ERROR en _savePayment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar pago: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatLoanDisplayText(LoanModel loan) {
    final idSafe = loan.id;
    final shortId = idSafe.length > 4 ? idSafe.substring(0, 4) : idSafe;
    final cuota = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0)
        .format((loan.calculatedPaymentAmount ?? 0).round());
    
    final saldo = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 2)
        .format(loan.remainingBalance);
    
    String residualWarning = '';
    String statusIndicator = '';
    
    if (loan.isFullyPaid) {
      statusIndicator = ' (PAGADO)';
    } else {
      final remaining = loan.remainingBalance;
      if (remaining <= _residualThreshold) {
        residualWarning = ' (RESIDUAL PEQUEÑO)';
      } else if (remaining <= 1.0) {
        residualWarning = ' (CASI PAGADO)';
      }
    }
    
    return 'Préstamo #$shortId - Cuota: $cuota - Saldo: $saldo$residualWarning$statusIndicator';
  }

  @override
  Widget build(BuildContext context) {
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
                                    _updateExpectedAmount();
                                  });
                                }
                              },
                        validator: (value) => value == null
                            ? 'Por favor, selecciona un préstamo.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ] else if (_selectedLoan != null) ...[
                      Builder(
                        builder: (context) {
                          final remaining = _selectedLoan!.remainingBalance;
                          final isFullyPaid = _selectedLoan!.isFullyPaid;
                          
                          if (isFullyPaid) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                border: Border.all(color: Colors.green),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green[800]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Préstamo completamente pagado',
                                      style: TextStyle(
                                        color: Colors.green[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else if (remaining <= _residualThreshold) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                border: Border.all(color: Colors.orange),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info, color: Colors.orange[800]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Saldo residual pequeño (\$${_formatCurrency(remaining)}). Se ajustará automáticamente.',
                                      style: TextStyle(
                                        color: Colors.orange[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else if (remaining <= 1.0) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                border: Border.all(color: Colors.blue),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.trending_down, color: Colors.blue[800]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Préstamo casi pagado. Saldo restante: \$${_formatCurrency(remaining)}',
                                      style: TextStyle(
                                        color: Colors.blue[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          
                          return const SizedBox.shrink();
                        },
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
                            ? 'Monto del Pago (Cuota: \$${_formatCurrency((_selectedLoan?.calculatedPaymentAmount ?? 0))} - Saldo: \$${_formatCurrency((_selectedLoan?.remainingBalance ?? 0))})'
                            : 'Monto del Pago',
                        border: const OutlineInputBorder(),
                        prefixText: '\$',
                        hintText: _selectedLoan != null 
                            ? _selectedLoan!.remainingBalance <= _residualThreshold
                                ? 'Se pagará el saldo completo'
                                : _selectedLoan!.remainingBalance <= 1.0
                                    ? 'Préstamo casi pagado'
                                    : null
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa el monto.';
                        }
                        
                        final amount = _parseAmount(value);
                        if (amount <= 0) {
                          return 'El monto debe ser mayor a cero.';
                        }
                        if (_selectedLoan != null) {
                          final remainingBalance = _selectedLoan!.remainingBalance;
                          if (amount > remainingBalance + _roundingTolerance) {
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
                            animationDuration: Duration.zero,
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