// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'highlight_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HighlightModelAdapter extends TypeAdapter<HighlightModel> {
  @override
  final int typeId = 3;

  @override
  HighlightModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HighlightModel(
      id: fields[0] as String,
      bookId: fields[1] as String,
      chapterId: fields[2] as int,
      verseNumber: fields[3] as int,
      colorHex: fields[4] as String,
      createdAt: fields[5] as DateTime,
      note: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HighlightModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.chapterId)
      ..writeByte(3)
      ..write(obj.verseNumber)
      ..writeByte(4)
      ..write(obj.colorHex)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HighlightModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
