import 'package:loan_app/domain/entities/client.dart';

abstract class IClientRepository {
  Future<void> createClient(Client client);
  Future<List<Client>> getClients();
  Future<List<Client>> searchClients(String query);
  Future<void> updateClient(Client client);
  Future<void> deleteClient(String clientId);
  Future<bool> hasActiveLoans(String clientId); // Para validación RF005
}