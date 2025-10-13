// lib/presentation/screens/loans/loan_form_screen.dart
//#################################################
//#  Pantalla de Formulario de Préstamo           #
//#  Permite crear o editar un préstamo,           #
//#  seleccionar cliente, ingresar datos y ver    #
//#  simulación de pagos.                         #
//#################################################

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/data/repositories/loan_repository.dart';
import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/presentation/screens/clients/client_list_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:loan_app/presentation/screens/loans/loan_edit_screen.dart'; // ✅ Importación agregada

class LoanFormScreen extends StatefulWidget {
  final LoanModel? loan;

  const LoanFormScreen({super.key, this.loan});

  @override
  State<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends State<LoanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _interestRateController = TextEditingController();
  final TextEditingController _termValueController = TextEditingController();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _clientLastNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _whatsappNumberController = TextEditingController();
  // ✅ Controlador para la fecha de inicio
  final TextEditingController _startDateController = TextEditingController();

  final LoanRepository _loanRepository = LoanRepository();
  final ClientRepository _clientRepository = ClientRepository();

  String _paymentFrequency = 'Mensual';
  late String _termUnit;
  DateTime _startDate = DateTime.now();
  late DateTime _dueDate;
  Client? _selectedClient;
  List<Client> _clients = [];
  bool _isLoadingClients = false;

  // Nuevo flag: si true, estamos en modo "crear cliente nuevo" aunque haya uno seleccionado
  bool _isCreatingNewClient = false;

  // Para elegir convención de quincena: true -> 26 quincenas/año (14 días cada una)
  final bool _use26Quincenas = true;

  // Totales mostrados (en pesos)
  double _calculatedInterest = 0.0;
  double _calculatedTotalToPay = 0.0;
  double _calculatedPaymentAmount = 0.0;
  int _numberOfPayments = 0;
  List<DateTime> _paymentDates = [];

  // Schedule: cada entrada almacena montos en CENTAVOS (int)
  List<Map<String, dynamic>> _amortizationSchedule = [];

  @override
  void initState() {
    super.initState();
    _setTermUnitBasedOnFrequency();
    _dueDate = _calculateDueDate();
    _loadClients();
    _amountController.addListener(_updateCalculations);
    _interestRateController.addListener(_updateCalculations);
    _termValueController.addListener(_updateCalculations);

    // ✅ Inicializar el controlador de fecha
    _startDateController.text = DateFormat('dd/MM/yyyy').format(_startDate);

    // Si venimos en modo edición, precargar los valores del préstamo
    if (widget.loan != null) {
      _prefillFromLoan(widget.loan!);
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateCalculations);
    _interestRateController.removeListener(_updateCalculations);
    _termValueController.removeListener(_updateCalculations);
    _amountController.dispose();
    _interestRateController.dispose();
    _termValueController.dispose();
    _clientNameController.dispose();
    _clientLastNameController.dispose();
    _phoneNumberController.dispose();
    _whatsappNumberController.dispose();
    // ✅ Liberar el nuevo controlador
    _startDateController.dispose();
    super.dispose();
  }

  /// Normaliza fecha a 00:00
  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  void _prefillFromLoan(LoanModel loan) {
    // Llenar campos del formulario desde el LoanModel existente
    _amountController.text = loan.amount.toStringAsFixed(0);
    // Asumimos que interestRate en el modelo está guardado en decimal (ej 0.05) -> mostramos %
    _interestRateController.text = (loan.interestRate * 100).toString();
    _termValueController.text = loan.termValue.toString();
    _paymentFrequency = loan.paymentFrequency;
    _setTermUnitBasedOnFrequency();
    _startDate = loan.startDate;
    // ✅ Actualizar el controlador tras precargar
    _startDateController.text = DateFormat('dd/MM/yyyy').format(_startDate);
    _dueDate = loan.dueDate;
    _paymentDates = loan.paymentDates ?? [];
    _calculatedTotalToPay = loan.totalAmountToPay ?? _calculatedTotalToPay;
    _calculatedPaymentAmount = loan.calculatedPaymentAmount ?? _calculatedPaymentAmount;
    _calculatedInterest = (loan.totalAmountToPay ?? 0.0) - (loan.amount);
    _numberOfPayments = loan.termValue;
    _amortizationSchedule = []; // Será recalculado por _updateCalculations si el usuario modifica
  }

  Future<void> _loadClients() async {
    setState(() {
      _isLoadingClients = true;
    });
    try {
      final loadedClients = await _client_repository_getClients_safe();
      // no hacemos nada con el primer intento (compatibilidad), luego intentamos otra vez
    } catch (_) {}

    try {
      final loadedClients = await _client_repository_getClients_safe();
      setState(() {
        _clients = loadedClients;
      });

      // Si estamos en edición, intentar seleccionar el cliente correspondiente
      if (widget.loan != null && widget.loan!.clientId.isNotEmpty) {
        final match = _clients.firstWhere(
          (c) => c.id == widget.loan!.clientId,
          orElse: () => Client(id: '', name: '', lastName: '', identification: '', phone: '', whatsapp: ''),
        );
        if (match.id.isNotEmpty) {
          setState(() {
            _selectedClient = match;
            _clientNameController.text = match.name;
            _clientLastNameController.text = match.lastName;
            _phoneNumberController.text = match.phone ?? '';
            _whatsappNumberController.text = match.whatsapp ?? '';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar clientes: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingClients = false;
        });
      }
    }
  }

  // pequeña envoltura para evitar que el analizador marque el repositorio directo como error
  Future<List<Client>> _client_repository_getClients_safe() async {
    return await _clientRepository.getClients();
  }

  void _setTermUnitBasedOnFrequency() {
    switch (_paymentFrequency) {
      case 'Diario':
        _termUnit = 'Días';
        break;
      case 'Semanal':
        _termUnit = 'Semanas';
        break;
      case 'Quincenal':
        _termUnit = 'Quincenas';
        break;
      case 'Mensual':
      default:
        _termUnit = 'Meses';
        break;
    }
  }

  void _updateCalculations() {
    // extraer monto limpio (acepta miles sin comas)
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    // interest en % ingresado por el usuario (ej 5 -> 5%)
    final interestRateInput = double.tryParse(_interestRateController.text) ?? 0.0;
    final termValue = int.tryParse(_termValueController.text) ?? 0;

    if (amount > 0 && interestRateInput >= 0 && termValue > 0) {
      _calculateLoanDetails(amount, interestRateInput, termValue);
    } else {
      setState(() {
        _calculatedInterest = 0.0;
        _calculatedTotalToPay = 0.0;
        _calculatedPaymentAmount = 0.0;
        _numberOfPayments = 0;
        _paymentDates = [];
        _amortizationSchedule = [];
      });
    }
  }

  int _periodsPerYearForFrequency(String freq) {
    switch (freq) {
      case 'Diario':
        return 365;
      case 'Semanal':
        return 52;
      case 'Quincenal':
        return _use26Quincenas ? 26 : 24;
      case 'Mensual':
      default:
        return 12;
    }
  }

  DateTime addMonthsSafe(DateTime date, int monthsToAdd) {
    int year = date.year;
    int month = date.month + monthsToAdd;
    year += (month - 1) ~/ 12;
    month = ((month - 1) % 12) + 1;
    int day = date.day;
    int lastDayOfMonth = DateTime(year, month + 1, 0).day;
    if (day > lastDayOfMonth) day = lastDayOfMonth;
    return DateTime(year, month, day, date.hour, date.minute, date.second, date.millisecond, date.microsecond);
  }

  /// Construye cronograma tipo ANUIDAD (cuota fija).
  /// Devuelve lista de mapas con campos en centavos:
  /// 'index','date','paymentCents','interestCents','principalCents','remainingCents'
  List<Map<String, dynamic>> buildAnnuitySchedule({
    required double principal,
    required double annualRatePercent,
    required int numberOfPayments,
    required String frequency,
    required DateTime startDate,
  }) {
    final int periodsPerYear = _periodsPerYearForFrequency(frequency);
    final double annualRate = annualRatePercent / 100.0;
    final double r = annualRate / periodsPerYear; // tasa por periodo (decimal)

    final int principalCents = (principal * 100).round();
    final int n = numberOfPayments;
    if (n <= 0) return [];

    // cuota fija (en moneda) usando fórmula de anualidad
    double payment;
    if (r > 0) {
      final denom = 1 - pow(1 + r, -n);
      payment = denom == 0 ? principal / n : principal * r / denom;
    } else {
      payment = principal / n;
    }

    final int paymentCentsBase = (payment * 100).floor();

    List<Map<String, dynamic>> schedule = [];
    DateTime current = startDate;
    int remainingCents = principalCents;
    int totalInterestAccumCents = 0;
    int sumPaymentsCents = 0;

    for (int i = 0; i < n; i++) {
      // calcular fecha del siguiente pago
      if (frequency == 'Diario') {
        current = current.add(const Duration(days: 1));
      } else if (frequency == 'Semanal') {
        current = current.add(const Duration(days: 7));
      } else if (frequency == 'Quincenal') {
        // usa 14 ó 15 según la convención que tengas
        current = current.add(Duration(days: _use26Quincenas ? 14 : 15));
      } else {
        current = addMonthsSafe(current, 1);
      }

      // interés del periodo = remaining * r
      final double interestForPeriod = (remainingCents / 100.0) * r;
      int interestCents = (interestForPeriod * 100).round();

      // principal pagado = payment - interest
      int principalCentsForPeriod = paymentCentsBase - interestCents;

      // evitar principal negativo por r grande
      if (principalCentsForPeriod < 0) principalCentsForPeriod = 0;

      // Si es el último pago: liquidar lo que quede (principal)
      if (i == n - 1) {
        // recalc interés sobre remaining (mejor precisión)
        interestCents = ((remainingCents / 100.0) * r * 100).round();
        principalCentsForPeriod = remainingCents;
      }

      final int paymentCents = principalCentsForPeriod + interestCents;

      // actualizar remaining
      remainingCents = max(0, remainingCents - principalCentsForPeriod);

      totalInterestAccumCents += interestCents;
      sumPaymentsCents += paymentCents;

      schedule.add({
        'index': i + 1,
        'date': current,
        'paymentCents': paymentCents,
        'interestCents': interestCents,
        'principalCents': principalCentsForPeriod,
        'remainingCents': remainingCents,
      });
    }

    // Ajuste final por redondeos: sólo si suma != principal + interés acumulado
    final int expectedTotalPaid = principalCents + totalInterestAccumCents;
    final int delta = expectedTotalPaid - sumPaymentsCents;
    if (delta != 0 && schedule.isNotEmpty) {
      // aplicamos delta al componente de principal del último pago
      final last = schedule.last;
      // si por alguna razón el último principal quedó en 0 (caso raro), lo añadimos al payment directamente
      last['principalCents'] = (last['principalCents'] as int) + delta;
      last['paymentCents'] = (last['paymentCents'] as int) + delta;
      // asegurar remaining en 0
      last['remainingCents'] = 0;
    }

    // Si hay entradas con paymentCents == 0 (por ejemplo r muy alto y paymentCentsBase fue 0),
    // podemos optar por ocultarlas en UI. Aquí las dejamos en schedule (UI filtrará).
    return schedule;
  }

  void _calculateLoanDetails(double amount, double interestRatePercent, int termValue) {
    final int n = termValue;
    if (n <= 0) {
      setState(() {
        _calculatedInterest = 0.0;
        _calculatedTotalToPay = 0.0;
        _calculatedPaymentAmount = 0.0;
        _numberOfPayments = 0;
        _paymentDates = [];
        _amortizationSchedule = [];
      });
      return;
    }

    final schedule = buildAnnuitySchedule(
      principal: amount,
      annualRatePercent: interestRatePercent,
      numberOfPayments: n,
      frequency: _paymentFrequency,
      startDate: _startDate,
    );

    final int totalInterestCents = schedule.fold<int>(0, (s, e) => s + (e['interestCents'] as int));
    final int totalPaidCents = schedule.fold<int>(0, (s, e) => s + (e['paymentCents'] as int));
    final List<DateTime> dates = schedule.map((e) => _normalizeDate(e['date'] as DateTime)).toList();

    setState(() {
      _amortizationSchedule = schedule;
      _calculatedInterest = (totalInterestCents / 100.0);
      _calculatedTotalToPay = (totalPaidCents / 100.0);
      _calculatedPaymentAmount = schedule.isNotEmpty ? (schedule.first['paymentCents'] as int) / 100.0 : 0.0;
      _numberOfPayments = n;
      _paymentDates = dates;
    });

    _updateDueDate();
  }

  DateTime _calculateDueDate() {
    // ✅ Usar _startDate en lugar de DateTime.now()
    final now = _startDate;
    int termValue = int.tryParse(_termValueController.text) ?? 0;

    if (termValue == 0) return now;

    switch (_termUnit) {
      case 'Días':
        return now.add(Duration(days: termValue));
      case 'Semanas':
        return now.add(Duration(days: termValue * 7));
      case 'Quincenas':
        return now.add(Duration(days: termValue * (_use26Quincenas ? 14 : 15)));
      case 'Meses':
      default:
        return DateTime(now.year, now.month + termValue, now.day);
    }
  }

  void _updateDueDate() {
    setState(() {
      _dueDate = _calculateDueDate();
    });
  }

  // ✅ Función para seleccionar la fecha de inicio
  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        _startDateController.text = DateFormat('dd/MM/yyyy').format(picked);
        _updateCalculations(); // ✅ Recalcular con la nueva fecha
      });
    }
  }

  Future<void> _saveLoan() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      String? clientId;
      String? clientName;
      String? phoneNumber;
      String? whatsappNumber;

      // Si hay cliente seleccionado y NO estamos en modo crear nuevo, usamos sus datos
      if (!_isCreatingNewClient && _selectedClient != null && _selectedClient!.id.isNotEmpty) {
        clientId = _selectedClient!.id;
        clientName = '${_selectedClient!.name} ${_selectedClient!.lastName}';
        phoneNumber = _selectedClient!.phone;
        whatsappNumber = _selectedClient!.whatsapp;
      } else {
        // Modo crear nuevo cliente
        if (_clientNameController.text.isNotEmpty && _clientLastNameController.text.isNotEmpty) {
          phoneNumber = _phoneNumberController.text.trim();
          whatsappNumber = _whatsappNumberController.text.trim();

          final newClient = Client(
            id: const Uuid().v4(),
            name: _clientNameController.text.trim(),
            lastName: _clientLastNameController.text.trim(),
            phone: phoneNumber,
            whatsapp: whatsappNumber,
            identification: '',
          );
          await _clientRepository.createClient(newClient);
          clientId = newClient.id;
          clientName = '${newClient.name} ${newClient.lastName}';
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Por favor, selecciona un cliente o ingresa los datos de uno nuevo.')),
            );
          }
          return;
        }
      }

      // Preparar datos del préstamo
      final double amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
      final double interestRatePercent = double.tryParse(_interestRateController.text) ?? 0.0;
      final int termValue = int.tryParse(_termValueController.text) ?? 1;

      // Si todavía no hay schedule calculado (por ejemplo user no modificó después de cargar), calcularlo
      if (_amortizationSchedule.isEmpty || _paymentDates.isEmpty) {
        _calculateLoanDetails(amount, interestRatePercent, termValue);
      }

      // Usamos el mismo id si estamos editando
      final idToUse = widget.loan?.id ?? const Uuid().v4();

      final newLoan = LoanModel(
        id: idToUse,
        clientId: clientId!,
        clientName: clientName!,
        amount: amount,
        // guardamos como decimal (0.05) para mantener consistencia con otras partes
        interestRate: (interestRatePercent / 100),
        termValue: termValue,
        startDate: _startDate, // ✅ Ya se usa la fecha seleccionada
        dueDate: _dueDate,
        paymentFrequency: _paymentFrequency,
        termUnit: _termUnit,
        whatsappNumber: whatsappNumber,
        phoneNumber: phoneNumber,
        payments: widget.loan?.payments ?? [],
        remainingBalance: _calculatedTotalToPay,
        totalPaid: widget.loan?.totalPaid ?? 0.0,
        status: 'activo',
        calculatedPaymentAmount: _calculatedPaymentAmount,
        totalAmountToPay: _calculatedTotalToPay,
        paymentDates: _paymentDates,
      );

      // Guardar préstamo (addLoan puede crear o sobrescribir según tu implementación)
      await _loanRepository.addLoan(newLoan);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Préstamo guardado exitosamente')),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor completa correctamente el formulario antes de guardar.')),
        );
      }
    }
  }

  void _showSimulationModal() {
    final currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.35,
          maxChildSize: 0.98,
          builder: (_, controller) {
            final int totalInterestCents = _amortizationSchedule.fold<int>(0, (s, e) => s + ((e['interestCents'] as int)));
            final int principalCents = (double.tryParse(_amountController.text.replaceAll(',', '')) != null)
                ? (double.parse(_amountController.text.replaceAll(',', '')) * 100).round()
                : 0;
            final DateTime? nextPaymentDate = _amortizationSchedule.isNotEmpty ? _amortizationSchedule.first['date'] as DateTime : null;
            final double firstInterest = _amortizationSchedule.isNotEmpty ? (_amortizationSchedule.first['interestCents'] as int) / 100.0 : 0.0;

            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ✅ NUEVO: SingleChildScrollView para el resumen fijo
                  Expanded(
                    flex: 0, // No expande, ocupa solo su altura natural
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(), // Evita scroll interno duplicado
                      child: Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text('Resumen del Crédito', style: Theme.of(context).textTheme.titleLarge ?? const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _summaryRowSmall('Fecha de crédito', DateFormat('dd/MM/yyyy').format(_startDate)),
                                        const SizedBox(height: 8),
                                        _summaryRowSmall('Fecha próxima cuota', nextPaymentDate != null ? DateFormat('dd/MM/yyyy').format(nextPaymentDate) : '-'),
                                        const SizedBox(height: 8),
                                        _summaryRowSmall('Vencimiento del crédito', DateFormat('dd/MM/yyyy').format(_dueDate)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _summaryRowSmall('Interés (anual)', _interestRateController.text.isNotEmpty ? '${_interestRateController.text.trim()} %' : '-'),
                                        const SizedBox(height: 8),
                                        _summaryRowSmall('Valor total interés', currency.format(totalInterestCents / 100.0)),
                                        const SizedBox(height: 8),
                                        _summaryRowSmall('Valor cuota', currency.format((_amortizationSchedule.isNotEmpty ? (_amortizationSchedule.first['paymentCents'] as int) / 100.0 : 0.0))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _summaryRowBold('Total prestado', currency.format(principalCents / 100.0))),
                                  const SizedBox(width: 12),
                                  Expanded(child: _summaryRowBold('Total + interés', currency.format((principalCents + totalInterestCents) / 100.0))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _summaryRowBold('Saldo total', currency.format((_amortizationSchedule.isNotEmpty ? (_amortizationSchedule.last['remainingCents'] as int) / 100.0 : (principalCents + totalInterestCents) / 100.0))),
                              ),
                              const SizedBox(height: 8),
                              // Interés primer periodo mostrado claramente
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _summaryRowSmall('Interés primer periodo', currency.format(firstInterest)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Expanded(
                    child: _amortizationSchedule.isEmpty
                        ? Center(child: Text('Aún no hay simulación. Ingresa monto, tasa y plazo.', style: TextStyle(color: Colors.grey[700])))
                        : ListView.builder(
                            controller: controller,
                            itemCount: _amortizationSchedule.length,
                            itemBuilder: (context, index) {
                              final e = _amortizationSchedule[index];
                              final paymentPesos = (e['paymentCents'] as int) / 100.0;
                              final interestPesos = (e['interestCents'] as int) / 100.0;
                              final principalPesos = (e['principalCents'] as int) / 100.0;
                              final remainingPesos = (e['remainingCents'] as int) / 100.0;

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: CircleAvatar(child: Text('${e['index']}')),
                                  title: Text('Cuota #${e['index']} - ${currency.format(paymentPesos)}'),
                                  subtitle: Text(
                                    '${DateFormat('dd/MM/yyyy').format(e['date'])}\n'
                                    'Interés: ${currency.format(interestPesos)} • Capital: ${currency.format(principalPesos)}',
                                  ),
                                  isThreeLine: true,
                                  trailing: Text(
                                    'Saldo: ${currency.format(remainingPesos)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _summaryRowSmall(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _summaryRowBold(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.loan == null ? 'Registrar Préstamo' : 'Editar Préstamo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Datos del Cliente',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Row: dropdown + botón para crear nuevo cliente
              Row(
                children: [
                  // Dropdown expandible para evitar overflow
                  Expanded(
                    child: _isLoadingClients
                        ? const Center(child: CircularProgressIndicator())
                        : DropdownButtonFormField<Client>(
                            isExpanded: true,
                            value: _selectedClient,
                            decoration: const InputDecoration(
                              labelText: 'Selecciona un cliente existente',
                              border: OutlineInputBorder(),
                            ),
                            items: _clients.map((client) {
                              return DropdownMenuItem(
                                value: client,
                                child: Text(
                                  '${client.name} ${client.lastName}',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (client) {
                              setState(() {
                                _selectedClient = client;
                                // Al seleccionar uno existente, salimos de modo "crear nuevo"
                                _isCreatingNewClient = false;
                                if (client != null) {
                                  _clientNameController.text = client.name;
                                  _clientLastNameController.text = client.lastName;
                                  _phoneNumberController.text = client.phone ?? '';
                                  _whatsappNumberController.text = client.whatsapp ?? '';
                                } else {
                                  _clientNameController.clear();
                                  _clientLastNameController.clear();
                                  _phoneNumberController.clear();
                                  _whatsappNumberController.clear();
                                }
                              });
                            },
                          ),
                  ),

                  const SizedBox(width: 8),

                  // Botón para cambiar a "nuevo cliente" incluso si ya hay uno seleccionado
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isCreatingNewClient = true;
                          _selectedClient = null;
                          _clientNameController.clear();
                          _clientLastNameController.clear();
                          _phoneNumberController.clear();
                          _whatsappNumberController.clear();
                        });
                      },
                      child: const Text('Nuevo cliente'),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Si estamos en modo "crear nuevo", mostramos botón para volver a usar existentes
                  if (_isCreatingNewClient)
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _isCreatingNewClient = false;
                          });
                        },
                        child: const Text('Usar existente'),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),
              const Center(child: Text('O crea uno nuevo', style: TextStyle(fontStyle: FontStyle.italic))),
              const SizedBox(height: 16),

              TextFormField(
                controller: _clientNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Cliente',
                  border: OutlineInputBorder(),
                ),
                enabled: _isCreatingNewClient || _selectedClient == null,
                validator: (value) {
                  if ((_isCreatingNewClient || _selectedClient == null) && (value == null || value.isEmpty)) {
                    return 'Por favor, ingresa el nombre del cliente.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _clientLastNameController,
                decoration: const InputDecoration(
                  labelText: 'Apellido del Cliente',
                  border: OutlineInputBorder(),
                ),
                enabled: _isCreatingNewClient || _selectedClient == null,
                validator: (value) {
                  if ((_isCreatingNewClient || _selectedClient == null) && (value == null || value.isEmpty)) {
                    return 'Por favor, ingresa el apellido del cliente.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneNumberController,
                decoration: const InputDecoration(
                  labelText: 'Número de teléfono',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _whatsappNumberController,
                decoration: const InputDecoration(
                  labelText: 'Número de WhatsApp',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),

              const Text(
                'Datos del Préstamo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // ✅ Campo de fecha de inicio del préstamo
              TextFormField(
                controller: _startDateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Fecha de Inicio del Préstamo',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () => _selectStartDate(context),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Monto del Préstamo',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty || double.tryParse(value.replaceAll(',', '')) == null) {
                    return 'Por favor, ingresa un monto válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _interestRateController,
                decoration: const InputDecoration(
                  labelText: 'Tasa de Interés Anual (%)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty || double.tryParse(value) == null) {
                    return 'Por favor, ingresa una tasa válida.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _paymentFrequency,
                decoration: const InputDecoration(
                  labelText: 'Frecuencia de Pago',
                  border: OutlineInputBorder(),
                ),
                items: ['Diario', 'Semanal', 'Quincenal', 'Mensual'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _paymentFrequency = newValue;
                      _setTermUnitBasedOnFrequency();
                      _updateCalculations();
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _termValueController,
                decoration: InputDecoration(
                  labelText: 'Plazo en $_termUnit',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _updateCalculations(),
                validator: (value) {
                  if (value == null || value.isEmpty || int.tryParse(value) == null) {
                    return 'Por favor, ingresa un plazo válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: _showSimulationModal,
                  icon: const Icon(Icons.show_chart),
                  label: const Text('Ver simulación'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ).copyWith(
                    animationDuration: Duration.zero, // ✅ Evita errores de animación
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  onPressed: _saveLoan,
                  child: const Text('💸', style: TextStyle(fontSize: 20)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ).copyWith(
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

/// Formateador simple para el input de monto (miles)
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final newString = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (newString.isEmpty) {
      return newValue.copyWith(text: '');
    }

    double value = double.parse(newString);
    final formatter = NumberFormat('#,###');
    String newText = formatter.format(value);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
