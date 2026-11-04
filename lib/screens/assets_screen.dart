import 'package:flutter/material.dart';
import 'package:metra_it_assets/models/asset.dart';
import 'package:metra_it_assets/screens/asset_form_screen.dart';
import 'package:metra_it_assets/services/asset_repository.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});
  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}
class _AssetsScreenState extends State<AssetsScreen> {
  final search = TextEditingController();
  final repository = AssetRepository();
  AssetCategory? category;
  AssetStatus? status;
  @override
  void dispose() { search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الأجهزة والجرد')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssetFormScreen())),
      icon: const Icon(Icons.add), label: const Text('إضافة جهاز')),
    body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      const Align(alignment: Alignment.centerRight, child: Text('سجل الأصول', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 280, child: TextField(controller: search, onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث بالاسم أو الموديل أو الرقم التسلسلي'))),
        SizedBox(width: 220, child: DropdownButtonFormField<AssetCategory>(value: category, decoration: const InputDecoration(labelText: 'التصنيف'),
          items: AssetCategory.values.map((e)=>DropdownMenuItem(value:e,child:Text(e.label))).toList(), onChanged: (v)=>setState(()=>category=v))),
        SizedBox(width: 220, child: DropdownButtonFormField<AssetStatus>(value: status, decoration: const InputDecoration(labelText: 'الحالة'),
          items: AssetStatus.values.map((e)=>DropdownMenuItem(value:e,child:Text(e.label))).toList(), onChanged: (v)=>setState(()=>status=v))),
      ]),
      const SizedBox(height: 18),
      Expanded(child: StreamBuilder<List<Asset>>(
        stream: repository.watchAssets(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('تعذر تحميل الأصول: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final q = search.text.trim().toLowerCase();
          final items = snapshot.data!.where((a) =>
            (category == null || a.category == category) &&
            (status == null || a.status == status) &&
            (q.isEmpty || '${a.brand} ${a.model} ${a.serialNumber}'.toLowerCase().contains(q))).toList();
          if (items.isEmpty) return const Center(child: Text('لا توجد أجهزة مطابقة لمعايير البحث'));
          return Card(child: ListView.separated(itemCount: items.length, separatorBuilder: (_,__)=>const Divider(height: 1),
            itemBuilder: (context, i) { final a=items[i]; return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.devices_other)),
              title: Text('${a.brand} ${a.model}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${a.category.label} • الرقم التسلسلي: ${a.serialNumber.isEmpty ? 'غير محدد' : a.serialNumber}'),
              trailing: Chip(label: Text(a.status.label)),
            ); }));
        },
      )),
    ])),
  );
}
