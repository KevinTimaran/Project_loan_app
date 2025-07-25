import 'package:hive/hive.dart';
import 'package:loan_app/data/models/client_model.dart';
import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/domain/repositories/i_client_repository.dart';
import 'package:loan_app/data/models/loan_model.dart'; // Necesario para la validación de préstamos

class ClientRepository implements IClientRepository {
  static const String _clientBoxName = 'clients';
  static const String _loanBoxName =
      'loans'; // Con esto se verifico préstamos activos

  Future<Box<ClientModel>> _getClientBox() async {
    return await Hive.openBox<ClientModel>(_clientBoxName);
  }

  Future<Box<LoanModel>> _getLoanBox() async {
    return await Hive.openBox<LoanModel>(_loanBoxName);
  }

  @override
  Future<void> createClient(Client client) async {
    final box = await _getClientBox();
    await box.put(client.id, ClientModel.fromEntity(client));
  }

  @override
  Future<List<Client>> getClients() async {
    final box = await _getClientBox();
    return box.values.map((model) => model.toEntity()).toList();
  }

  @override
  Future<List<Client>> searchClients(String query) async {
    final box = await _getClientBox();
    final lowerCaseQuery = query.toLowerCase();
    return box.values
        .where((clientModel) =>
            clientModel.name.toLowerCase().contains(lowerCaseQuery) ||
            clientModel.lastName.toLowerCase().contains(lowerCaseQuery))
        .map((model) => model.toEntity())
        .toList();
  }

  @override
  Future<void> updateClient(Client client) async {
    final box = await _getClientBox();
    await box.put(client.id, ClientModel.fromEntity(client));
  }

  @override
  Future<void> deleteClient(String clientId) async {
    final box = await _getClientBox();
    await box.delete(clientId);
  }

  @override
  Future<bool> hasActiveLoans(String clientId) async {
    final loanBox = await _getLoanBox();
    // Suponiendo que el LoanModel tendrá un campo `clientId` y `isFullyPaid`
    // Necesitarás definir LoanModel y su lógica para `isFullyPaid` más adelante.
    return loanBox.values
        .where((loan) => loan.clientId == clientId && !loan.isFullyPaid)
        .isNotEmpty;
  }
}
