import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/domain/repositories/i_client_repository.dart';

class SearchClients {
  final IClientRepository repository;

  SearchClients(this.repository);

  Future<List<Client>> call(String query) {
    return repository.searchClients(query);
  }
}