import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
 const ReportsScreen({super.key});
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('التقارير والجرد')),body:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('assets').snapshots(),builder:(context,s){
  if(s.hasError)return Center(child:Text('تعذر تحميل الإحصائيات: ${s.error}'));if(!s.hasData)return const Center(child:CircularProgressIndicator());
  final docs=s.data!.docs;int count(String status)=>docs.where((d)=>d.data()['status']==status).length;
  final categories=<String,int>{};for(final d in docs){final key=d.data()['category'] as String? ?? 'other';categories[key]=(categories[key]??0)+1;}
  final labels={'desktop':'كمبيوتر مكتبي','laptop':'لابتوب','monitor':'شاشة','printer':'طابعة','scanner':'ماسح','network':'معدات شبكة','storage':'تخزين','ups':'UPS','accessory':'ملحقات','other':'أخرى'};
  return ListView(padding:const EdgeInsets.all(20),children:[
   const Text('ملخص الجرد الحالي',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const SizedBox(height:16),
   GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:MediaQuery.sizeOf(context).width>850?4:2,childAspectRatio:1.65,crossAxisSpacing:12,mainAxisSpacing:12,children:[
    _Metric('إجمالي الأصول',docs.length,Icons.devices),_Metric('متوفر',count('available'),Icons.inventory_2_outlined),_Metric('بعهدة الموظفين',count('assigned'),Icons.assignment_ind),_Metric('قيد الصيانة',count('maintenance'),Icons.build_circle_outlined),
   ]),
   const SizedBox(height:22),const Text('التوزيع حسب التصنيف',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:10),
   Card(child:Column(children:categories.entries.map((e)=>ListTile(title:Text(labels[e.key]??e.key),trailing:Text('${e.value}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)))).toList().isEmpty?[const ListTile(title:Text('لا توجد بيانات بعد'))]:categories.entries.map((e)=>ListTile(title:Text(labels[e.key]??e.key),trailing:Text('${e.value}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)))).toList())),
   const SizedBox(height:12),const Text('ملاحظة: الإحصائيات مباشرة من مجموعة assets في Firestore. التصدير والتقارير التفصيلية ستضاف في مرحلة لاحقة.',style:TextStyle(color:Colors.black54)),
  ]);
 }));
}
class _Metric extends StatelessWidget{const _Metric(this.label,this.value,this.icon);final String label;final int value;final IconData icon;@override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:const Color(0xFF168C8C)),const Spacer(),Text('$value',style:const TextStyle(fontSize:26,fontWeight:FontWeight.bold)),Text(label,style:const TextStyle(color:Colors.black54))])));}
