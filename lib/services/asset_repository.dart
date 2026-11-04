import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:metra_it_assets/models/asset.dart';

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

  Future<void> retireAsset(Asset asset, {String reason = ''}) =>
      _db.runTransaction((tx) async {
    final ref = _assets.doc(asset.id);
    final snap = await tx.get(ref);
    if (!snap.exists) throw StateError('الجهاز غير موجود');
    if (snap.data()?['status'] == AssetStatus.retired.name) {
      throw StateError('الجهاز مستبعد مسبقاً');
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
