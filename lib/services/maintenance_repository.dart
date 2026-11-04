import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/maintenance_record.dart';

class MaintenanceRepository {
  MaintenanceRepository({FirebaseFirestore? firestore})
      : db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get records =>
      db.collection('maintenance_records');

  Stream<List<MaintenanceRecord>> watch() =>
      records.orderBy('reportedAt', descending: true).snapshots().map(
            (snapshot) => snapshot.docs
                .map((doc) => MaintenanceRecord.fromMap(doc.id, doc.data()))
                .toList(),
          );

  Future<void> create(MaintenanceRecord record) =>
      db.runTransaction((transaction) async {
        final assetRef = db.collection('assets').doc(record.assetId);
        final recordRef = records.doc(record.id);
        final assetSnapshot = await transaction.get(assetRef);
        final recordSnapshot = await transaction.get(recordRef);

        if (!assetSnapshot.exists) {
          throw StateError('الأصل المحدد غير موجود');
        }
        if (recordSnapshot.exists) {
          throw StateError('رقم طلب الصيانة مستخدم مسبقاً');
        }

        final assetData = assetSnapshot.data()!;
        final previousStatus =
            assetData['status'] as String? ?? 'available';
        if (previousStatus == 'retired') {
          throw StateError('لا يمكن فتح صيانة لجهاز مستبعد');
        }
        if (previousStatus == 'assigned' || previousStatus == 'maintenance') {
          throw StateError(
            'لا يمكن فتح طلب صيانة لجهاز بعهدة موظف أو قيد الصيانة بالفعل',
          );
        }
        if (previousStatus != 'available' &&
            previousStatus != 'damaged' &&
            previousStatus != 'returned') {
          throw StateError('حالة الجهاز لا تسمح بفتح طلب صيانة');
        }

        final brand = assetData['brand'] as String? ?? '';
        final model = assetData['model'] as String? ?? '';
        final canonicalLabel = '$brand $model'.trim();
        final now = FieldValue.serverTimestamp();

        transaction.set(recordRef, {
          ...record.toMap(),
          'assetLabel': canonicalLabel,
          'reportedAt': now,
          'previousAssetStatus': previousStatus,
          'status': MaintenanceStatus.open.name,
        });
        transaction.update(assetRef, {'status': 'maintenance'});

        final movement = db.collection('asset_movements').doc();
        transaction.set(movement, {
          'assetId': record.assetId,
          'assetLabel': canonicalLabel,
          'movementType': 'maintenance_opened',
          'occurredAt': now,
          'maintenanceId': record.id,
          'notes': record.title.trim(),
        });
      });

  Future<void> complete(
    MaintenanceRecord record, {
    required String resolution,
    required double cost,
  }) =>
      db.runTransaction((transaction) async {
        final recordRef = records.doc(record.id);
        final recordSnapshot = await transaction.get(recordRef);
        if (!recordSnapshot.exists) {
          throw StateError('طلب الصيانة غير موجود');
        }

        final data = recordSnapshot.data()!;
        final status = data['status'] as String? ?? 'open';
        if (status == 'completed' || status == 'cancelled') {
          throw StateError('الطلب مغلق مسبقاً');
        }
        if (resolution.trim().isEmpty || !cost.isFinite || cost < 0) {
          throw ArgumentError('الحل مطلوب والتكلفة يجب أن تكون رقماً غير سالب');
        }

        final assetId = data['assetId'] as String? ?? '';
        if (assetId.isEmpty) {
          throw StateError('طلب الصيانة لا يحتوي على معرّف أصل صالح');
        }
        final assetRef = db.collection('assets').doc(assetId);
        final assetSnapshot = await transaction.get(assetRef);
        if (!assetSnapshot.exists) {
          throw StateError('الجهاز المرتبط غير موجود');
        }
        final assetData = assetSnapshot.data()!;
        if (assetData['status'] != 'maintenance') {
          throw StateError('حالة الجهاز تغيرت ولا يمكن إغلاق الطلب بأمان');
        }

        final previousStatus =
            data['previousAssetStatus'] as String? ?? 'available';
        final assetLabel = data['assetLabel'] as String? ?? '';
        final now = FieldValue.serverTimestamp();

        transaction.update(recordRef, {
          'status': MaintenanceStatus.completed.name,
          'resolution': resolution.trim(),
          'cost': cost,
          'completedAt': now,
        });
        transaction.update(assetRef, {'status': previousStatus});

        final movement = db.collection('asset_movements').doc();
        transaction.set(movement, {
          'assetId': assetId,
          'assetLabel': assetLabel,
          'movementType': 'maintenance_completed',
          'occurredAt': now,
          'maintenanceId': record.id,
          'notes': resolution.trim(),
          'cost': cost,
        });
      });
}
