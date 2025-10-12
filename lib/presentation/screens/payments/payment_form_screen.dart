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

  // ✅ CORREGIDO: Tolerancia más realista para validación
  static const double _residualThreshold = 0.50; // Hasta 50 centavos se considera residual pequeño
  static const double _roundingTolerance = 0.01; // 1 centavo de tolerancia para validación

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

  // ✅ MEJORADO: Método para calcular el monto esperado con detección inteligente de residuales
  void _updateExpectedAmount() {
    if (_selectedLoan == null) return;
    
    final remaining = _selectedLoan!.remainingBalance;
    final cuota = _selectedLoan!.calculatedPaymentAmount ?? 0.0;
    
    // ✅ Si el saldo restante es muy pequeño (residual), sugerir pagar el saldo completo
    if (remaining <= _residualThreshold) {
      _expectedPaymentAmount = remaining;
    } else if (remaining < cuota) {
      // ✅ Si el saldo restante es menor que la cuota, sugerir el saldo completo
      _expectedPaymentAmount = remaining;
    } else {
      _expectedPaymentAmount = cuota;
    }
    
    _amountController.text = _formatCurrency(_expectedPaymentAmount);
  }

  // ✅ CORREGIDO: Método auxiliar para parsear montos con formato colombiano
  double _parseAmount(String amountText) {
    if (amountText.isEmpty) return 0.0;
    
    // ✅ CORREGIDO: Manejar formato colombiano (punto para miles, coma para decimales)
    String cleanAmountText = amountText.trim();
    
    // Si tiene coma decimal, convertir a formato estándar
    if (cleanAmountText.contains(',')) {
      // Separar por la coma decimal
      final parts = cleanAmountText.split(',');
      if (parts.length == 2) {
        // Remover puntos de miles de la parte entera
        final integerPart = parts[0].replaceAll('.', '');
        final decimalPart = parts[1];
        cleanAmountText = '$integerPart.$decimalPart';
      }
    } else {
      // Si no tiene coma, solo remover puntos de miles
      cleanAmountText = cleanAmountText.replaceAll('.', '');
    }
    
    // Parsear el número
    final parsed = double.tryParse(cleanAmountText);
    
    
    return parsed ?? 0.0;
  }

  // ✅ CORREGIDO: Formateador de moneda simple sin separadores de miles
  String _formatCurrency(double value) {
    return NumberFormat('#,##0.00', 'es_CO').format(value);
  }

  void _formatAmount() {
    final text = _amountController.text;
    if (text.isEmpty) return;
    
    // ✅ CORREGIDO: Manejar formato colombiano (punto para miles, coma para decimales)
    // Remover todo excepto dígitos, puntos y comas
    final cleanText = text.replaceAll(RegExp(r'[^\d.,]'), '');
    
    // Si tiene coma decimal, manejar formato colombiano
    if (cleanText.contains(',')) {
      final parts = cleanText.split(',');
      if (parts.length == 2) {
        // Formatear parte entera con puntos de miles
        final integerPart = int.tryParse(parts[0].replaceAll('.', '')) ?? 0;
        final decimalPart = parts[1];
        
        // Limitar a 2 decimales
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
      // Si no tiene coma, formatear como entero con puntos de miles
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

  // ✅ MEJORADO: Manejo inteligente de montos de pago con detección avanzada de residuales
  double _calculatePaymentAmount(double inputAmount, double remainingBalance) {
    // ✅ Si el pago deja un residual muy pequeño, pagar el saldo completo
    final residualAfterPayment = remainingBalance - inputAmount;
    
    // ✅ Detectar residuales pequeños comunes (hasta 50 centavos)
    if (residualAfterPayment > 0 && residualAfterPayment <= _residualThreshold) {
      return remainingBalance; // Pagar el saldo completo
    }
    
    // ✅ Detectar casos donde el pago es muy cercano al saldo restante
    final paymentRatio = inputAmount / remainingBalance;
    if (paymentRatio >= 0.95 && residualAfterPayment <= 1.0) {
      return remainingBalance; // Pagar el saldo completo si es muy cercano
    }
    
    return inputAmount;
  }

  // ✅ MEJORADO: Save Payment con manejo robusto de residuales
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
      // ✅ CORREGIDO: Parseo robusto que maneja separadores de miles y decimales
      final amountText = _amountController.text;
      
      // Validar formato de número
      if (amountText.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor ingresa un monto válido')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
      
      // Parsear el número usando el método auxiliar
      final inputAmount = _parseAmount(amountText);
      

      // ✅ MEJORADO: Validación más clara y útil
      if (inputAmount <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El monto debe ser mayor a cero')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final remainingBalance = _selectedLoan!.remainingBalance;
      
      // ✅ Aplicar lógica inteligente de residuales
      final finalPaymentAmount = _calculatePaymentAmount(inputAmount, remainingBalance);

      // ✅ MEJORADO: Validación con tolerancia
      if (finalPaymentAmount > remainingBalance + _roundingTolerance) {
        final formattedRemaining = _formatCurrency(remainingBalance);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('El monto no puede ser mayor al saldo pendiente: \$$formattedRemaining')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final loanIdToUse = _selectedLoan!.id;

      // ✅ CREAR Y REGISTRAR EL PAGO PRINCIPAL
      final newPayment = Payment(
        id: const Uuid().v4(),
        loanId: loanIdToUse,
        amount: finalPaymentAmount,
        date: _selectedDate,
      );

      // ✅ Registrar pago en el modelo (esto actualiza remainingBalance automáticamente)
      _selectedLoan!.registerPayment(newPayment);

      // ✅ VERIFICAR SI QUEDÓ ALGÚN RESIDUAL DESPUÉS DEL PAGO
      final newRemaining = _selectedLoan!.remainingBalance;
      
      // ✅ Si queda un residual pequeño después del pago, crear pago adicional automático
      if (newRemaining > 0 && newRemaining <= _residualThreshold) {
        debugPrint('🔧 Ajustando residual de \$$newRemaining');
        
        final residualPayment = Payment(
          id: const Uuid().v4(),
          loanId: loanIdToUse,
          amount: newRemaining,
          date: _selectedDate,
        );
        
        // ✅ Registrar el pago residual (esto dejará el remainingBalance en 0.0)
        _selectedLoan!.registerPayment(residualPayment);
        await _paymentRepository.addPayment(residualPayment);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pago registrado. Se ajustó residual de \$${_formatCurrency(newRemaining)}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else if (newRemaining > _residualThreshold && newRemaining <= 1.0) {
        // ✅ Caso especial: residuales entre 50 centavos y 1 peso
        debugPrint('🔧 Residual moderado detectado: \$$newRemaining');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Préstamo casi pagado. Saldo restante: \$${_formatCurrency(newRemaining)}'),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Pagar saldo',
                onPressed: () {
                  // ✅ Opción para pagar el saldo restante inmediatamente
                  _amountController.text = _formatCurrency(newRemaining);
                  _savePayment();
                },
              ),
            ),
          );
        }
      }

      // ✅ PERSISTIR LOS CAMBIOS
      await _paymentRepository.addPayment(newPayment);
      await _loanRepository.updateLoan(_selectedLoan!);

      // ✅ VERIFICACIÓN FINAL
      final persisted = await _loanRepositoryGetter(_selectedLoan!.id);
      debugPrint(
          '>>> Pago completado. loanId=${persisted?.id} '
          'remaining=${persisted?.remainingBalance} '
          'isFullyPaid=${persisted?.isFullyPaid} '
          'status=${persisted?.status}');

      if (!mounted) return;
      
      // ✅ MOSTRAR CONFIRMACIÓN
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pago registrado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );

      // ✅ Devolver true para indicar éxito y recargar la pantalla anterior
      Navigator.pop(context, true);
    } catch (e) {
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

  Future<LoanModel?> _loanRepositoryGetter(String? id) async {
    if (id == null || id.isEmpty) return null;
    try {
      return await _loanRepository.getLoanById(id);
    } catch (_) {
      return null;
    }
  }

  String _formatLoanDisplayText(LoanModel loan) {
    final idSafe = loan.id;
    final shortId = idSafe.length > 4 ? idSafe.substring(0, 4) : idSafe;
    final cuota = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0)
        .format((loan.calculatedPaymentAmount ?? 0).round());
    
    // ✅ MOSTRAR SALDO CON 2 DECIMALES PARA VISUALIZAR RESIDUALES
    final saldo = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 2)
        .format(loan.remainingBalance);
    
    // ✅ INDICADORES MEJORADOS DE RESIDUALES
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
                      // ✅ INDICADORES VISUALES MEJORADOS DE RESIDUALES
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
                    // ✅ CON ESTO:
                  Builder(
                    builder: (BuildContext builderContext) {
                      return TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Fecha del Pago',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        onTap: () async {
                          final selectedDate = await showDatePicker(
                            context: builderContext,
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
                      );
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
                        // ✅ MEJORADO: Hint text inteligente para residuales
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
                        
                        // ✅ CORREGIDO: Usar el método auxiliar para parseo consistente
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