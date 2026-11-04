import 'package:flutter/material.dart';
import 'package:metra_it_assets/models/asset.dart';
import 'package:metra_it_assets/models/office.dart';
import 'package:metra_it_assets/screens/asset_form_screen.dart';
import 'package:metra_it_assets/services/asset_repository.dart';
import 'package:metra_it_assets/services/office_repository.dart';

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

  Future<void> _retire(Asset asset) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('استبعاد الجهاز من الخدمة'),
      content: TextField(controller: reason, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'سبب الاستبعاد')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد الاستبعاد')),
      ],
    ));
    if (confirmed == true) {
      try {
        await repository.retireAsset(asset, reason: reason.text);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استبعاد الجهاز مع الاحتفاظ بسجل حركته')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الاستبعاد: $e')));
      }
    }
    reason.dispose();
  }

  Future<void> _transfer(Asset asset) async {
    final offices = OfficeRepository();
    final notes = TextEditingController();
    final key = GlobalKey<FormState>();
    Office? destination;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('نقل الجهاز إلى مكتب آخر'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('الجهاز: ${asset.brand} ${asset.model}'),
                  const SizedBox(height: 14),
                  StreamBuilder<List<Office>>(
                    stream: offices.watchOffices(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Text('تعذر تحميل المكاتب: ${snapshot.error}');
                      if (!snapshot.hasData) return const LinearProgressIndicator();
                      final available = snapshot.data!.where((o) => o.isActive && o.id != asset.officeId).toList();
                      if (available.isEmpty) return const Text('لا توجد مكاتب نشطة أخرى. أضف مكتباً أولاً.');
                      return DropdownButtonFormField<String>(
                        initialValue: destination?.id,
                        decoration: const InputDecoration(labelText: 'المكتب الوجهة'),
                        items: available.map((o) => DropdownMenuItem(value: o.id, child: Text(o.name))).toList(),
                        onChanged: (id) => setDialog(() {
                          destination = available.where((o) => o.id == id).firstOrNull;
                        }),
                        validator: (_) => destination == null ? 'اختر المكتب الوجهة' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'سبب النقل / ملاحظات'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (destination != null && key.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('تأكيد النقل'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && destination != null) {
      try {
        await repository.transferAsset(asset, destination!, notes: notes.text);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم نقل الجهاز إلى ${destination!.name} وتسجيل الحركة')),
        );
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر نقل الجهاز: $e')));
      }
    }
    notes.dispose();
  }

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
        SizedBox(width: 220, child: DropdownButtonFormField<AssetCategory>(initialValue: category, decoration: const InputDecoration(labelText: 'التصنيف'),
          items: AssetCategory.values.map((e)=>DropdownMenuItem(value:e,child:Text(e.label))).toList(), onChanged: (v)=>setState(()=>category=v))),
        SizedBox(width: 220, child: DropdownButtonFormField<AssetStatus>(initialValue: status, decoration: const InputDecoration(labelText: 'الحالة'),
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
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Chip(label: Text(a.status.label)),
                PopupMenuButton<String>(
                  tooltip: 'إجراءات الجهاز',
                  onSelected: (v) {
                    if (v == 'edit') Navigator.push(context, MaterialPageRoute(builder: (_) => AssetFormScreen(initialAsset: a)));
                    if (v == 'retire') _retire(a);
                    if (v == 'transfer') _transfer(a);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: ListTile(dense: true, leading: Icon(Icons.edit_outlined), title: Text('تعديل البيانات'))),
                    if (a.status != AssetStatus.retired) const PopupMenuItem(value: 'retire', child: ListTile(dense: true, leading: Icon(Icons.archive_outlined), title: Text('استبعاد من الخدمة'))),
                    if (a.status == AssetStatus.available || a.status == AssetStatus.returned) const PopupMenuItem(value: 'transfer', child: ListTile(dense: true, leading: Icon(Icons.drive_file_move_outline), title: Text('نقل إلى مكتب آخر'))),
                  ],
                ),
              ]),
            ); }));
        },
      )),
    ])),
  );
}
