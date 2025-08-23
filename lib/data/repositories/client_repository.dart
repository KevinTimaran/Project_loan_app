// lib/data/repositories/client_repository.dart
import 'package:hive/hive.dart';
import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/domain/repositories/i_client_repository.dart';
import 'package:loan_app/data/models/loan_model.dart';

class ClientRepository implements IClientRepository {
  static const String _clientBoxName = 'clients';
  static const String _loanBoxName = 'loans';

  Future<Box<Client>> _getClientBox() async {
    return await Hive.openBox<Client>(_clientBoxName);
  }

  Future<Box<LoanModel>> _getLoanBox() async {
    return await Hive.openBox<LoanModel>(_loanBoxName);
  }

  @override
  Future<void> createClient(Client client) async {
    final box = await _getClientBox();
    await box.put(client.id, client);
  }

  @override
  Future<List<Client>> getClients() async {
    final box = await _getClientBox();
    return box.values.toList();
  }

  @override
  Future<List<Client>> searchClients(String query) async {
    final box = await _getClientBox();
    final lowerCaseQuery = query.toLowerCase();
    return box.values
        .where((client) =>
            // 💡 Esta línea busca el nombre y apellido en el repositorio
            client.name.toLowerCase().contains(lowerCaseQuery) ||
            client.lastName.toLowerCase().contains(lowerCaseQuery))
        .toList();
  }

  @override
  Future<void> updateClient(Client client) async {
    final box = await _getClientBox();
    await box.put(client.id, client);
  }

  @override
  Future<void> deleteClient(String clientId) async {
    final hasLoans = await hasActiveLoans(clientId);
    if (hasLoans) {
      throw Exception('No se puede eliminar un cliente con préstamos activos.');
    }
    final box = await _getClientBox();
    await box.delete(clientId);
  }

  @override
  Future<bool> hasActiveLoans(String clientId) async {
    final loanBox = await _getLoanBox();
    return loanBox.values
        .where((loan) => loan.clientId == clientId && loan.status == 'activo')
        .isNotEmpty;
  }

  @override
  Future<Client?> getClientById(String clientId) async {
    final box = await _getClientBox();
    return box.get(clientId);
  }
}