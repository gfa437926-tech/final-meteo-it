import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:metra_it_assets/models/purchase_record.dart';
import 'package:metra_it_assets/services/purchase_repository.dart';
import 'package:metra_it_assets/services/asset_repository.dart';
import 'package:uuid/uuid.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final repository = PurchaseRepository();
  final dateFormat = DateFormat('yyyy/MM/dd');

  Future<void> _showPurchaseDetails(PurchaseRecord record) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تفاصيل فاتورة الشراء'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailLine('الأصل', record.assetLabel),
                _detailLine('المورد', record.supplier),
                _detailLine('رقم الفاتورة', record.invoiceNumber.isEmpty ? 'غير محدد' : record.invoiceNumber),
                _detailLine('تاريخ الشراء', dateFormat.format(record.purchaseDate)),
                _detailLine('قيمة الشراء', record.totalCost.toStringAsFixed(2)),
                _detailLine('الضمان', record.warrantyUntil == null ? 'غير محدد' : dateFormat.format(record.warrantyUntil!)),
                if (record.notes.trim().isNotEmpty) _detailLine('ملاحظات', record.notes),
                const Divider(height: 28),
                const Text('المرفقات المرتبطة', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('asset_documents')
                      .where('purchaseRecordId', isEqualTo: record.id)
                      .where('assetId', isEqualTo: record.assetId)
                      .where('officeId', isEqualTo: record.officeId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Text('تعذر تحميل المرفقات: ${snapshot.error}');
                    if (!snapshot.hasData) return const LinearProgressIndicator();
                    final attachments = snapshot.data!.docs;
                    if (attachments.isEmpty) return const Text('لا توجد فاتورة أو وثيقة مرفقة بهذا السجل');
                    return Column(
                      children: attachments.map((document) {
                        final data = document.data();
                        final name = data['fileName'] as String? ?? 'مرفق';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.attach_file),
                          title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            tooltip: 'مشاركة / تنزيل',
                            icon: const Icon(Icons.download_outlined),
                            onPressed: () async {
                              try {
                                final path = data['storagePath'] as String? ?? '';
                                if (path.isEmpty) throw StateError('مسار الملف غير موجود');
                                final bytes = await FirebaseStorage.instance.ref(path).getData(10 * 1024 * 1024);
                                if (bytes == null || bytes.isEmpty) throw StateError('تعذر قراءة الملف');
                                await Share.shareXFiles([
                                  XFile.fromData(bytes, name: name,
                                    mimeType: data['contentType'] as String? ?? 'application/octet-stream'),
                                ], text: 'مرفق فاتورة شراء');
                              } catch (error) {
                                if (dialogContext.mounted) {
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    SnackBar(content: Text('تعذرت مشاركة المرفق: $error')),
                                  );
                                }
                              }
                            },
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Widget _detailLine(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 125, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(child: Text(value)),
          ],
        ),
      );

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
                    StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                      stream: AssetRepository().watchAssetDocuments(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text('تعذر تحميل الأصول: ${snapshot.error}');
                        }
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }
                        final assets = snapshot.data!;
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
                final today = DateTime.now();
                final warrantyExpired = warranty != null &&
                    warranty.isBefore(DateTime(today.year, today.month, today.day));
                final warrantyLabel = warranty == null
                    ? 'لا يوجد تاريخ ضمان'
                    : warrantyExpired
                        ? 'انتهى الضمان بتاريخ ${dateFormat.format(warranty)}'
                        : 'الضمان ساري حتى ${dateFormat.format(warranty)}';
                return Card(
                  child: ListTile(
                    onTap: () => _showPurchaseDetails(record),
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
