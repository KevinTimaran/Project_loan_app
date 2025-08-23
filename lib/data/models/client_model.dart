// lib/data/models/client_model.dart
import 'package:loan_app/domain/entities/client.dart';
import 'package:hive/hive.dart';

part 'client_model.g.dart';

@HiveType(typeId: 2)
class ClientModel extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  String lastName;
  @HiveField(3)
  String identification;
  @HiveField(4)
  String? address; // 💡 Cambiado a String?
  @HiveField(5)
  String phone;
  @HiveField(6)
  String whatsapp;

  ClientModel({
    required this.id,
    required this.name,
    required this.lastName,
    required this.identification,
    this.address,
    required this.phone,
    required this.whatsapp,
  });

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