import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SparePartsRepository {
  SparePartsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore db;
  final FirebaseAuth _auth;

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
        'minimumQuantity': minimumQuantity,
        'unitCost': unitCost,
        'supplier': supplier.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }


  /// Atomically increases stock and appends an immutable receipt audit record.
  /// The part's unitCost is recalculated as a weighted average.
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
      final currentQuantity = part['quantity'] as int? ?? -1;
      final currentUnitCost = (part['unitCost'] as num?)?.toDouble() ?? double.nan;
      if (currentQuantity < 0 || !currentUnitCost.isFinite ||
          currentUnitCost < 0) {
        throw StateError('بيانات رصيد أو تكلفة المخزون غير صالحة');
      }
      final newQuantity = currentQuantity + quantity;
      if (newQuantity < currentQuantity) {
        throw StateError('تجاوز الحد المسموح لكمية المخزون');
      }
      final totalCost = quantity * unitCost;
      final averageCost =
          ((currentQuantity * currentUnitCost) + totalCost) / newQuantity;
      final now = FieldValue.serverTimestamp();
      transaction.update(partRef, {
        'quantity': newQuantity,
        'unitCost': averageCost,
        'supplier': cleanSupplier,
        'lastRestockId': receiptRef.id,
        'updatedAt': now,
      });
      transaction.set(receiptRef, {
        'partId': partId,
        'officeId': officeId,
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
    });
  }

  Future<void> consume({
    required String partId,
    required String maintenanceId,
    required int quantity,
    required String notes,
  }) async {
    if (quantity <= 0) throw ArgumentError('الكمية يجب أن تكون أكبر من صفر');
    final partRef = parts.doc(partId);
    final ticketRef = _tickets.doc(maintenanceId);
    final usageRef = db.collection('maintenance_parts').doc();
    final assetCollection = db.collection('assets');

    await db.runTransaction((transaction) async {
      final partSnapshot = await transaction.get(partRef);
      final ticketSnapshot = await transaction.get(ticketRef);
      if (!partSnapshot.exists) throw StateError('قطعة الغيار غير موجودة');
      if (!ticketSnapshot.exists) throw StateError('طلب الصيانة غير موجود');

      final part = partSnapshot.data()!;
      final ticket = ticketSnapshot.data()!;
      final status = ticket['status'] as String? ?? '';
      if (status != 'open' && status != 'inProgress') {
        throw StateError('لا يمكن صرف قطع غيار لطلب صيانة مغلق');
      }

      final assetId = ticket['assetId'] as String? ?? '';
      final officeId = ticket['officeId'] as String? ?? '';
      if (assetId.isEmpty || officeId.isEmpty) {
        throw StateError('طلب الصيانة غير مرتبط بأصل ومكتب صالحين');
      }
      final assetRef = assetCollection.doc(assetId);
      final assetSnapshot = await transaction.get(assetRef);
      final officeRef = db.collection('offices').doc(officeId);
      final officeSnapshot = await transaction.get(officeRef);
      if (!assetSnapshot.exists || !officeSnapshot.exists ||
          officeSnapshot.data()?['isActive'] != true) {
        throw StateError('الأصل أو المكتب غير موجود أو غير نشط');
      }
      if (assetSnapshot.data()?['officeId'] != officeId ||
          part['officeId'] != officeId) {
        throw StateError('يجب أن تتطابق مكاتب القطعة وطلب الصيانة والأصل');
      }
      if (assetSnapshot.data()?['status'] != 'maintenance') {
        throw StateError('الأصل المرتبط ليس في حالة صيانة');
      }

      final available = (part['quantity'] as num?)?.toInt() ?? 0;
      if (available < quantity) throw StateError('الكمية المتاحة غير كافية');
      final unitCost = (part['unitCost'] as num?)?.toDouble() ?? 0;
      if (!unitCost.isFinite || unitCost < 0) {
        throw StateError('تكلفة القطعة المخزنة غير صالحة');
      }
      final totalCost = unitCost * quantity;
      final previousPartsCost = (ticket['partsCost'] as num?)?.toDouble() ?? 0;
      if (!previousPartsCost.isFinite || previousPartsCost < 0) {
        throw StateError('تكلفة القطع السابقة غير صالحة');
      }
      final usageId = usageRef.id;
      final now = FieldValue.serverTimestamp();

      transaction.update(partRef, {
        'quantity': available - quantity,
        'lastUsageId': usageId,
        'updatedAt': now,
      });
      transaction.update(ticketRef, {
        'partsCost': previousPartsCost + totalCost,
        'lastPartsUsageId': usageId,
        'updatedAt': now,
      });
      transaction.set(usageRef, {
        'partId': partId,
        'partName': part['name'] as String? ?? '',
        'maintenanceId': maintenanceId,
        'assetId': assetId,
        'officeId': officeId,
        'quantity': quantity,
        'unitCost': unitCost,
        'totalCost': totalCost,
        'notes': notes.trim(),
        'usedAt': now,
      });
    });
  }
}
