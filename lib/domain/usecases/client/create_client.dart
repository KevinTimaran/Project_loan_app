import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/domain/repositories/i_client_repository.dart';

class CreateClient {
  final IClientRepository repository;

  CreateClient(this.repository);

  Future<void> call(Client client) {
    return repository.createClient(client);
  }
}