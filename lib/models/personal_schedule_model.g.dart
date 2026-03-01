// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_schedule_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PersonalScheduleAdapter extends TypeAdapter<PersonalSchedule> {
  @override
  final int typeId = 3;

  @override
  PersonalSchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PersonalSchedule(
      id: fields[0] as String,
      title: fields[1] as String,
      startDate: fields[2] as DateTime,
      endDate: fields[3] as DateTime,
      memo: fields[4] as String?,
      colorValue: fields[5] as int,
      notifyBefore: fields[6] as bool,
      notifyMinutesBefore: fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PersonalSchedule obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.startDate)
      ..writeByte(3)
      ..write(obj.endDate)
      ..writeByte(4)
      ..write(obj.memo)
      ..writeByte(5)
      ..write(obj.colorValue)
      ..writeByte(6)
      ..write(obj.notifyBefore)
      ..writeByte(7)
      ..write(obj.notifyMinutesBefore);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonalScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
