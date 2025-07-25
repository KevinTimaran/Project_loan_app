import 'package:flutter/material.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/domain/usecases/client/get_clients.dart';
import 'package:loan_app/domain/usecases/client/search_clients.dart';
import 'package:loan_app/presentation/screens/clients/client_form_screen.dart';
import 'package:loan_app/presentation/screens/clients/client_detail_screen.dart'; // Necesario para ver detalles

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Client> _clients = [];
  List<Client> _filteredClients = [];
  final GetClients _getClients = GetClients(ClientRepository());
  final SearchClients _searchClients = SearchClients(ClientRepository());

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    final clients = await _getClients.call();
    setState(() {
      _clients = clients;
      _filteredClients = clients; // Inicialmente, todos los clientes
    });
  }

  void _onSearchChanged() async {
    if (_searchController.text.isEmpty) {
      setState(() {
        _filteredClients = _clients;
      });
    } else {
      final searchedClients = await _searchClients.call(_searchController.text);
      setState(() {
        _filteredClients = searchedClients;
      });
    }
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
              _loadClients(); // Recargar clientes después de agregar uno nuevo
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
          Expanded(
            child: _filteredClients.isEmpty
                ? const Center(child: Text('No hay clientes registrados.'))
                : ListView.builder(
                    itemCount: _filteredClients.length,
                    itemBuilder: (context, index) {
                      final client = _filteredClients[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          title: Text('${client.name} ${client.lastName}'),
                          subtitle: Text(client.identification),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ClientDetailScreen(clientId: client.id),
                              ),
                            );
                            _loadClients(); // Recargar clientes si se editó o eliminó
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}