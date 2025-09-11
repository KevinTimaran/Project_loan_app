// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loan_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LoanModelAdapter extends TypeAdapter<LoanModel> {
  @override
  final int typeId = 2;

  @override
  LoanModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LoanModel(
      id: fields[0] as String?,
      clientId: fields[1] as String,
      clientName: fields[2] as String,
      amount: fields[3] as double,
      interestRate: fields[4] as double,
      termValue: fields[5] as int,
      startDate: fields[6] as DateTime,
      dueDate: fields[7] as DateTime,
      status: fields[8] as String,
      paymentFrequency: fields[9] as String,
      whatsappNumber: fields[10] as String?,
      phoneNumber: fields[11] as String?,
      termUnit: fields[12] as String,
      loanNumber: fields[13] as int?,
      totalPaid: fields[16] as double,
      payments: (fields[18] as List?)?.cast<Payment>(),
      remainingBalance: fields[17] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, LoanModel obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.clientId)
      ..writeByte(2)
      ..write(obj.clientName)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.interestRate)
      ..writeByte(5)
      ..write(obj.termValue)
      ..writeByte(6)
      ..write(obj.startDate)
      ..writeByte(7)
      ..write(obj.dueDate)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.paymentFrequency)
      ..writeByte(10)
      ..write(obj.whatsappNumber)
      ..writeByte(11)
      ..write(obj.phoneNumber)
      ..writeByte(12)
      ..write(obj.termUnit)
      ..writeByte(13)
      ..write(obj.loanNumber)
      ..writeByte(14)
      ..write(obj.totalAmountToPay)
      ..writeByte(15)
      ..write(obj.calculatedPaymentAmount)
      ..writeByte(16)
      ..write(obj.totalPaid)
      ..writeByte(17)
      ..write(obj.remainingBalance)
      ..writeByte(18)
      ..write(obj.payments);
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
