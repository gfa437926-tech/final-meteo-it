import 'package:flutter/material.dart';
import 'package:metra_it_assets/models/asset.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});
  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}
class _AssetsScreenState extends State<AssetsScreen> {
  AssetCategory? category;
  AssetStatus? status;
  final search = TextEditingController();
  @override
  void dispose() { search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الأجهزة والجرد')),
    floatingActionButton: FloatingActionButton.extended(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('إضافة جهاز')),
    body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      const Align(alignment: Alignment.centerRight, child: Text('سجل الأصول', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 280, child: TextField(controller: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'الموديل أو الرقم التسلسلي'))),
        SizedBox(width: 220, child: DropdownButtonFormField<AssetCategory>(value: category, decoration: const InputDecoration(labelText: 'التصنيف'), items: AssetCategory.values.map((e)=>DropdownMenuItem(value:e,child:Text(e.label))).toList(), onChanged: (v)=>setState(()=>category=v))),
        SizedBox(width: 220, child: DropdownButtonFormField<AssetStatus>(value: status, decoration: const InputDecoration(labelText: 'الحالة'), items: AssetStatus.values.map((e)=>DropdownMenuItem(value:e,child:Text(e.label))).toList(), onChanged: (v)=>setState(()=>status=v))),
      ]),
      const SizedBox(height: 18),
      Expanded(child: Card(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inventory_2_outlined, size: 54, color: Colors.blueGrey.shade300),
        const SizedBox(height: 12), const Text('لا توجد أصول مسجلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Text('ستظهر الأجهزة بعد ربط قاعدة البيانات أو استيراد ملف الجرد'),
      ])))),
    ])),
  );
}
