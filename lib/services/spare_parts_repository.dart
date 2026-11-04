import 'package:cloud_firestore/cloud_firestore.dart';

class SparePartsRepository {
  SparePartsRepository({FirebaseFirestore? firestore})
      : db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get parts =>
      db.collection('spare_parts');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchParts() =>
      parts.orderBy('name').snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOpenTickets() =>
      db.collection('maintenance_records')
          .where('status', whereIn: ['open', 'inProgress'])
          .snapshots();

  Future<void> addPart({
    required String id,
    required String name,
    required String sku,
    required int quantity,
    required int minimumQuantity,
    required double unitCost,
    required String supplier,
  }) async {
    final cleanName = name.trim();
    final cleanSku = sku.trim().toUpperCase();
    if (cleanName.isEmpty || cleanSku.isEmpty || quantity < 0 ||
        minimumQuantity < 0 || !unitCost.isFinite || unitCost < 0) {
      throw ArgumentError('تحقق من اسم القطعة ورمزها والكميات والتكلفة');
    }
    final ref = parts.doc(id);
    await db.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) throw StateError('معرّف القطعة مستخدم مسبقاً');
      transaction.set(ref, {
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

  Future<void> consume({
    required String partId,
    required String maintenanceId,
    required int quantity,
    required String notes,
  }) async {
    if (quantity <= 0) throw ArgumentError('الكمية يجب أن تكون أكبر من صفر');
    final partRef = parts.doc(partId);
    final ticketRef = db.collection('maintenance_records').doc(maintenanceId);
    final usageRef = db.collection('maintenance_parts').doc();
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
      final available = (part['quantity'] as num?)?.toInt() ?? 0;
      if (available < quantity) throw StateError('الكمية المتاحة غير كافية');
      final unitCost = (part['unitCost'] as num?)?.toDouble() ?? 0;
      final partName = part['name'] as String? ?? '';
      final ticketAssetId = ticket['assetId'] as String? ?? '';
      if (ticketAssetId.isEmpty) throw StateError('طلب الصيانة غير مرتبط بأصل');
      transaction.update(partRef, {
        'quantity': available - quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(usageRef, {
        'partId': partId,
        'partName': partName,
        'maintenanceId': maintenanceId,
        'assetId': ticketAssetId,
        'quantity': quantity,
        'unitCost': unitCost,
        'totalCost': unitCost * quantity,
        'notes': notes.trim(),
        'usedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
