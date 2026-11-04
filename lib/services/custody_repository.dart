import 'package:cloud_firestore/cloud_firestore.dart';

class CustodyRecord {
  const CustodyRecord({
    required this.id,
    required this.assetId,
    required this.assetLabel,
    required this.employeeName,
    required this.officeName,
    required this.assignedAt,
    this.notes = '',
    this.status = 'active',
  });

  final String id;
  final String assetId;
  final String assetLabel;
  final String employeeName;
  final String officeName;
  final String notes;
  final String status;
  final DateTime assignedAt;

  Map<String, Object?> toMap() => {
        'assetId': assetId,
        'assetLabel': assetLabel.trim(),
        'employeeName': employeeName.trim(),
        'officeName': officeName.trim(),
        'assignedAt': assignedAt.toIso8601String(),
        'notes': notes.trim(),
        'status': status,
      };

  factory CustodyRecord.fromMap(String id, Map<String, dynamic> map) =>
      CustodyRecord(
        id: id,
        assetId: map['assetId'] as String? ?? '',
        assetLabel: map['assetLabel'] as String? ?? '',
        employeeName: map['employeeName'] as String? ?? '',
        officeName: map['officeName'] as String? ?? '',
        assignedAt: DateTime.tryParse(map['assignedAt'] as String? ?? '') ??
            DateTime.now(),
        notes: map['notes'] as String? ?? '',
        status: map['status'] as String? ?? 'active',
      );
}

class CustodyRepository {
  CustodyRepository({FirebaseFirestore? firestore})
      : db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get ref =>
      db.collection('custody_cards');

  Stream<List<CustodyRecord>> watch() => ref
      .orderBy('assignedAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => CustodyRecord.fromMap(doc.id, doc.data()))
          .toList());

  Future<void> returnAsset(CustodyRecord record) =>
      db.runTransaction((transaction) async {
        final cardRef = ref.doc(record.id);
        final cardSnapshot = await transaction.get(cardRef);
        if (!cardSnapshot.exists) {
          throw StateError('بطاقة العهدة غير موجودة');
        }

        final cardData = cardSnapshot.data()!;
        if ((cardData['status'] ?? 'active') != 'active') {
          throw StateError('بطاقة العهدة مغلقة مسبقاً');
        }

        // Use the persisted card as the source of truth, not client-supplied
        // asset or employee details from the screen.
        final assetId = cardData['assetId'] as String? ?? '';
        if (assetId.isEmpty) {
          throw StateError('بطاقة العهدة لا تحتوي على معرّف أصل صالح');
        }

        final assetRef = db.collection('assets').doc(assetId);
        final assetSnapshot = await transaction.get(assetRef);
        if (!assetSnapshot.exists) {
          throw StateError('الأصل المرتبط غير موجود');
        }
        final assetData = assetSnapshot.data()!;
        if (assetData['status'] != 'assigned') {
          throw StateError('حالة الأصل لا تسمح بإتمام الإرجاع');
        }

        final now = DateTime.now().toIso8601String();
        final brand = assetData['brand'] as String? ?? '';
        final model = assetData['model'] as String? ?? '';
        final assetLabel = '$brand $model'.trim();
        final employeeName = cardData['employeeName'] as String? ?? '';

        transaction.update(cardRef, {
          'status': 'returned',
          'returnedAt': now,
        });
        transaction.update(assetRef, {'status': 'available'});

        final movementRef = db.collection('asset_movements').doc();
        transaction.set(movementRef, {
          'assetId': assetId,
          'assetLabel': assetLabel,
          'movementType': 'returned',
          'fromEmployee': employeeName,
          'occurredAt': now,
          'custodyId': record.id,
          'notes': 'إرجاع من العهدة',
        });
      });

  Future<void> add(CustodyRecord record) =>
      db.runTransaction((transaction) async {
        final employeeName = record.employeeName.trim();
        final officeName = record.officeName.trim();
        if (employeeName.isEmpty || officeName.isEmpty) {
          throw ArgumentError('اسم الموظف والمكتب مطلوبان');
        }
        if (record.assetId.trim().isEmpty || record.id.trim().isEmpty) {
          throw ArgumentError('معرّف الأصل وبطاقة العهدة مطلوبان');
        }

        final assetRef = db.collection('assets').doc(record.assetId);
        final cardRef = ref.doc(record.id);
        final assetSnapshot = await transaction.get(assetRef);
        final cardSnapshot = await transaction.get(cardRef);

        if (!assetSnapshot.exists) {
          throw StateError('الأصل المحدد غير موجود');
        }
        if (cardSnapshot.exists) {
          throw StateError('معرّف بطاقة العهدة مستخدم مسبقاً');
        }

        final assetData = assetSnapshot.data()!;
        if (assetData['status'] != 'available') {
          throw StateError('الجهاز غير متاح للتسليم أو تم تسليمه مسبقاً');
        }

        final brand = assetData['brand'] as String? ?? '';
        final model = assetData['model'] as String? ?? '';
        final assetLabel = '$brand $model'.trim();
        final now = record.assignedAt.toIso8601String();

        transaction.set(cardRef, {
          ...record.toMap(),
          'assetLabel': assetLabel,
          'employeeName': employeeName,
          'officeName': officeName,
          'status': 'active',
        });
        transaction.update(assetRef, {
          'status': 'assigned',
          'officeName': officeName,
        });

        final movementRef = db.collection('asset_movements').doc();
        transaction.set(movementRef, {
          'assetId': record.assetId,
          'assetLabel': assetLabel,
          'movementType': 'assigned',
          'toEmployee': employeeName,
          'toOffice': officeName,
          'occurredAt': now,
          'custodyId': record.id,
          'notes': record.notes.trim(),
        });
      });
}
