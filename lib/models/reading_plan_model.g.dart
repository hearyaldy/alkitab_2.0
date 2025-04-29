// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_plan_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReadingPlanModelAdapter extends TypeAdapter<ReadingPlanModel> {
  @override
  final int typeId = 5;

  @override
  ReadingPlanModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReadingPlanModel(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      durationDays: fields[3] as int,
      imageUrl: fields[4] as String?,
      days: (fields[5] as List).cast<ReadingPlanDayModel>(),
      isSynced: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ReadingPlanModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.durationDays)
      ..writeByte(4)
      ..write(obj.imageUrl)
      ..writeByte(5)
      ..write(obj.days)
      ..writeByte(6)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingPlanModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReadingPlanDayModelAdapter extends TypeAdapter<ReadingPlanDayModel> {
  @override
  final int typeId = 6;

  @override
  ReadingPlanDayModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReadingPlanDayModel(
      id: fields[0] as String,
      planId: fields[1] as String,
      dayNumber: fields[2] as int,
      scriptureReferences: (fields[3] as List).cast<String>(),
      title: fields[4] as String,
      description: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ReadingPlanDayModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.planId)
      ..writeByte(2)
      ..write(obj.dayNumber)
      ..writeByte(3)
      ..write(obj.scriptureReferences)
      ..writeByte(4)
      ..write(obj.title)
      ..writeByte(5)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingPlanDayModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserReadingPlanModelAdapter extends TypeAdapter<UserReadingPlanModel> {
  @override
  final int typeId = 7;

  @override
  UserReadingPlanModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserReadingPlanModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      readingPlanId: fields[2] as String,
      startDate: fields[3] as DateTime,
      currentDay: fields[4] as int,
      isCompleted: fields[5] as bool,
      completionDate: fields[6] as DateTime?,
      completedDays: (fields[7] as List).cast<int>(),
      isSynced: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, UserReadingPlanModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.readingPlanId)
      ..writeByte(3)
      ..write(obj.startDate)
      ..writeByte(4)
      ..write(obj.currentDay)
      ..writeByte(5)
      ..write(obj.isCompleted)
      ..writeByte(6)
      ..write(obj.completionDate)
      ..writeByte(7)
      ..write(obj.completedDays)
      ..writeByte(8)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserReadingPlanModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
