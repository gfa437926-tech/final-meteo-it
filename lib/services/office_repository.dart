import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:metra_it_assets/models/office.dart';
class OfficeRepository {
  OfficeRepository({FirebaseFirestore? firestore}):_db=firestore??FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  CollectionReference<Map<String,dynamic>> get _offices=>_db.collection('offices');
  Stream<List<Office>> watchOffices()=>_offices.orderBy('name').snapshots().map((s)=>s.docs.map((d)=>Office.fromMap(d.id,d.data())).toList());
  Future<void> save(Office office)=>_offices.doc(office.id).set(office.toMap());
}