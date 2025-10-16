// lib/presentation/screens/clients/client_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/domain/usecases/client/check_client_active_loans.dart';
import 'package:loan_app/domain/usecases/client/delete_client.dart';
import 'package:loan_app/domain/usecases/client/get_clients.dart';
import 'package:loan_app/presentation/screens/clients/client_form_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loan_app/presentation/screens/clients/client_history_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final String clientId;

  const ClientDetailScreen({super.key, required this.clientId});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  Client? _client;
  final GetClients _getClients = GetClients(ClientRepository());
  final DeleteClient _deleteClient = DeleteClient(ClientRepository());
  final CheckClientActiveLoans _checkClientActiveLoans =
      CheckClientActiveLoans(ClientRepository());
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClientDetails();
  }

  Future<void> _loadClientDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final allClients = await _getClients.call();
      final client = allClients.firstWhere(
        (c) => c.id == widget.clientId,
        orElse: () => Client(
          id: '',
          name: '',
          lastName: '',
          identification: '',
          phone: '',
          whatsapp: '',
          address: '',
          notes: '',
        ),
      );
      if (client.id.isEmpty) {
        setState(() {
          _client = null;
          _error = 'Cliente no encontrado o eliminado.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _client = client;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _client = null;
        _error = 'Error al cargar cliente: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmDeleteClient() async {
    if (_client == null) return;

    final hasActiveLoans = await _checkClientActiveLoans.call(_client!.id);

    if (hasActiveLoans) {
      _showAlertDialog(
        context,
        'No se puede eliminar',
        'El cliente tiene préstamos activos y no puede ser eliminado.',
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Estás seguro de que quieres eliminar a ${_client!.name} ${_client!.lastName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _deleteClient.call(_client!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cliente eliminado exitosamente')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar cliente: $e')),
          );
        }
      }
    }
  }

  void _showAlertDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir la aplicación.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir enlace: $e')),
        );
      }
    }
  }

  void _makePhoneCall() {
    if (_client?.phone != null && _client!.phone.trim().isNotEmpty) {
      final cleanedPhone = _client!.phone.replaceAll(RegExp(r'\s+'), '');
      _launchUrl('tel:$cleanedPhone');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El cliente no tiene un número de teléfono registrado.')),
        );
      }
    }
  }

  void _sendWhatsAppMessage() {
    if (_client?.whatsapp != null && _client!.whatsapp.trim().isNotEmpty) {
      final cleanedWhatsapp = _client!.whatsapp.replaceAll(RegExp(r'\s+'), '');
      _launchUrl('https://wa.me/$cleanedWhatsapp');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El cliente no tiene un número de WhatsApp registrado.')),
        );
      }
    }
  }

  void _openEditClient() async {
    if (_client == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientFormScreen(client: _client),
      ),
    );
    if (result == true && mounted) {
      _loadClientDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalles del Cliente')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalles del Cliente')),
        body: Center(
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_client == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalles del Cliente')),
        body: const Center(child: Text('Cliente no encontrado o eliminado.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${_client!.name} ${_client!.lastName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _confirmDeleteClient,
            tooltip: 'Eliminar cliente',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: _openEditClient,
                        tooltip: 'Editar cliente',
                      ),
                    ),
                    _buildInfoRow('Nombre:', '${_client!.name} ${_client!.lastName}'),
                    _buildInfoRow('Identificación:', _client!.identification),
                    _buildInfoRow('Dirección:', _client!.address),
                    _buildInfoRow('Teléfono:', _client!.phone),
                    _buildInfoRow('WhatsApp:', _client!.whatsapp),
                    _buildInfoRow('Notas:', _client!.notes),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _makePhoneCall,
                  icon: const Icon(Icons.phone),
                  label: const Text('Llamar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _sendWhatsAppMessage,
                  icon: const Icon(FontAwesomeIcons.whatsapp),
                  label: const Text('WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClientHistoryScreen(
                      clientId: _client!.id,
                    ),
                  ),
                );
              },
              child: const Text('Ver Historial de Préstamos del Cliente'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    final displayValue = value != null && value.trim().isNotEmpty ? value : 'N/A';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(displayValue)),
        ],
      ),
    );
  }
}