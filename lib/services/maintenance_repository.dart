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
    tx.set(records.doc(record.id), record.toMap());
    tx.update(assetRef, {'status': 'maintenance'});
    final movement = db.collection('asset_movements').doc();
    tx.set(movement, {
      'assetId': record.assetId, 'assetLabel': record.assetLabel,
      'movementType': 'maintenance_opened', 'occurredAt': Timestamp.fromDate(record.reportedAt),
      'maintenanceId': record.id, 'notes': record.title,
    });
  });
}
