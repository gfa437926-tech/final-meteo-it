import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SparePartsRepository {
  SparePartsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore db;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get parts =>
      db.collection('spare_parts');

  CollectionReference<Map<String, dynamic>> get _tickets =>
      db.collection('maintenance_records');

  /// null means global administrator; an empty list means no active office.
  Stream<List<String>?> _activeOfficeScope() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const <String>[]);
    return db.collection('users').doc(uid).snapshots().asyncExpand((profile) {
      final data = profile.data() ?? const <String, dynamic>{};
      if (data['isActive'] != true) return Stream.value(const <String>[]);
      if (data['role'] == 'admin') return Stream.value(null);
      final raw = data['officeIds'];
      final assigned = raw is List
          ? raw.whereType<String>().toSet().toList()
          : <String>[];
      if (data['role'] != 'it_manager' || assigned.isEmpty) {
        return Stream.value(const <String>[]);
      }
      return db.collection('offices')
          .where(FieldPath.documentId, whereIn: assigned)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchParts() =>
      _activeOfficeScope().asyncExpand((officeIds) {
        if (officeIds == null) return parts.orderBy('name').snapshots();
        if (officeIds.isEmpty) {
          return parts.where('officeId', isEqualTo: '__no_active_office__')
              .snapshots();
        }
        return parts.where('officeId', whereIn: officeIds)
            .orderBy('name').snapshots();
      });

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOpenTickets() =>
      _activeOfficeScope().asyncExpand((officeIds) {
        if (officeIds == null) {
          return _tickets.where('status', whereIn: ['open', 'inProgress'])
              .snapshots();
        }
        if (officeIds.isEmpty) {
          return _tickets.where('officeId', isEqualTo: '__no_active_office__')
              .snapshots();
        }
        // Filter open status in the UI after the office-scoped query. Combining
        // two whereIn filters can exceed Firestore's 30-disjunction limit when
        // a manager has multiple assigned offices.
        return _tickets.where('officeId', whereIn: officeIds).snapshots();
      });


  /// Loads an office-authorized, read-only report assembled from immutable
  /// receipt and issue events. Supplier attribution applies to receipts only:
  /// issue events do not retain lot-level supplier provenance.
  Future<List<Map<String, dynamic>>> loadMovementReport({
    required DateTime start,
    required DateTime endExclusive,
    String? officeId,
  }) async {
    if (!endExclusive.isAfter(start)) {
      throw ArgumentError('نهاية الفترة يجب أن تكون بعد بدايتها');
    }
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('يجب تسجيل الدخول أولاً');
    final profile = await db.collection('users').doc(uid).get();
    final user = profile.data() ?? const <String, dynamic>{};
    if (user['isActive'] != true) throw StateError('الحساب غير نشط');

    List<String>? allowedOffices;
    if (user['role'] != 'admin') {
      final raw = user['officeIds'];
      final assigned = raw is List
          ? raw.whereType<String>().toSet().toList()
          : <String>[];
      if (user['role'] != 'it_manager' || assigned.isEmpty) {
        throw StateError('لا توجد مكاتب مخولة للتقرير');
      }
      allowedOffices = <String>[];
      for (var offset = 0; offset < assigned.length; offset += 30) {
        final officeBatch = assigned.skip(offset).take(30).toList();
        final active = await db.collection('offices')
            .where(FieldPath.documentId, whereIn: officeBatch)
            .where('isActive', isEqualTo: true).get();
        allowedOffices.addAll(active.docs.map((doc) => doc.id));
      }
    }

    if (officeId != null && officeId.isNotEmpty &&
        allowedOffices != null && !allowedOffices.contains(officeId)) {
      throw StateError('لا تملك صلاحية الاطلاع على هذا المكتب');
    }
    if (allowedOffices != null && allowedOffices.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final officeIdsToRead = officeId != null && officeId.isNotEmpty
        ? <String>[officeId]
        : allowedOffices;
    final events = <Map<String, dynamic>>[];
    final startStamp = Timestamp.fromDate(start);
    final endStamp = Timestamp.fromDate(endExclusive);

    Future<void> appendCollection({
      required String collection,
      required String kind,
      required String dateField,
      required bool incoming,
      String? office,
    }) async {
      Query<Map<String, dynamic>> query = db.collection(collection)
          .where(dateField, isGreaterThanOrEqualTo: startStamp)
          .where(dateField, isLessThan: endStamp)
          .orderBy(dateField)
          .limit(500);
      if (office != null) {
        query = query.where('officeId', isEqualTo: office);
      }

      DocumentSnapshot<Map<String, dynamic>>? cursor;
      while (true) {
        final pageQuery = cursor == null ? query : query.startAfterDocument(cursor);
        final page = await pageQuery.get();
        final allocationSnapshots =
            <String, DocumentSnapshot<Map<String, dynamic>>>{};
        if (!incoming) {
          final trackedDocs = page.docs.where((doc) {
            final allocationId = doc.data()['allocationId'];
            return allocationId is String && allocationId.isNotEmpty;
          }).toList();
          for (var offset = 0; offset < trackedDocs.length; offset += 30) {
            final batch = trackedDocs.skip(offset).take(30);
            final snapshots = await Future.wait(batch.map((doc) =>
                db.collection('spare_part_allocations')
                    .doc(doc.data()['allocationId'] as String).get()));
            for (var index = 0; index < snapshots.length; index++) {
              allocationSnapshots[batch.elementAt(index).id] = snapshots[index];
            }
          }
        }
        for (final doc in page.docs) {
          final data = doc.data();
          final allocationData = incoming
              ? null
              : allocationSnapshots[doc.id]?.data();
          final rawDate = data[dateField];
          final eventDate = rawDate is Timestamp ? rawDate.toDate() :
              rawDate is DateTime ? rawDate : null;
          if (eventDate == null) continue;
          events.add({
            ...data,
            'eventId': doc.id,
            'kind': kind,
            'eventAt': eventDate,
            'quantity': (data['quantity'] as num?)?.toInt() ?? 0,
            'totalCost': (data['totalCost'] as num?)?.toDouble() ?? 0,
            'isIncoming': incoming,
            'allocationLines': allocationData?['lines'] is List
                ? allocationData!['lines'] as List
                : const <dynamic>[],
            'costAttributionComplete': data['costAttributionComplete'] == true,
          });
        }
        if (page.docs.length < 500) break;
        cursor = page.docs.last;
      }
    }

    final officesToQuery = officeIdsToRead;
    if (officesToQuery == null) {
      await Future.wait([
        appendCollection(collection: 'spare_part_receipts', kind: 'توريد',
            dateField: 'receivedAt', incoming: true),
        appendCollection(collection: 'maintenance_parts', kind: 'صرف',
            dateField: 'usedAt', incoming: false),
      ]);
    } else {
      for (final office in officesToQuery) {
        await Future.wait([
          appendCollection(collection: 'spare_part_receipts', kind: 'توريد',
              dateField: 'receivedAt', incoming: true, office: office),
          appendCollection(collection: 'maintenance_parts', kind: 'صرف',
              dateField: 'usedAt', incoming: false, office: office),
        ]);
      }
    }
    events.sort((a, b) =>
        (b['eventAt'] as DateTime).compareTo(a['eventAt'] as DateTime));
    return events;
  }

  Future<void> _assertOfficeAssignment(String officeId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('يجب تسجيل الدخول أولاً');
    final profile = await db.collection('users').doc(uid).get();
    final user = profile.data() ?? const <String, dynamic>{};
    final office = await db.collection('offices').doc(officeId).get();
    if (user['isActive'] != true || !office.exists ||
        office.data()?['isActive'] != true) {
      throw StateError('المكتب غير نشط أو غير متاح');
    }
    final allowed = user['role'] == 'admin' ||
        (user['role'] == 'it_manager' &&
         (user['officeIds'] as List?)?.contains(officeId) == true);
    if (!allowed) throw StateError('لا تملك صلاحية إدارة مخزون هذا المكتب');
  }

  Future<void> addPart({
    required String id,
    required String officeId,
    required String name,
    required String sku,
    required int quantity,
    required int minimumQuantity,
    required double unitCost,
    required String supplier,
  }) async {
    final cleanName = name.trim();
    final cleanSku = sku.trim().toUpperCase();
    if (officeId.trim().isEmpty || cleanName.isEmpty || cleanSku.isEmpty ||
        quantity < 0 || minimumQuantity < 0 ||
        !unitCost.isFinite || unitCost < 0) {
      throw ArgumentError('تحقق من المكتب واسم القطعة ورمزها والكميات والتكلفة');
    }
    await _assertOfficeAssignment(officeId);
    final ref = parts.doc(id);
    await db.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) throw StateError('معرّف القطعة مستخدم مسبقاً');
      transaction.set(ref, {
        'officeId': officeId,
        'name': cleanName,
        'sku': cleanSku,
        'quantity': quantity,
        // Opening stock has no verifiable receipt, so retain it as untracked.
        'untrackedQuantity': quantity,
        'minimumQuantity': minimumQuantity,
        'unitCost': unitCost,
        'supplier': supplier.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }


  /// Atomically increases stock, appends its receipt, and creates a FIFO lot.
  /// Existing stock without lot provenance remains untracked and is not assigned
  /// a supplier or purchase cost by this operation.
  Future<void> restock({
    required String partId,
    required int quantity,
    required double unitCost,
    required String supplier,
    required String notes,
    required DateTime receivedAt,
  }) async {
    final cleanSupplier = supplier.trim();
    if (quantity <= 0 || !unitCost.isFinite || unitCost < 0 ||
        cleanSupplier.isEmpty) {
      throw ArgumentError('أدخل كمية موجبة وتكلفة صحيحة واسم المورد');
    }
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('يجب تسجيل الدخول أولاً');
    final partRef = parts.doc(partId);
    final receiptRef = db.collection('spare_part_receipts').doc();
    final lotRef = db.collection('spare_part_lots').doc(receiptRef.id);
    final balanceRef = db.collection('spare_part_lot_balances').doc(receiptRef.id);
    await db.runTransaction((transaction) async {
      final partSnapshot = await transaction.get(partRef);
      if (!partSnapshot.exists) throw StateError('قطعة الغيار غير موجودة');
      final part = partSnapshot.data()!;
      final officeId = part['officeId'] as String? ?? '';
      if (officeId.isEmpty) {
        throw StateError('لا يمكن إعادة توريد سجل مخزون تاريخي بلا مكتب');
      }
      final officeRef = db.collection('offices').doc(officeId);
      final officeSnapshot = await transaction.get(officeRef);
      if (!officeSnapshot.exists || officeSnapshot.data()?['isActive'] != true) {
        throw StateError('المكتب غير موجود أو غير نشط');
      }
      final currentQuantity = part['quantity'] is int
          ? part['quantity'] as int
          : -1;
      final currentUnitCost = (part['unitCost'] as num?)?.toDouble() ?? double.nan;
      if (currentQuantity < 0 || !currentUnitCost.isFinite ||
          currentUnitCost < 0) {
        throw StateError('بيانات رصيد أو تكلفة المخزون غير صالحة');
      }
      final rawUntracked = part['untrackedQuantity'];
      final untrackedQuantity = rawUntracked == null
          ? currentQuantity
          : rawUntracked is int
              ? rawUntracked
              : -1;
      if (untrackedQuantity < 0 || untrackedQuantity > currentQuantity) {
        throw StateError('رصيد المخزون التاريخي غير صالح');
      }
      final newQuantity = currentQuantity + quantity;
      if (newQuantity < currentQuantity) {
        throw StateError('تجاوز الحد المسموح لكمية المخزون');
      }
      final totalCost = quantity * unitCost;
      if (!totalCost.isFinite) {
        throw ArgumentError('إجمالي تكلفة التوريد يتجاوز النطاق الرقمي المسموح');
      }
      final now = FieldValue.serverTimestamp();
      transaction.update(partRef, {
        'quantity': newQuantity,
        'untrackedQuantity': untrackedQuantity,
        'unitCost': unitCost,
        'supplier': cleanSupplier,
        'lastRestockId': receiptRef.id,
        'updatedAt': now,
      });
      transaction.set(receiptRef, {
        'partId': partId,
        'officeId': officeId,
        'lotId': lotRef.id,
        'quantity': quantity,
        'quantityBefore': currentQuantity,
        'quantityAfter': newQuantity,
        'unitCost': unitCost,
        'totalCost': totalCost,
        'supplier': cleanSupplier,
        'notes': notes.trim(),
        'receivedAt': Timestamp.fromDate(receivedAt),
        'createdAt': now,
        'createdBy': uid,
      });
      transaction.set(lotRef, {
        'partId': partId,
        'officeId': officeId,
        'receiptId': receiptRef.id,
        'supplier': cleanSupplier,
        'receivedQuantity': quantity,
        'unitCost': unitCost,
        'totalCost': totalCost,
        'receivedAt': Timestamp.fromDate(receivedAt),
        'createdAt': now,
        'createdBy': uid,
      });
      transaction.set(balanceRef, {
        'lotId': lotRef.id,
        'partId': partId,
        'officeId': officeId,
        'remainingQuantity': quantity,
        'createdAt': now,
        'updatedAt': now,
        'lastAllocationId': null,
      });
    });
  }

  /// Stock consumption is performed by a trusted callable transaction.
  /// The client never chooses a lot or writes stock/allocation records directly.
  Future<void> consume({
    required String partId,
    required String maintenanceId,
    required int quantity,
    required String notes,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('الكمية يجب أن تكون أكبر من صفر');
    }
    if (_auth.currentUser == null) {
      throw StateError('يجب تسجيل الدخول أولاً');
    }
    try {
      await _functions.httpsCallable('consumeSparePart').call({
        'partId': partId,
        'maintenanceId': maintenanceId,
        'quantity': quantity,
        'notes': notes.trim(),
      });
    } on FirebaseFunctionsException catch (error) {
      throw StateError(error.message ?? 'تعذر إتمام صرف قطع الغيار');
    }
  }

}
