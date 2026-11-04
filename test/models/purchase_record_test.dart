import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra_it_assets/models/purchase_record.dart';

void main() {
  test('purchase record serializes invoice, amount, and warranty dates', () {
    final purchaseDate = DateTime(2026, 5, 12);
    final warrantyDate = DateTime(2028, 5, 12);
    final record = PurchaseRecord(
      id: 'purchase-001',
      assetId: 'asset-001',
      assetLabel: 'Dell OptiPlex',
      supplier: 'Example Supplier',
      invoiceNumber: 'INV-2026-001',
      purchaseDate: DateTime(2026, 5, 12),
      totalCost: 1250.50,
      warrantyUntil: DateTime(2028, 5, 12),
      notes: 'Initial purchase',
    );

    final map = record.toMap();
    expect(map['assetId'], 'asset-001');
    expect(map['supplier'], 'Example Supplier');
    expect(map['invoiceNumber'], 'INV-2026-001');
    expect((map['purchaseDate'] as Timestamp).toDate(), purchaseDate);
    expect((map['warrantyUntil'] as Timestamp).toDate(), warrantyDate);
    expect(map['totalCost'], 1250.50);

    final restored = PurchaseRecord.fromMap('purchase-001', map);
    expect(restored.id, record.id);
    expect(restored.assetLabel, record.assetLabel);
    expect(restored.purchaseDate, purchaseDate);
    expect(restored.warrantyUntil, warrantyDate);
    expect(restored.totalCost, 1250.50);
  });

  test('purchase record supports purchases without warranty dates', () {
    final record = PurchaseRecord(
      id: 'purchase-002',
      assetId: 'asset-002',
      assetLabel: 'Network Switch',
      supplier: 'Supplier',
      invoiceNumber: '',
      purchaseDate: DateTime(2026, 7, 1),
      totalCost: 300,
    );

    final map = record.toMap();
    expect(map['warrantyUntil'], isNull);
    final restored = PurchaseRecord.fromMap('purchase-002', map);
    expect(restored.warrantyUntil, isNull);
    expect(restored.totalCost, 300);
  });
}
