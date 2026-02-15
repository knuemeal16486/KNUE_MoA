// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notice_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NoticeAdapter extends TypeAdapter<Notice> {
  @override
  final int typeId = 0;

  @override
  Notice read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Notice(
      id: fields[0] as int,
      category: fields[1] as String,
      group: fields[2] as String,
      title: fields[3] as String,
      date: fields[4] as String,
      author: fields[5] as String,
      link: fields[6] as String,
      isNew: fields[7] as bool,
      isRead: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Notice obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.category)
      ..writeByte(2)
      ..write(obj.group)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.author)
      ..writeByte(6)
      ..write(obj.link)
      ..writeByte(7)
      ..write(obj.isNew)
      ..writeByte(8)
      ..write(obj.isRead);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoticeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
