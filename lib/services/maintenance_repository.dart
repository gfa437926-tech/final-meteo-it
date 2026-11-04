import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/maintenance_record.dart';

class MaintenanceRepository {
  MaintenanceRepository({FirebaseFirestore? firestore}) : db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore db;
  CollectionReference<Map<String, dynamic>> get records => db.collection('maintenance_records');

  Stream<List<MaintenanceRecord>> watch() => records.orderBy('reportedAt', descending: true)
      .snapshots().map((s) => s.docs.map((d) => MaintenanceRecord.fromMap(d.id, d.data())).toList());

  Future<void> create(MaintenanceRecord record) => db.runTransaction((tx) async {
    final assetRef = db.collection('assets').doc(record.assetId);
    final asset = await tx.get(assetRef);
    if (!asset.exists) throw StateError('الأصل المحدد غير موجود');
    if (asset.data()?['status'] == 'retired') throw StateError('لا يمكن فتح صيانة لجهاز مستبعد');
    final previousStatus = asset.data()?['status'] as String? ?? 'available';
    tx.set(records.doc(record.id), {...record.toMap(), 'previousAssetStatus': previousStatus});
    tx.update(assetRef, {'status': 'maintenance'});
    final movement = db.collection('asset_movements').doc();
    tx.set(movement, {
      'assetId': record.assetId, 'assetLabel': record.assetLabel,
      'movementType': 'maintenance_opened', 'occurredAt': Timestamp.fromDate(record.reportedAt),
      'maintenanceId': record.id, 'notes': record.title,
    });
  });

  Future<void> complete(MaintenanceRecord record, {required String resolution, required double cost}) =>
      db.runTransaction((tx) async {
    final recordRef = records.doc(record.id);
    final recordSnap = await tx.get(recordRef);
    if (!recordSnap.exists) throw StateError('طلب الصيانة غير موجود');
    final data = recordSnap.data()!;
    if (data['status'] == 'completed' || data['status'] == 'cancelled') throw StateError('الطلب مغلق مسبقاً');
    final assetRef = db.collection('assets').doc(record.assetId);
    final assetSnap = await tx.get(assetRef);
    if (!assetSnap.exists) throw StateError('الجهاز المرتبط غير موجود');
    final previousStatus = data['previousAssetStatus'] as String? ?? 'available';
    tx.update(recordRef, {'status': MaintenanceStatus.completed.name, 'resolution': resolution.trim(), 'cost': cost, 'completedAt': Timestamp.now()});
    tx.update(assetRef, {'status': previousStatus});
    final movement = db.collection('asset_movements').doc();
    tx.set(movement, {'assetId': record.assetId, 'assetLabel': record.assetLabel, 'movementType': 'maintenance_completed', 'occurredAt': Timestamp.now(), 'maintenanceId': record.id, 'notes': resolution.trim(), 'cost': cost});
  });
}
