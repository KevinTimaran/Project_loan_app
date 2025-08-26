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

  @override
  void initState() {
    super.initState();
    _loadClientDetails();
  }

  Future<void> _loadClientDetails() async {
    final allClients = await _getClients.call();
    setState(() {
      _client = allClients.firstWhere((c) => c.id == widget.clientId);
    });
  }

  Future<void> _confirmDeleteClient() async {
    if (_client == null) return;

    final hasActiveLoans = await _checkClientActiveLoans.call(_client!.id);

    if (hasActiveLoans) {
      // ignore: use_build_context_synchronously
      _showAlertDialog(
        context,
        'No se puede eliminar',
        'El cliente tiene préstamos activos y no puede ser eliminado.',
      );
      return;
    }

    // ignore: use_build_context_synchronously
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text(
            '¿Estás seguro de que quieres eliminar a ${_client!.name} ${_client!.lastName}?'),
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
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente eliminado exitosamente')),
        );
        // ignore: use_build_context_synchronously
        Navigator.pop(context); // Regresar a la lista de clientes
      } catch (e) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar cliente: $e')),
        );
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

  // 💡 Lógica para llamadas y WhatsApp
  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la aplicación.')),
      );
    }
  }

  void _makePhoneCall() {
    if (_client?.phone != null && _client!.phone.isNotEmpty) {
      _launchUrl('tel:${_client!.phone}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El cliente no tiene un número de teléfono registrado.')),
      );
    }
  }

  void _sendWhatsAppMessage() {
    if (_client?.whatsapp != null && _client!.whatsapp.isNotEmpty) {
      _launchUrl('https://wa.me/${_client!.whatsapp}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El cliente no tiene un número de WhatsApp registrado.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_client == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalles del Cliente')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${_client!.name} ${_client!.lastName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              // Navegar a la pantalla de formulario para editar
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ClientFormScreen(client: _client),
                ),
              );
              // 💡 ¡Este es el paso clave! Recargar los detalles del cliente al volver
              _loadClientDetails();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Nombre:', '${_client!.name} ${_client!.lastName}'),
            _buildInfoRow('Identificación:', _client!.identification),
            _buildInfoRow('Dirección:', _client!.address ?? 'N/A'),
            _buildInfoRow('Teléfono:', _client!.phone),
            _buildInfoRow('WhatsApp:', _client!.whatsapp),
            _buildInfoRow('Notas:', _client!.notes),
            const Divider(),
            // 💡 Botones de llamada y WhatsApp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _makePhoneCall,
                  icon: const Icon(Icons.phone),
                  label: const Text('Llamar'),
                ),
                ElevatedButton.icon(
                  onPressed: _sendWhatsAppMessage,
                  icon: const Icon(FontAwesomeIcons.whatsapp),
                  label: const Text('WhatsApp'),
                ),
              ],
            ),
            const Divider(),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Funcionalidad de préstamos por cliente (próximamente)')),
                );
              },
              child: const Text('Ver Préstamos del Cliente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}