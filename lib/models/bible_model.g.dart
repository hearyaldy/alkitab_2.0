// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bible_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BibleBookAdapter extends TypeAdapter<BibleBook> {
  @override
  final int typeId = 0;

  @override
  BibleBook read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BibleBook(
      id: fields[0] as String,
      name: fields[1] as String,
      abbreviation: fields[2] as String,
      order: fields[3] as int,
      testament: fields[4] as String,
      chapters: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, BibleBook obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.abbreviation)
      ..writeByte(3)
      ..write(obj.order)
      ..writeByte(4)
      ..write(obj.testament)
      ..writeByte(5)
      ..write(obj.chapters);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleBookAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BibleVerseAdapter extends TypeAdapter<BibleVerse> {
  @override
  final int typeId = 1;

  @override
  BibleVerse read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BibleVerse(
      id: fields[0] as int,
      bookId: fields[1] as String,
      chapterId: fields[2] as int,
      verseNumber: fields[3] as int,
      text: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, BibleVerse obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.chapterId)
      ..writeByte(3)
      ..write(obj.verseNumber)
      ..writeByte(4)
      ..write(obj.text);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleVerseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BibleVersionAdapter extends TypeAdapter<BibleVersion> {
  @override
  final int typeId = 2;

  @override
  BibleVersion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BibleVersion(
      id: fields[0] as String,
      name: fields[1] as String,
      code: fields[2] as String,
      description: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BibleVersion obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.code)
      ..writeByte(3)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleVersionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
