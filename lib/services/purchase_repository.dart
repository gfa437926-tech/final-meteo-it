import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase_record.dart';

class PurchaseRepository {
  PurchaseRepository({FirebaseFirestore? firestore})
      : db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get records =>
      db.collection('purchase_records');

  Stream<List<PurchaseRecord>> watch() =>
      records.orderBy('purchaseDate', descending: true).snapshots().map(
            (snapshot) => snapshot.docs
                .map((doc) => PurchaseRecord.fromMap(doc.id, doc.data()))
                .toList(),
          );

  Future<void> create(PurchaseRecord record) =>
      db.runTransaction((transaction) async {
        final assetRef = db.collection('assets').doc(record.assetId);
        final purchaseRef = records.doc(record.id);
        final assetSnapshot = await transaction.get(assetRef);
        final purchaseSnapshot = await transaction.get(purchaseRef);

        if (!assetSnapshot.exists) {
          throw StateError('الأصل المرتبط بفاتورة الشراء غير موجود');
        }
        if (purchaseSnapshot.exists) {
          throw StateError('معرّف سجل الشراء مستخدم مسبقاً');
        }
        if (record.supplier.trim().isEmpty) {
          throw ArgumentError('اسم المورد مطلوب');
        }
        if (!record.totalCost.isFinite || record.totalCost < 0) {
          throw ArgumentError('قيمة الشراء يجب أن تكون رقماً غير سالب');
        }
        if (record.warrantyUntil != null &&
            record.warrantyUntil!.isBefore(record.purchaseDate)) {
          throw ArgumentError('تاريخ انتهاء الضمان يسبق تاريخ الشراء');
        }

        final assetData = assetSnapshot.data()!;
        final label =
            '${assetData['brand'] ?? ''} ${assetData['model'] ?? ''}'.trim();
        final now = FieldValue.serverTimestamp();

        transaction.set(purchaseRef, {
          ...record.toMap(),
          'assetLabel': label,
          'createdAt': now,
        });

        final movement = db.collection('asset_movements').doc();
        transaction.set(movement, {
          'assetId': record.assetId,
          'assetLabel': label,
          'movementType': 'purchase_registered',
          'occurredAt': now,
          'purchaseId': record.id,
          'notes': 'تسجيل فاتورة شراء: ${record.invoiceNumber.trim()}',
        });
      });
}
