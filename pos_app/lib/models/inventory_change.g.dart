part of 'inventory_change.dart';

class InventoryChangeAdapter extends TypeAdapter<InventoryChange> {
  @override
  final int typeId = 4;

  @override
  InventoryChange read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      fields[key] = reader.read();
    }
    return InventoryChange(
      id: fields[0] as String,
      productId: fields[1] as String,
      delta: fields[2] as int,
      reason: fields[3] as String,
      createdAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, InventoryChange obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productId)
      ..writeByte(2)
      ..write(obj.delta)
      ..writeByte(3)
      ..write(obj.reason)
      ..writeByte(4)
      ..write(obj.createdAt);
  }
}