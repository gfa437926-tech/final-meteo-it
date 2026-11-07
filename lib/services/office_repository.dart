import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:metra_it_assets/models/office.dart';

class OfficeRepository {
  OfficeRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _offices =>
      _db.collection('offices');

  Stream<List<Office>> watchOffices() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const <Office>[]);
    return Stream.fromFuture(_db.collection('users').doc(uid).get())
        .asyncExpand((profile) {
      final data = profile.data() ?? const <String, dynamic>{};
      if (data['isActive'] != true) return Stream.value(const <Office>[]);
      Query<Map<String, dynamic>> query = _offices;
      if (data['role'] != 'admin') {
        final rawOfficeIds = data['officeIds'];
        final officeIds = rawOfficeIds is List
            ? rawOfficeIds.whereType<String>().toSet().toList()
            : <String>[];
        if (data['role'] != 'it_manager' || officeIds.isEmpty) {
          return Stream.value(const <Office>[]);
        }
        // The Firestore query is restricted before data is downloaded.
        query = _offices
            .where(FieldPath.documentId, whereIn: officeIds)
            .where('isActive', isEqualTo: true);
      }
      return query.snapshots().map((snapshot) {
        final offices = snapshot.docs
            .map((doc) => Office.fromMap(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        return offices;
      });
    });
  }

  Future<void> save(Office office) => _offices.doc(office.id).set(office.toMap());
}
