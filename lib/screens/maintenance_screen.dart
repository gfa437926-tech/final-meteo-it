import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/maintenance_record.dart';
import '../services/maintenance_repository.dart';
import '../services/asset_repository.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});
  @override State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}
class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final repo = MaintenanceRepository();
  Future<void> _newTicket() async {
    final form = GlobalKey<FormState>();
    final title = TextEditingController(), description = TextEditingController();
    final technician = TextEditingController();
    String? assetId, assetLabel;
    String priority = 'normal';
    final created = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        title: const Text('فتح طلب صيانة'),
        content: SizedBox(width: 480, child: Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: AssetRepository().watchAssetDocuments(
              statuses: ['available', 'damaged', 'returned'],
            ),
            builder: (ctx, snap) {
              final docs = snap.data ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              return DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'الجهاز'),
                items: docs.map((d) { final m=d.data(); return DropdownMenuItem(value:d.id, child:Text('${m['brand'] ?? ''} ${m['model'] ?? ''} • ${m['serialNumber'] ?? ''}')); }).toList(),
                onChanged: (v) { setDialog(() { assetId=v; final found=docs.where((d)=>d.id==v); if(found.isNotEmpty){final m=found.first.data();assetLabel='${m['brand']??''} ${m['model']??''}';} }); },
                validator: (v)=>v==null?'اختر الجهاز':null,
              );
            },
          ),
          const SizedBox(height: 10),
          TextFormField(controller:title,decoration:const InputDecoration(labelText:'عنوان العطل'),validator:(v)=>v==null||v.trim().isEmpty?'هذا الحقل مطلوب':null),
          TextFormField(controller:description,minLines:2,maxLines:4,decoration:const InputDecoration(labelText:'وصف العطل')),
          TextFormField(controller:technician,decoration:const InputDecoration(labelText:'الفني المسؤول')),
          DropdownButtonFormField<String>(initialValue:priority,decoration:const InputDecoration(labelText:'الأولوية'),items:const [
            DropdownMenuItem(value:'low',child:Text('منخفضة')),DropdownMenuItem(value:'normal',child:Text('عادية')),DropdownMenuItem(value:'high',child:Text('عالية')),DropdownMenuItem(value:'urgent',child:Text('عاجلة')),
          ],onChanged:(v)=>setDialog(()=>priority=v??'normal')),
        ])))),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,form.currentState!.validate()),child:const Text('حفظ الطلب'))],
      ),
    ));
    if(created==true && assetId!=null) {
      try {
        await repo.create(MaintenanceRecord(id:const Uuid().v4(),assetId:assetId!,assetLabel:assetLabel??'',title:title.text,description:description.text,priority:priority,status:MaintenanceStatus.open,reportedAt:DateTime.now(),technician:technician.text));
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم تسجيل طلب الصيانة وتحديث حالة الجهاز')));
      } catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تسجيل الطلب: $e'))); }
    }
    title.dispose(); description.dispose(); technician.dispose();
  }


  Future<void> _complete(MaintenanceRecord record) async {
    final resolution = TextEditingController();
    final cost = TextEditingController(text: '0');
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('إغلاق طلب الصيانة'),
      content: Form(key: form, child: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: resolution, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'الإجراء / الحل المنفذ'), validator: (v) => v == null || v.trim().isEmpty ? 'يرجى توثيق الحل' : null),
        TextFormField(controller: cost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'التكلفة'), validator: (v) => double.tryParse(v ?? '') == null || double.parse(v!) < 0 ? 'أدخل تكلفة صحيحة' : null),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, form.currentState!.validate()), child: const Text('إغلاق الطلب'))],
    ));
    if (ok == true) {
      try {
        await repo.complete(record, resolution: resolution.text, cost: double.parse(cost.text));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أغلق طلب الصيانة وأعيد الجهاز إلى حالته السابقة')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إغلاق الطلب: $e')));
      }
    }
    resolution.dispose();
    cost.dispose();
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('إدارة الصيانة')),
    floatingActionButton:FloatingActionButton.extended(onPressed:_newTicket,icon:const Icon(Icons.add),label:const Text('طلب صيانة جديد')),
    body:StreamBuilder<List<MaintenanceRecord>>(stream:repo.watch(),builder:(context,s){
      if(s.hasError)return Center(child:Text('تعذر تحميل طلبات الصيانة: ${s.error}'));
      if(!s.hasData)return const Center(child:CircularProgressIndicator());
      if(s.data!.isEmpty)return const Center(child:Text('لا توجد طلبات صيانة مسجلة'));
      return ListView.separated(padding:const EdgeInsets.all(16),itemCount:s.data!.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(context,i){
        final r=s.data![i]; final priority={'low':'منخفضة','normal':'عادية','high':'عالية','urgent':'عاجلة'}[r.priority]??r.priority;
        return Card(child:ListTile(leading:CircleAvatar(child:Icon(r.status==MaintenanceStatus.completed?Icons.check:Icons.build)),title:Text(r.title,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${r.assetLabel} • $priority\n${r.description}',maxLines:3,overflow:TextOverflow.ellipsis),isThreeLine:true,trailing:r.status==MaintenanceStatus.open||r.status==MaintenanceStatus.inProgress?TextButton.icon(onPressed:()=>_complete(r),icon:const Icon(Icons.check_circle_outline),label:const Text('إنهاء')):Chip(label:Text(r.status.label))));
      });
    }),
  );
}
