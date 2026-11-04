import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:metra_it_assets/models/asset.dart';
import 'package:metra_it_assets/services/asset_repository.dart';

class AssetFormScreen extends StatefulWidget {
  const AssetFormScreen({super.key, this.initialAsset});
  final Asset? initialAsset;
  @override
  State<AssetFormScreen> createState() => _AssetFormScreenState();
}
class _AssetFormScreenState extends State<AssetFormScreen> {
  final formKey = GlobalKey<FormState>();
  final repository = AssetRepository();
  AssetCategory category = AssetCategory.laptop;
  AssetStatus status = AssetStatus.available;
  final brand = TextEditingController(), model = TextEditingController(), serial = TextEditingController();
  final cpu = TextEditingController(), ram = TextEditingController(), storage = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.initialAsset;
    if (a != null) {
      category = a.category;
      status = a.status;
      brand.text = a.brand;
      model.text = a.model;
      serial.text = a.serialNumber;
      cpu.text = a.cpu ?? '';
      ram.text = a.ram ?? '';
      storage.text = a.storage ?? '';
    }
  }
  @override
  void dispose() { brand.dispose(); model.dispose(); serial.dispose(); cpu.dispose(); ram.dispose(); storage.dispose(); super.dispose(); }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    final asset = Asset(id: widget.initialAsset?.id ?? const Uuid().v4(), category: category, brand: brand.text,
      model: model.text, serialNumber: serial.text, status: status,
      cpu: cpu.text, ram: ram.text, storage: storage.text);
    try {
      if (widget.initialAsset == null) { await repository.createAsset(asset); } else { await repository.updateAsset(asset); }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.initialAsset == null ? 'تم حفظ الجهاز بنجاح' : 'تم تحديث بيانات الجهاز')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.initialAsset == null ? 'إضافة أصل جديد' : 'تعديل بيانات الجهاز')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: Card(
      child: Padding(padding: const EdgeInsets.all(24), child: Form(key: formKey, child: ListView(shrinkWrap: true, children: [
        Text(widget.initialAsset == null ? 'بيانات الجهاز' : 'تحديث بيانات الجهاز', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        DropdownButtonFormField<AssetCategory>(initialValue: category, decoration: const InputDecoration(labelText: 'نوع الجهاز'),
          items: AssetCategory.values.map((e)=>DropdownMenuItem(value:e,child:Text(e.label))).toList(), onChanged: (v)=>setState(()=>category=v!)),
        const SizedBox(height: 14),
        _field(brand, 'الشركة المصنعة', required: true),
        _field(model, 'الموديل', required: true),
        _field(serial, 'الرقم التسلسلي'),
        DropdownButtonFormField<AssetStatus>(initialValue: status, decoration: const InputDecoration(labelText: 'حالة الجهاز'),
          items: AssetStatus.values.map((e)=>DropdownMenuItem(value:e,child:Text(e.label))).toList(), onChanged: (v)=>setState(()=>status=v!)),
        if (category == AssetCategory.laptop || category == AssetCategory.desktop) ...[
          _field(cpu, 'المعالج'), _field(ram, 'الذاكرة RAM'), _field(storage, 'التخزين'),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: saving ? null : save, icon: saving ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.save_outlined),
          label: Text(saving ? 'جارٍ الحفظ...' : 'حفظ الجهاز')),
      ])))),
    )),
  );
  Widget _field(TextEditingController c, String label, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: TextFormField(controller: c, validator: required ? (v)=>v==null||v.trim().isEmpty?'هذا الحقل مطلوب':null : null,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
  );
}
