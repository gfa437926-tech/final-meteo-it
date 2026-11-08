import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase_record.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PurchaseRepository {
  PurchaseRepository({FirebaseFirestore? firestore})
      : db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get records =>
      db.collection('purchase_records');

  Future<List<String>> _activeAssignedOfficeIds(List<String> officeIds) async {
    if (officeIds.isEmpty) return const <String>[];
    final snapshot = await db
        .collection('offices')
        .where(FieldPath.documentId, whereIn: officeIds)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map((document) => document.id).toList();
  }

  Stream<List<PurchaseRecord>> watch() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const <PurchaseRecord>[]);
    return db.collection('users').doc(uid).snapshots().asyncExpand((profile) {
      final data = profile.data() ?? const <String, dynamic>{};
      if (data['isActive'] != true) {
        return Stream.value(const <PurchaseRecord>[]);
      }
      if (data['role'] == 'admin') {
        return records.orderBy('purchaseDate', descending: true)
            .snapshots()
            .map((snapshot) => snapshot.docs
                .map((doc) => PurchaseRecord.fromMap(doc.id, doc.data()))
                .toList());
      }
      final raw = data['officeIds'];
      final officeIds = raw is List
          ? raw.whereType<String>().toSet().toList()
          : <String>[];
      if (data['role'] != 'it_manager' || officeIds.isEmpty) {
        return Stream.value(const <PurchaseRecord>[]);
      }
      return Stream.fromFuture(_activeAssignedOfficeIds(officeIds))
          .asyncExpand((activeOfficeIds) {
        if (activeOfficeIds.isEmpty) {
          return Stream.value(const <PurchaseRecord>[]);
        }
        return records
            .where('officeId', whereIn: activeOfficeIds)
            .orderBy('purchaseDate', descending: true)
            .snapshots()
            .map((snapshot) => snapshot.docs
                .map((doc) => PurchaseRecord.fromMap(doc.id, doc.data()))
                .toList());
      });
    });
  }

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
        final officeId = assetData['officeId'] as String? ?? '';
        if (officeId.isEmpty) throw StateError('الأصل غير مرتبط بمكتب');
        final label =
            '${assetData['brand'] ?? ''} ${assetData['model'] ?? ''}'.trim();
        final now = FieldValue.serverTimestamp();

        transaction.set(purchaseRef, {
          ...record.toMap(),
          'officeId': officeId,
          'assetLabel': label,
          'createdAt': now,
        });

        final movement = db.collection('asset_movements').doc();
        transaction.set(movement, {
          'assetId': record.assetId,
          'officeId': officeId,
          'assetLabel': label,
          'movementType': 'purchase_registered',
          'occurredAt': now,
          'purchaseId': record.id,
          'notes': 'تسجيل فاتورة شراء: ${record.invoiceNumber.trim()}',
        });
      });
}
