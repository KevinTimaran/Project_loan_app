import 'package:flutter/material.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/domain/usecases/client/get_clients.dart';
import 'package:loan_app/domain/usecases/client/search_clients.dart';
import 'package:loan_app/presentation/screens/clients/client_form_screen.dart';
import 'package:loan_app/presentation/screens/clients/client_detail_screen.dart';
import 'package:loan_app/presentation/screens/clients/client_history_screen.dart';

class ClientListScreen extends StatefulWidget {
  final String? searchTerm;

  const ClientListScreen({super.key, this.searchTerm});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Client> _clients = [];
  List<Client> _filteredClients = [];
  final GetClients _getClients = GetClients(ClientRepository());
  final SearchClients _searchClients = SearchClients(ClientRepository());
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchController.addListener(_onSearchChanged);

    if (widget.searchTerm != null && widget.searchTerm!.isNotEmpty) {
      _searchController.text = widget.searchTerm!;
      _onSearchChanged();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final clients = await _getClients.call();
      setState(() {
        _clients = clients;
        _filteredClients = clients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error al cargar clientes: $e';
      });
    }
  }

  void _onSearchChanged() async {
    if (_searchController.text.isEmpty) {
      setState(() {
        _filteredClients = _clients;
      });
    } else {
      try {
        final searchedClients = await _searchClients.call(_searchController.text);
        setState(() {
          _filteredClients = searchedClients;
        });
      } catch (e) {
        setState(() {
          _error = 'Error al buscar clientes: $e';
        });
      }
    }
  }

  Widget _buildClientTile(Client client) {
    // Manejo de nulos y datos incompletos
    final String displayName = '${client.name.isNotEmpty ? client.name : 'Sin nombre'} ${client.lastName.isNotEmpty ? client.lastName : ''}'.trim();
    final String displayId = client.identification.isNotEmpty ? client.identification : 'Sin ID';
    final bool hasNotes = client.notes.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(client.name.isNotEmpty ? client.name[0].toUpperCase() : '?'),
        ),
        title: Text(displayName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: $displayId'),
            if (hasNotes)
              Text('Notas: ${client.notes}', maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClientDetailScreen(clientId: client.id),
            ),
          );
          _loadClients();
        },
        trailing: IconButton(
          icon: const Icon(Icons.history, color: Colors.blueGrey),
          tooltip: 'Ver historial',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ClientHistoryScreen(clientId: client.id),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ClientFormScreen()),
              );
              _loadClients();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar Cliente',
                hintText: 'Nombre o Apellido',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (_filteredClients.isEmpty)
            const Expanded(
              child: Center(child: Text('No hay clientes registrados.')),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _filteredClients.length,
                itemBuilder: (context, index) {
                  final client = _filteredClients[index];
                  return _buildClientTile(client);
                },
              ),
            ),
        ],
      ),
    );
  }
}