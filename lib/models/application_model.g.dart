// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'application_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ApplicationFormAdapter extends TypeAdapter<ApplicationForm> {
  @override
  final int typeId = 1;

  @override
  ApplicationForm read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ApplicationForm(
      id: fields[0] as String?,
      title: fields[1] as String,
      name: fields[2] as String,
      gender: fields[3] as String,
      contact: fields[4] as String,
      major: fields[5] as String,
      studentId: fields[6] as String,
      grade: fields[7] as String,
      selfIntroduction: fields[8] as String,
      etc: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ApplicationForm obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.gender)
      ..writeByte(4)
      ..write(obj.contact)
      ..writeByte(5)
      ..write(obj.major)
      ..writeByte(6)
      ..write(obj.studentId)
      ..writeByte(7)
      ..write(obj.grade)
      ..writeByte(8)
      ..write(obj.selfIntroduction)
      ..writeByte(9)
      ..write(obj.etc);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationFormAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
