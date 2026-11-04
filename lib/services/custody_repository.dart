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
    this.approvalStatus = 'approved',
  });

  final String id;
  final String assetId;
  final String assetLabel;
  final String employeeName;
  final String officeName;
  final String notes;
  final String status;
  final String approvalStatus;
  final DateTime assignedAt;

  Map<String, Object?> toMap() => {
        'assetId': assetId,
        'assetLabel': assetLabel.trim(),
        'employeeName': employeeName.trim(),
        'officeName': officeName.trim(),
        'assignedAt': assignedAt.toIso8601String(),
        'notes': notes.trim(),
        'status': status,
        'approvalStatus': approvalStatus,
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
        approvalStatus: map['approvalStatus'] as String? ?? 'approved',
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
        if ((cardData['approvalStatus'] ?? 'approved') != 'approved') {
          throw StateError('لا يمكن إرجاع عهدة قبل اعتمادها');
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
          'approvalStatus': 'pending',
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

  Future<void> approveCustody(CustodyRecord record, {required String approverUid}) =>
      db.runTransaction((transaction) async {
        final cardRef = ref.doc(record.id);
        final snapshot = await transaction.get(cardRef);
        if (!snapshot.exists) throw StateError('بطاقة العهدة غير موجودة');
        final data = snapshot.data()!;
        if ((data['status'] ?? 'active') != 'active' ||
            (data['approvalStatus'] ?? 'approved') != 'pending') {
          throw StateError('بطاقة العهدة ليست بانتظار الاعتماد');
        }
        transaction.update(cardRef, {
          'approvalStatus': 'approved',
          'approvedBy': approverUid,
          'approvedAt': FieldValue.serverTimestamp(),
        });
        final movement = db.collection('asset_movements').doc();
        transaction.set(movement, {
          'assetId': data['assetId'],
          'assetLabel': data['assetLabel'],
          'movementType': 'custody_approved',
          'toEmployee': data['employeeName'],
          'toOffice': data['officeName'],
          'occurredAt': DateTime.now().toIso8601String(),
          'custodyId': record.id,
          'notes': 'اعتماد بطاقة العهدة',
        });
      });

  Future<void> rejectCustody(CustodyRecord record, {
    required String approverUid,
    String reason = '',
  }) =>
      db.runTransaction((transaction) async {
        final cardRef = ref.doc(record.id);
        final snapshot = await transaction.get(cardRef);
        if (!snapshot.exists) throw StateError('بطاقة العهدة غير موجودة');
        final data = snapshot.data()!;
        if ((data['status'] ?? 'active') != 'active' ||
            (data['approvalStatus'] ?? 'approved') != 'pending') {
          throw StateError('بطاقة العهدة ليست بانتظار الاعتماد');
        }
        final assetId = data['assetId'] as String? ?? '';
        if (assetId.isEmpty) throw StateError('معرّف الأصل غير صالح');
        final assetRef = db.collection('assets').doc(assetId);
        final assetSnapshot = await transaction.get(assetRef);
        if (!assetSnapshot.exists) throw StateError('الأصل المرتبط غير موجود');
        if (assetSnapshot.data()?['status'] != 'assigned') {
          throw StateError('حالة الأصل لا تسمح برفض العهدة');
        }
        final now = DateTime.now().toIso8601String();
        transaction.update(cardRef, {
          'status': 'rejected',
          'approvalStatus': 'rejected',
          'rejectedBy': approverUid,
          'rejectedAt': now,
          'rejectionReason': reason.trim(),
        });
        transaction.update(assetRef, {'status': 'available'});
        final movement = db.collection('asset_movements').doc();
        transaction.set(movement, {
          'assetId': assetId,
          'assetLabel': data['assetLabel'],
          'movementType': 'custody_rejected',
          'fromEmployee': data['employeeName'],
          'occurredAt': now,
          'custodyId': record.id,
          'notes': reason.trim().isEmpty ? 'رفض بطاقة العهدة' : reason.trim(),
        });
      });

  Future<void> transferCustody(
    CustodyRecord record, {
    required String newEmployeeName,
    required String newOfficeName,
    String notes = '',
  }) =>
      db.runTransaction((transaction) async {
        final employeeName = newEmployeeName.trim();
        final officeName = newOfficeName.trim();
        if (employeeName.isEmpty || officeName.isEmpty) {
          throw ArgumentError('اسم الموظف والمكتب الجديدان مطلوبان');
        }

        final cardRef = ref.doc(record.id);
        final cardSnapshot = await transaction.get(cardRef);
        if (!cardSnapshot.exists) {
          throw StateError('بطاقة العهدة غير موجودة');
        }
        final cardData = cardSnapshot.data()!;
        if ((cardData['status'] ?? 'active') != 'active') {
          throw StateError('لا يمكن نقل بطاقة عهدة مغلقة');
        }
        if ((cardData['approvalStatus'] ?? 'approved') != 'approved') {
          throw StateError('لا يمكن نقل عهدة قبل اعتمادها');
        }

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
          throw StateError('حالة الأصل لا تسمح بنقل العهدة');
        }

        final previousEmployee = cardData['employeeName'] as String? ?? '';
        final previousOffice = cardData['officeName'] as String? ?? '';
        final brand = assetData['brand'] as String? ?? '';
        final model = assetData['model'] as String? ?? '';
        final assetLabel = '$brand $model'.trim();
        final now = DateTime.now().toIso8601String();

        transaction.update(cardRef, {
          'employeeName': employeeName,
          'officeName': officeName,
          'transferredAt': now,
        });
        transaction.update(assetRef, {'officeName': officeName});

        final movementRef = db.collection('asset_movements').doc();
        transaction.set(movementRef, {
          'assetId': assetId,
          'assetLabel': assetLabel,
          'movementType': 'custody_transferred',
          'fromEmployee': previousEmployee,
          'toEmployee': employeeName,
          'fromOffice': previousOffice,
          'toOffice': officeName,
          'occurredAt': now,
          'custodyId': record.id,
          'notes': notes.trim(),
        });
      });

}
