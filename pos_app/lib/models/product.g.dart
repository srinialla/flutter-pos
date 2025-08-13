part of 'product.dart';

class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 1;

  @override
  Product read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      fields[key] = reader.read();
    }
    return Product(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      barcode: fields[3] as String?,
      price: (fields[4] as num).toDouble(),
      cost: (fields[5] as num?)?.toDouble(),
      category: fields[6] as String?,
      stockQuantity: fields[7] as int,
      imageBase64: fields[8] as String?,
      updatedAt: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.barcode)
      ..writeByte(4)
      ..write(obj.price)
      ..writeByte(5)
      ..write(obj.cost)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.stockQuantity)
      ..writeByte(8)
      ..write(obj.imageBase64)
      ..writeByte(9)
      ..write(obj.updatedAt);
  }
}