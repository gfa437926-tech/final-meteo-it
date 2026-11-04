import 'package:cloud_firestore/cloud_firestore.dart';
class CustodyRecord {
 const CustodyRecord({required this.id,required this.assetId,required this.assetLabel,required this.employeeName,required this.officeName,required this.assignedAt,this.notes='',this.status='active'});
 final String id,assetId,assetLabel,employeeName,officeName,notes,status; final DateTime assignedAt;
 Map<String,Object?> toMap()=>{'assetId':assetId,'assetLabel':assetLabel,'employeeName':employeeName.trim(),'officeName':officeName.trim(),'assignedAt':assignedAt.toIso8601String(),'notes':notes.trim(),'status':status};
 factory CustodyRecord.fromMap(String id,Map<String,dynamic> m)=>CustodyRecord(id:id,assetId:m['assetId']??'',assetLabel:m['assetLabel']??'',employeeName:m['employeeName']??'',officeName:m['officeName']??'',assignedAt:DateTime.tryParse(m['assignedAt']??'')??DateTime.now(),notes:m['notes']??'',status:m['status']??'active');
}
class CustodyRepository {
 CustodyRepository({FirebaseFirestore? firestore}):db=firestore??FirebaseFirestore.instance;
 final FirebaseFirestore db;
 CollectionReference<Map<String,dynamic>> get ref=>db.collection('custody_cards');
 Stream<List<CustodyRecord>> watch()=>ref.orderBy('assignedAt',descending:true).snapshots().map((s)=>s.docs.map((d)=>CustodyRecord.fromMap(d.id,d.data())).toList());
 Future<void> add(CustodyRecord r)=>db.runTransaction((tx)async{final asset=db.collection('assets').doc(r.assetId);final snap=await tx.get(asset);if(!snap.exists)throw StateError('الأصل المحدد غير موجود');tx.set(ref.doc(r.id),r.toMap());tx.update(asset,{'status':'assigned','officeName':r.officeName});});
}
