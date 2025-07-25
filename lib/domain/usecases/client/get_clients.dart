import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/domain/repositories/i_client_repository.dart';

class GetClients {
  final IClientRepository repository;

  GetClients(this.repository);

  Future<List<Client>> call() {
    return repository.getClients();
  }
}