// lib/domain/entities/client.dart
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'client.g.dart';

@HiveType(typeId: 1)
class Client extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  String lastName;
  @HiveField(3)
  String identification;
  @HiveField(4)
  String? address;
  @HiveField(5)
  String phone;
  @HiveField(6)
  String whatsapp;
  @HiveField(7) 
  String notes;

  Client({
    String? id,
    required this.name,
    this.lastName = '',
    required this.identification,
    this.address,
    required this.phone,
    required this.whatsapp,
    this.notes = '',
      }) : id = id ?? const Uuid().v4();
}