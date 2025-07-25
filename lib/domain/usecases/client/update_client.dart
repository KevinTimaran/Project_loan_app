import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/domain/repositories/i_client_repository.dart';

class UpdateClient {
  final IClientRepository repository;

  UpdateClient(this.repository);

  Future<void> call(Client client) {
    return repository.updateClient(client);
  }
}