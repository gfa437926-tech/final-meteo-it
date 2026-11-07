import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      watchAssetDocuments({String? status, List<String>? statuses}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Stream.value(
        const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
      );
    }
    return Stream.fromFuture(_db.collection('users').doc(uid).get())
        .asyncExpand((profile) {
      final data = profile.data() ?? const <String, dynamic>{};
      if (data['isActive'] != true) {
        return Stream.value(
          const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        );
      }
      if (data['role'] == 'admin') {
        return _assets.snapshots().map((snapshot) => _filterAssetDocuments(
              snapshot.docs, status: status, statuses: statuses));
      }
      final rawOfficeIds = data['officeIds'];
      final officeIds = rawOfficeIds is List
          ? rawOfficeIds.whereType<String>().toSet().toList()
          : <String>[];
      if (data['role'] != 'it_manager' || officeIds.isEmpty) {
        return Stream.value(
          const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        );
      }
      // The query itself is office constrained; client-side filtering alone
      // would still request records outside the caller's authorization scope.
      return _assets
          .where('officeId', whereIn: officeIds)
          .snapshots()
          .map((snapshot) => _filterAssetDocuments(
                snapshot.docs, status: status, statuses: statuses));
    });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterAssetDocuments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents, {
    String? status,
    List<String>? statuses,
  }) {
    final filtered = documents.where((document) {
      final value = document.data()['status'];
      if (status != null) return value == status;
      if (statuses != null && statuses.isNotEmpty) return statuses.contains(value);
      return true;
    }).toList()
      ..sort((a, b) => ((a.data()['brand'] as String?) ?? '')
          .compareTo((b.data()['brand'] as String?) ?? ''));
    return filtered;
  }

  Stream<List<Asset>> watchAssets() => watchAssetDocuments().map(
        (documents) => documents
            .map((document) => Asset.fromMap(document.id, document.data()))
            .toList(),
      );

  Future<void> createAsset(Asset asset) async {
    final serial = _normalizeSerial(asset.serialNumber);
    final assetRef = _assets.doc(asset.id);
    final assetData = asset.toMap()..['serialNumber'] = serial;
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
          'officeId': asset.officeId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> updateAsset(Asset asset) async {
    final assetRef = _assets.doc(asset.id);
    final newSerial = _normalizeSerial(asset.serialNumber);
    final assetData = asset.toMap()..['serialNumber'] = newSerial;
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
          'officeId': asset.officeId,
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
        final serial = _normalizeSerial(data['serialNumber'] as String? ?? '');
        DocumentReference<Map<String, dynamic>>? serialRef;
        DocumentSnapshot<Map<String, dynamic>>? serialSnapshot;
        if (serial.isNotEmpty) {
          serialRef = _serialRef(serial);
          serialSnapshot = await tx.get(serialRef);
        }
        // All transaction reads are completed before the first write.
        tx.update(assetRef, {
          'officeId': destination.id,
          'officeName': officeName,
          'transferredAt': FieldValue.serverTimestamp(),
        });
        if (serialRef != null && serialSnapshot!.exists) {
          tx.update(serialRef, {'officeId': destination.id});
        }
        final movement = _db.collection('asset_movements').doc();
        tx.set(movement, {
          'assetId': asset.id,
          'assetLabel': '${data['brand'] ?? ''} ${data['model'] ?? ''}'.trim(),
          'officeId': destination.id,
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
          'officeId': snap.data()?['officeId'],
          'movementType': 'retired',
          'occurredAt': FieldValue.serverTimestamp(),
          'notes': reason.trim(),
        });
      });
}
