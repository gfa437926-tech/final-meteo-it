import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:metra_it_assets/models/asset.dart';
import 'package:metra_it_assets/models/office.dart';

class AssetRepository {
  AssetRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _assets =>
      _db.collection('assets');

  CollectionReference<Map<String, dynamic>> get _serials =>
      _db.collection('asset_serials');

  String _normalizeSerial(String serial) => serial.trim().toUpperCase();

  DocumentReference<Map<String, dynamic>> _serialRef(String serial) {
    final encoded = base64Url
        .encode(utf8.encode(_normalizeSerial(serial)))
        .replaceAll('=', '');
    return _serials.doc(encoded);
  }

  Stream<List<Asset>> watchAssets() =>
      _assets.orderBy('brand').snapshots().map((snapshot) =>
          snapshot.docs.map((doc) => Asset.fromMap(doc.id, doc.data())).toList());

  Future<void> createAsset(Asset asset) async {
    final serial = _normalizeSerial(asset.serialNumber);
    final assetRef = _assets.doc(asset.id);
    final assetData = asset.toMap()..['serialNumber'] = serial;
    if (serial.isNotEmpty) {
      final existingAssets = await _assets.get();
      final duplicate = existingAssets.docs.any((doc) =>
          _normalizeSerial(doc.data()['serialNumber'] as String? ?? '') ==
          serial);
      if (duplicate) throw StateError('الرقم التسلسلي مسجل مسبقاً');
    }
    await _db.runTransaction((tx) async {
      final assetSnapshot = await tx.get(assetRef);
      if (assetSnapshot.exists) {
        throw StateError('معرّف الأصل مستخدم مسبقاً');
      }

      DocumentReference<Map<String, dynamic>>? serialRef;
      if (serial.isNotEmpty) {
        serialRef = _serialRef(serial);
        final serialSnapshot = await tx.get(serialRef);
        if (serialSnapshot.exists) {
          throw StateError('الرقم التسلسلي مسجل مسبقاً');
        }
      }

      tx.set(assetRef, assetData);
      if (serialRef != null) {
        tx.set(serialRef, {
          'assetId': asset.id,
          'serialNumber': serial,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> updateAsset(Asset asset) async {
    final assetRef = _assets.doc(asset.id);
    final newSerial = _normalizeSerial(asset.serialNumber);
    final assetData = asset.toMap()..['serialNumber'] = newSerial;
    if (newSerial.isNotEmpty) {
      final existingAssets = await _assets.get();
      final duplicate = existingAssets.docs.any((doc) =>
          doc.id != asset.id &&
          _normalizeSerial(doc.data()['serialNumber'] as String? ?? '') ==
              newSerial);
      if (duplicate) throw StateError('الرقم التسلسلي مسجل لجهاز آخر');
    }

    await _db.runTransaction((tx) async {
      final assetSnapshot = await tx.get(assetRef);
      if (!assetSnapshot.exists) {
        throw StateError('الجهاز المراد تعديله غير موجود');
      }

      final oldSerial = _normalizeSerial(
        assetSnapshot.data()?['serialNumber'] as String? ?? '',
      );
      final serialChanged = oldSerial != newSerial;

      DocumentReference<Map<String, dynamic>>? oldSerialRef;
      DocumentReference<Map<String, dynamic>>? newSerialRef;
      DocumentSnapshot<Map<String, dynamic>>? oldSerialSnapshot;
      DocumentSnapshot<Map<String, dynamic>>? newSerialSnapshot;

      if (oldSerial.isNotEmpty && serialChanged) {
        oldSerialRef = _serialRef(oldSerial);
        oldSerialSnapshot = await tx.get(oldSerialRef);
      }

      if (newSerial.isNotEmpty) {
        newSerialRef = _serialRef(newSerial);
        newSerialSnapshot = await tx.get(newSerialRef);
        final reservedAssetId =
            newSerialSnapshot.data()?['assetId'] as String?;
        if (newSerialSnapshot.exists && reservedAssetId != asset.id) {
          throw StateError('الرقم التسلسلي مسجل لجهاز آخر');
        }
      }

      tx.update(assetRef, assetData);

      if (serialChanged && oldSerialRef != null &&
          oldSerialSnapshot?.data()?['assetId'] == asset.id) {
        tx.delete(oldSerialRef);
      }
      if (newSerialRef != null && !newSerialSnapshot!.exists) {
        tx.set(newSerialRef, {
          'assetId': asset.id,
          'serialNumber': newSerial,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> transferAsset(
    Asset asset,
    Office destination, {
    String notes = '',
  }) =>
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
        if (officeName.trim().isEmpty) {
          throw StateError('اسم المكتب الوجهة غير صالح');
        }
        final data = assetSnap.data()!;
        final status =
            data['status'] as String? ?? AssetStatus.available.name;
        if (status != AssetStatus.available.name &&
            status != AssetStatus.returned.name) {
          throw StateError(
            'لا يمكن نقل الجهاز إلا إذا كان متاحاً وغير مرتبط بعهدة أو صيانة',
          );
        }
        final fromOfficeId = data['officeId'] as String? ?? '';
        final fromOfficeName = data['officeName'] as String? ?? 'غير محدد';
        if (fromOfficeId == destination.id) {
          throw StateError('الجهاز موجود بالفعل في المكتب المحدد');
        }
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
        final currentStatus =
            snap.data()?['status'] as String? ?? AssetStatus.available.name;
        if (currentStatus == AssetStatus.retired.name) {
          throw StateError('الجهاز مستبعد مسبقاً');
        }
        if (currentStatus == AssetStatus.assigned.name ||
            currentStatus == AssetStatus.maintenance.name) {
          throw StateError(
            'يجب إغلاق العهدة أو طلب الصيانة قبل استبعاد الجهاز',
          );
        }
        tx.update(ref, {
          'status': AssetStatus.retired.name,
          'retiredAt': FieldValue.serverTimestamp(),
          'retirementReason': reason.trim(),
        });
        final movement = _db.collection('asset_movements').doc();
        tx.set(movement, {
          'assetId': asset.id,
          'assetLabel': '${asset.brand} ${asset.model}',
          'movementType': 'retired',
          'occurredAt': FieldValue.serverTimestamp(),
          'notes': reason.trim(),
        });
      });
}
