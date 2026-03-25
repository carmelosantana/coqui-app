import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

class MaterialColorAdapter extends TypeAdapter<MaterialColor> {
  @override
  final typeId = 0;

  @override
  MaterialColor read(BinaryReader reader) {
    final colorValue = reader.readInt();
    return Colors.primaries.firstWhere(
      // Hive stores the ARGB32 int — compare using the same representation.
      // ignore: deprecated_member_use
      (color) => color.value == colorValue,
      orElse: () => Colors.grey,
    );
  }

  @override
  void write(BinaryWriter writer, MaterialColor obj) {
    writer.writeInt(obj.toARGB32());
  }
}
