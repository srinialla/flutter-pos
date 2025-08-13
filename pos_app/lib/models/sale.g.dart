part of 'sale.dart';

class SaleItemAdapter extends TypeAdapter<SaleItem> {
  @override
  final int typeId = 2;

  @override
  SaleItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      fields[key] = reader.read();
    }
    return SaleItem(
      productId: fields[0] as String,
      name: fields[1] as String,
      quantity: fields[2] as int,
      unitPrice: (fields[3] as num).toDouble(),
      discount: (fields[4] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, SaleItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.unitPrice)
      ..writeByte(4)
      ..write(obj.discount);
  }
}

class SaleAdapter extends TypeAdapter<Sale> {
  @override
  final int typeId = 3;

  @override
  Sale read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      fields[key] = reader.read();
    }
    return Sale(
      id: fields[0] as String,
      items: (fields[1] as List).cast<SaleItem>(),
      discount: (fields[2] as num).toDouble(),
      taxRatePercent: (fields[3] as num).toDouble(),
      cashPaid: (fields[4] as num).toDouble(),
      cardPaid: (fields[5] as num).toDouble(),
      mobileMoneyPaid: (fields[6] as num).toDouble(),
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Sale obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.items)
      ..writeByte(2)
      ..write(obj.discount)
      ..writeByte(3)
      ..write(obj.taxRatePercent)
      ..writeByte(4)
      ..write(obj.cashPaid)
      ..writeByte(5)
      ..write(obj.cardPaid)
      ..writeByte(6)
      ..write(obj.mobileMoneyPaid)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }
}