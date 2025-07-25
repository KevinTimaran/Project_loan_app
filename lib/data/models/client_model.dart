import 'package:hive/hive.dart';
import 'package:loan_app/domain/entities/client.dart';

part 'client_model.g.dart'; // Este archivo se generará automáticamente

@HiveType(typeId: 0) // El typeId debe ser único para cada modelo
class ClientModel extends Client {
  @HiveField(0)
  final String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  String lastName;
  @HiveField(3)
  String identification;
  @HiveField(4)
  String address;
  @HiveField(5)
  String phone;
  @HiveField(6)
  String whatsapp;

  ClientModel({
    required this.id,
    required this.name,
    required this.lastName,
    required this.identification,
    required this.address,
    required this.phone,
    required this.whatsapp,
  }) : super(
          id: id,
          name: name,
          lastName: lastName,
          identification: identification,
          address: address,
          phone: phone,
          whatsapp: whatsapp,
        );

  // Método para convertir de entidad a modelo
  factory ClientModel.fromEntity(Client client) {
    return ClientModel(
      id: client.id,
      name: client.name,
      lastName: client.lastName,
      identification: client.identification,
      address: client.address,
      phone: client.phone,
      whatsapp: client.whatsapp,
    );
  }

  // Método para convertir de modelo a entidad
  Client toEntity() {
    return Client(
      id: id,
      name: name,
      lastName: lastName,
      identification: identification,
      address: address,
      phone: phone,
      whatsapp: whatsapp,
    );
  }
}