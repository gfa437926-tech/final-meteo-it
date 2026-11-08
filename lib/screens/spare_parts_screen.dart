import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/spare_parts_repository.dart';
import '../services/office_repository.dart';

class SparePartsScreen extends StatefulWidget {
  const SparePartsScreen({super.key});

  @override
  State<SparePartsScreen> createState() => _SparePartsScreenState();
}

class _SparePartsScreenState extends State<SparePartsScreen> {
  final repository = SparePartsRepository();

  Future<void> _addPart() async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController();
    final sku = TextEditingController();
    final quantity = TextEditingController(text: '0');
    final minimum = TextEditingController(text: '1');
    final cost = TextEditingController(text: '0');
    final supplier = TextEditingController();
    final offices = (await OfficeRepository().watchOffices().first)
        .where((office) => office.isActive).toList();
    if (!mounted) return;
    if (offices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مكاتب نشطة مخولة لإضافة المخزون')),
      );
      name.dispose(); sku.dispose(); quantity.dispose(); minimum.dispose();
      cost.dispose(); supplier.dispose();
      return;
    }
    String? selectedOfficeId = offices.length == 1 ? offices.first.id : null;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
        title: const Text('إضافة قطعة غيار للمخزون'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  value: selectedOfficeId,
                  decoration: const InputDecoration(labelText: 'المكتب'),
                  items: offices.map((office) => DropdownMenuItem(
                    value: office.id, child: Text(office.name),
                  )).toList(),
                  onChanged: (value) => setDialog(() => selectedOfficeId = value),
                  validator: (value) => value == null ? 'اختر المكتب' : null,
                ),
                const SizedBox(height: 10),
                _field(name, 'اسم القطعة'),
                _field(sku, 'رمز القطعة / SKU'),
                _field(quantity, 'الكمية الحالية', numeric: true),
                _field(minimum, 'حد التنبيه الأدنى', numeric: true),
                _field(cost, 'تكلفة القطعة الواحدة', numeric: true),
                _field(supplier, 'المورد (اختياري)', required: false),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (selectedOfficeId != null && form.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('حفظ القطعة'),
          ),
        ],
      ),
    );
    if (saved == true) {
      try {
        await repository.addPart(
          id: const Uuid().v4(),
          officeId: selectedOfficeId!,
          name: name.text,
          sku: sku.text,
          quantity: int.parse(quantity.text),
          minimumQuantity: int.parse(minimum.text),
          unitCost: double.parse(cost.text),
          supplier: supplier.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت إضافة قطعة الغيار إلى المخزون')),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذرت إضافة القطعة: $error')),
          );
        }
      }
    }
    name.dispose();
    sku.dispose();
    quantity.dispose();
    minimum.dispose();
    cost.dispose();
    supplier.dispose();
  }

  Future<void> _consume(QueryDocumentSnapshot<Map<String, dynamic>> part) async {
    final form = GlobalKey<FormState>();
    final amount = TextEditingController(text: '1');
    final notes = TextEditingController();
    String? maintenanceId;
    final tickets = await repository.watchOpenTickets().first;
    if (!mounted) return;
    if (tickets.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد طلبات صيانة مفتوحة لصرف القطع عليها')),
      );
      amount.dispose();
      notes.dispose();
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('صرف قطعة: ${part.data()['name'] ?? ''}'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'طلب الصيانة'),
                  items: tickets.docs.map((ticket) {
                    final data = ticket.data();
                    return DropdownMenuItem(
                      value: ticket.id,
                      child: Text('${data['title'] ?? 'طلب صيانة'} • ${data['assetLabel'] ?? ''}',
                          overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (value) => setDialog(() => maintenanceId = value),
                  validator: (_) => maintenanceId == null ? 'اختر طلب الصيانة' : null,
                ),
                _field(amount, 'الكمية المصروفة', numeric: true),
                _field(notes, 'ملاحظات (اختياري)', required: false),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (maintenanceId != null && form.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('تأكيد الصرف'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && maintenanceId != null) {
      try {
        await repository.consume(
          partId: part.id,
          maintenanceId: maintenanceId!,
          quantity: int.parse(amount.text),
          notes: notes.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم صرف القطعة وتحديث رصيد المخزون')),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر صرف القطعة: $error')),
          );
        }
      }
    }
    amount.dispose();
    notes.dispose();
  }

  Widget _field(TextEditingController controller, String label,
      {bool numeric = false, bool required = true}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: controller,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(labelText: label),
          validator: (value) {
            if (required && (value == null || value.trim().isEmpty)) {
              return 'هذا الحقل مطلوب';
            }
            if (numeric && value != null && value.trim().isNotEmpty) {
              final parsed = double.tryParse(value);
              if (parsed == null || !parsed.isFinite || parsed < 0 ||
                  ((label.contains('الكمية') || label.contains('حد التنبيه')) && parsed != parsed.roundToDouble())) {
                return 'أدخل قيمة صحيحة غير سالبة';
              }
            }
            return null;
          },
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('مخزون قطع الغيار')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addPart,
          icon: const Icon(Icons.add),
          label: const Text('إضافة قطعة'),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: repository.watchParts(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('تعذر تحميل المخزون: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Center(child: Text('مخزون قطع الغيار فارغ'));
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final part = docs[index];
                final data = part.data();
                final stock = (data['quantity'] as num?)?.toInt() ?? 0;
                final minimum = (data['minimumQuantity'] as num?)?.toInt() ?? 0;
                final low = stock <= minimum;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: low ? Colors.orange.shade50 : null,
                      child: Icon(low ? Icons.warning_amber : Icons.inventory_2_outlined,
                          color: low ? Colors.deepOrange : null),
                    ),
                    title: Text(data['name'] as String? ?? 'قطعة غيار',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'الرمز: ${data['sku'] ?? '—'} • المورد: ${data['supplier'] ?? '—'}\n'
                      'الرصيد: $stock • حد التنبيه: $minimum • تكلفة الوحدة: ${data['unitCost'] ?? 0}',
                    ),
                    isThreeLine: true,
                    trailing: FilledButton.tonal(
                      onPressed: stock > 0 ? () => _consume(part) : null,
                      child: const Text('صرف'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}
