import 'package:loan_app/domain/repositories/i_client_repository.dart';

class CheckClientActiveLoans {
  final IClientRepository repository;

  CheckClientActiveLoans(this.repository);

  Future<bool> call(String clientId) {
    return repository.hasActiveLoans(clientId);
  }
}
