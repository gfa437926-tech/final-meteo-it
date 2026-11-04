import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:metra_it_assets/models/asset.dart';
import 'package:metra_it_assets/models/office.dart';

class AssetRepository {
  AssetRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>> get _assets => _db.collection('assets');

  Stream<List<Asset>> watchAssets() => _assets.orderBy('brand').snapshots().map((snapshot) =>
    snapshot.docs.map((doc) => Asset.fromMap(doc.id, doc.data())).toList());

  Future<void> createAsset(Asset asset) async {
    final serial = asset.serialNumber.trim();
    if (serial.isNotEmpty) {
      final duplicate = await _assets.where('serialNumber', isEqualTo: serial).limit(1).get();
      if (duplicate.docs.isNotEmpty) throw StateError('الرقم التسلسلي مسجل مسبقاً');
    }
    await _assets.doc(asset.id).set(asset.toMap());
  }
  Future<void> updateAsset(Asset asset) async {
    final serial = asset.serialNumber.trim();
    if (serial.isNotEmpty) {
      final duplicate = await _assets.where('serialNumber', isEqualTo: serial).limit(2).get();
      if (duplicate.docs.any((doc) => doc.id != asset.id)) {
        throw StateError('الرقم التسلسلي مسجل لجهاز آخر');
      }
    }
    await _assets.doc(asset.id).update(asset.toMap());
  }

  Future<void> transferAsset(Asset asset, Office destination, {String notes = ''}) =>
      _db.runTransaction((tx) async {
    final assetRef = _assets.doc(asset.id);
    final officeRef = _db.collection('offices').doc(destination.id);
    final assetSnap = await tx.get(assetRef);
    final officeSnap = await tx.get(officeRef);
    if (!assetSnap.exists) throw StateError('الجهاز غير موجود');
    if (!officeSnap.exists || officeSnap.data()?['isActive'] == false) {
      throw StateError('المكتب الوجهة غير موجود أو غير فعال');
    }
    final officeName = officeSnap.data()?['name'] as String? ?? '';
    if (officeName.trim().isEmpty) throw StateError('اسم المكتب الوجهة غير صالح');
    final data = assetSnap.data()!;
    final status = data['status'] as String? ?? AssetStatus.available.name;
    if (status != AssetStatus.available.name && status != AssetStatus.returned.name) {
      throw StateError('لا يمكن نقل الجهاز إلا إذا كان متاحاً وغير مرتبط بعهدة أو صيانة');
    }
    final fromOfficeId = data['officeId'] as String? ?? '';
    final fromOfficeName = data['officeName'] as String? ?? 'غير محدد';
    if (fromOfficeId == destination.id) throw StateError('الجهاز موجود بالفعل في المكتب المحدد');
    tx.update(assetRef, {
      'officeId': destination.id,
      'officeName': officeName,
      'transferredAt': FieldValue.serverTimestamp(),
    });
    final movement = _db.collection('asset_movements').doc();
    tx.set(movement, {
      'assetId': asset.id,
      'assetLabel': '${data['brand'] ?? ''} ${data['model'] ?? ''}'.trim(),
      'movementType': 'transferred',
      'occurredAt': FieldValue.serverTimestamp(),
      'fromOfficeId': fromOfficeId,
      'fromOfficeName': fromOfficeName,
      'toOfficeId': destination.id,
      'toOfficeName': officeName,
      'notes': notes.trim(),
    });
  });

  Future<void> retireAsset(Asset asset, {String reason = ''}) =>
      _db.runTransaction((tx) async {
    final ref = _assets.doc(asset.id);
    final snap = await tx.get(ref);
    if (!snap.exists) throw StateError('الجهاز غير موجود');
    final currentStatus = snap.data()?['status'] as String? ?? AssetStatus.available.name;
    if (currentStatus == AssetStatus.retired.name) throw StateError('الجهاز مستبعد مسبقاً');
    if (currentStatus == AssetStatus.assigned.name || currentStatus == AssetStatus.maintenance.name) {
      throw StateError('يجب إغلاق العهدة أو طلب الصيانة قبل استبعاد الجهاز');
    }
    tx.update(ref, {'status': AssetStatus.retired.name, 'retiredAt': FieldValue.serverTimestamp(), 'retirementReason': reason.trim()});
    final movement = _db.collection('asset_movements').doc();
    tx.set(movement, {
      'assetId': asset.id, 'assetLabel': '${asset.brand} ${asset.model}',
      'movementType': 'retired', 'occurredAt': FieldValue.serverTimestamp(),
      'notes': reason.trim(),
    });
  });
}
