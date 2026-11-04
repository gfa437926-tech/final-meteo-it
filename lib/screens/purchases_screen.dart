import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:metra_it_assets/models/purchase_record.dart';
import 'package:metra_it_assets/services/purchase_repository.dart';
import 'package:uuid/uuid.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final repository = PurchaseRepository();
  final dateFormat = DateFormat('yyyy/MM/dd');

  Future<void> _addPurchase() async {
    final formKey = GlobalKey<FormState>();
    final supplier = TextEditingController();
    final invoice = TextEditingController();
    final cost = TextEditingController(text: '0');
    final notes = TextEditingController();
    String? assetId;
    DateTime purchaseDate = DateTime.now();
    DateTime? warrantyUntil;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('تسجيل فاتورة شراء وضمان'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('assets')
                          .orderBy('brand')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text('تعذر تحميل الأصول: ${snapshot.error}');
                        }
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }
                        final assets = snapshot.data!.docs;
                        return DropdownButtonFormField<String>(
                          initialValue: assetId,
                          decoration: const InputDecoration(labelText: 'الأصل المرتبط'),
                          items: assets.map((document) {
                            final data = document.data();
                            return DropdownMenuItem(
                              value: document.id,
                              child: Text(
                                '${data['brand'] ?? ''} ${data['model'] ?? ''} • ${data['serialNumber'] ?? ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) => setDialogState(() => assetId = value),
                          validator: (value) => value == null ? 'اختر الأصل' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: supplier,
                      decoration: const InputDecoration(labelText: 'اسم المورد'),
                      validator: (value) => value == null || value.trim().isEmpty ? 'اسم المورد مطلوب' : null,
                    ),
                    TextFormField(
                      controller: invoice,
                      decoration: const InputDecoration(labelText: 'رقم الفاتورة'),
                    ),
                    TextFormField(
                      controller: cost,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'قيمة الشراء'),
                      validator: (value) {
                        final amount = double.tryParse(value ?? '');
                        return amount == null || !amount.isFinite || amount < 0
                            ? 'أدخل قيمة صحيحة غير سالبة'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('تاريخ الشراء'),
                      subtitle: Text(dateFormat.format(purchaseDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: dialogContext,
                          initialDate: purchaseDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (selected != null) {
                          setDialogState(() => purchaseDate = selected);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('انتهاء الضمان'),
                      subtitle: Text(
                        warrantyUntil == null
                            ? 'غير محدد'
                            : dateFormat.format(warrantyUntil!),
                      ),
                      trailing: Wrap(
                        children: [
                          if (warrantyUntil != null)
                            IconButton(
                              tooltip: 'مسح تاريخ الضمان',
                              onPressed: () => setDialogState(() => warrantyUntil = null),
                              icon: const Icon(Icons.clear),
                            ),
                          const Icon(Icons.verified_user_outlined),
                        ],
                      ),
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: dialogContext,
                          initialDate: warrantyUntil ?? purchaseDate,
                          firstDate: purchaseDate,
                          lastDate: DateTime(2100),
                        );
                        if (selected != null) {
                          setDialogState(() => warrantyUntil = selected);
                        }
                      },
                    ),
                    TextFormField(
                      controller: notes,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'ملاحظات'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                formKey.currentState?.validate() ?? false,
              ),
              child: const Text('حفظ الفاتورة'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && assetId != null) {
      try {
        await repository.create(
          PurchaseRecord(
            id: const Uuid().v4(),
            assetId: assetId!,
            assetLabel: '',
            supplier: supplier.text,
            invoiceNumber: invoice.text,
            purchaseDate: purchaseDate,
            warrantyUntil: warrantyUntil,
            totalCost: double.parse(cost.text),
            notes: notes.text,
          ),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تسجيل فاتورة الشراء والضمان')),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر تسجيل الفاتورة: $error')),
          );
        }
      }
    }

    supplier.dispose();
    invoice.dispose();
    cost.dispose();
    notes.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('المشتريات والضمان')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addPurchase,
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('فاتورة شراء جديدة'),
        ),
        body: StreamBuilder<List<PurchaseRecord>>(
          stream: repository.watch(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('تعذر تحميل المشتريات: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return const Center(child: Text('لا توجد فواتير شراء مسجلة'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: snapshot.data!.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final record = snapshot.data![index];
                final warranty = record.warrantyUntil;
                final warrantyLabel = warranty == null
                    ? 'لا يوجد تاريخ ضمان'
                    : 'الضمان حتى ${dateFormat.format(warranty)}';
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.receipt_long_outlined),
                    ),
                    title: Text(
                      record.assetLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${record.supplier} • فاتورة ${record.invoiceNumber.isEmpty ? 'بدون رقم' : record.invoiceNumber}\n'
                      '${dateFormat.format(record.purchaseDate)} • $warrantyLabel',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      record.totalCost.toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}
