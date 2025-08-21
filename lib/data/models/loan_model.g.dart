// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loan_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LoanModelAdapter extends TypeAdapter<LoanModel> {
  @override
  final int typeId = 3;

  @override
  LoanModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LoanModel(
      id: fields[0] as String?,
      clientId: fields[1] as String,
      amount: fields[2] as double,
      interestRate: fields[3] as double,
      termValue: fields[4] as int,
      startDate: fields[5] as DateTime,
      dueDate: fields[6] as DateTime,
      status: fields[7] as String,
      paymentFrequency: fields[8] as String,
      whatsappNumber: fields[9] as String?,
      phoneNumber: fields[10] as String?,
      termUnit: fields[11] as String,
    );
  }

  @override
  void write(BinaryWriter writer, LoanModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.clientId)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.interestRate)
      ..writeByte(4)
      ..write(obj.termValue)
      ..writeByte(5)
      ..write(obj.startDate)
      ..writeByte(6)
      ..write(obj.dueDate)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.paymentFrequency)
      ..writeByte(9)
      ..write(obj.whatsappNumber)
      ..writeByte(10)
      ..write(obj.phoneNumber)
      ..writeByte(11)
      ..write(obj.termUnit);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoanModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
