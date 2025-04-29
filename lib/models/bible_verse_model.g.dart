// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bible_verse_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BibleVerseModelAdapter extends TypeAdapter<BibleVerseModel> {
  @override
  final int typeId = 10;

  @override
  BibleVerseModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BibleVerseModel(
      book: fields[0] as String,
      chapter: fields[1] as int,
      verse: fields[2] as int,
      text: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, BibleVerseModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.book)
      ..writeByte(1)
      ..write(obj.chapter)
      ..writeByte(2)
      ..write(obj.verse)
      ..writeByte(3)
      ..write(obj.text);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleVerseModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
