import 'package:flutter/material.dart';
import 'package:metra_it_assets/models/asset.dart';

class AssetFormScreen extends StatefulWidget {
  const AssetFormScreen({super.key});
  @override
  State<AssetFormScreen> createState() => _AssetFormScreenState();
}
class _AssetFormScreenState extends State<AssetFormScreen> {
  final formKey = GlobalKey<FormState>();
  AssetCategory category = AssetCategory.laptop;
  final brand = TextEditingController(), model = TextEditingController(), serial = TextEditingController();
  final cpu = TextEditingController(), ram = TextEditingController(), storage = TextEditingController();
  @override
  void dispose() { brand.dispose(); model.dispose(); serial.dispose(); cpu.dispose(); ram.dispose(); storage.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إضافة أصل جديد')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: Card(
      child: Padding(padding: const EdgeInsets.all(24), child: Form(key: formKey, child: ListView(shrinkWrap: true, children: [
        const Text('بيانات الجهاز', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        DropdownButtonFormField<AssetCategory>(value: category, decoration: const InputDecoration(labelText: 'نوع الجهاز'), items: AssetCategory.values.map((e)=>DropdownMenuItem(value:e,child:Text(e.label))).toList(), onChanged: (v)=>setState(()=>category=v!)),
        const SizedBox(height: 14),
        _field(brand, 'الشركة المصنعة', required: true),
        _field(model, 'الموديل', required: true),
        _field(serial, 'الرقم التسلسلي'),
        if (category == AssetCategory.laptop || category == AssetCategory.desktop) ...[
          _field(cpu, 'المعالج'),
          _field(ram, 'الذاكرة RAM'),
          _field(storage, 'التخزين'),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: () { if (formKey.currentState!.validate()) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('النموذج جاهز؛ الحفظ يتطلب ربط Firestore'))); }, icon: const Icon(Icons.save_outlined), label: const Text('حفظ الجهاز')),
      ]))),
    )),
  );
  Widget _field(TextEditingController c, String label, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: TextFormField(controller: c, validator: required ? (v)=>v==null||v.trim().isEmpty?'هذا الحقل مطلوب':null : null, decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
  );
}
