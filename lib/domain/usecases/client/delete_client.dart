import 'package:loan_app/domain/repositories/i_client_repository.dart';

class DeleteClient {
  final IClientRepository repository;

  DeleteClient(this.repository);

  Future<void> call(String clientId) {
    return repository.deleteClient(clientId);
  }
}