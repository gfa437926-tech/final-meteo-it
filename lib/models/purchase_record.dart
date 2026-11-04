import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseRecord {
  const PurchaseRecord({
    required this.id,
    required this.assetId,
    required this.assetLabel,
    required this.supplier,
    required this.invoiceNumber,
    required this.purchaseDate,
    required this.totalCost,
    this.warrantyUntil,
    this.notes = '',
  });

  final String id;
  final String assetId;
  final String assetLabel;
  final String supplier;
  final String invoiceNumber;
  final DateTime purchaseDate;
  final DateTime? warrantyUntil;
  final double totalCost;
  final String notes;

  Map<String, Object?> toMap() => {
        'assetId': assetId,
        'assetLabel': assetLabel,
        'supplier': supplier.trim(),
        'invoiceNumber': invoiceNumber.trim(),
        'purchaseDate': Timestamp.fromDate(purchaseDate),
        'warrantyUntil':
            warrantyUntil == null ? null : Timestamp.fromDate(warrantyUntil!),
        'totalCost': totalCost,
        'notes': notes.trim(),
      };

  factory PurchaseRecord.fromMap(String id, Map<String, dynamic> map) =>
      PurchaseRecord(
        id: id,
        assetId: map['assetId'] as String? ?? '',
        assetLabel: map['assetLabel'] as String? ?? '',
        supplier: map['supplier'] as String? ?? '',
        invoiceNumber: map['invoiceNumber'] as String? ?? '',
        purchaseDate:
            (map['purchaseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        warrantyUntil: (map['warrantyUntil'] as Timestamp?)?.toDate(),
        totalCost: (map['totalCost'] as num?)?.toDouble() ?? 0,
        notes: map['notes'] as String? ?? '',
      );
}
