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
}
