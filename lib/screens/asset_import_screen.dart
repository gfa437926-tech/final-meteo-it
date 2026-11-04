import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:metra_it_assets/models/asset.dart';
import 'package:metra_it_assets/services/asset_repository.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

class AssetImportScreen extends StatefulWidget {
  const AssetImportScreen({super.key});

  @override
  State<AssetImportScreen> createState() => _AssetImportScreenState();
}

class _ParsedAssetRow {
  _ParsedAssetRow({required this.rowNumber, required this.asset, required this.errors});
  final int rowNumber;
  final Asset asset;
  final List<String> errors;
  bool get valid => errors.isEmpty;
}

class _AssetImportScreenState extends State<AssetImportScreen> {
  final repository = AssetRepository();
  List<_ParsedAssetRow> rows = [];
  String? sourceName;
  bool importing = false;

  Future<void> _selectCsv() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _message('تعذر قراءة ملف CSV');
      return;
    }
    if (bytes.length > 5 * 1024 * 1024) {
      _message('الحد الأقصى لملف الاستيراد 5 ميغابايت');
      return;
    }
    try {
      var content = utf8.decode(bytes);
      content = content.replaceFirst('\uFEFF', '');
      final table = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(content);
      if (table.length < 2) throw const FormatException('الملف لا يحتوي على صفوف بيانات');
      final headers = table.first.map((value) => value.toString().trim().toLowerCase()).toList();
      final requiredHeaders = ['category', 'brand', 'model', 'serial_number'];
      final missing = requiredHeaders.where((name) => !headers.contains(name)).toList();
      if (missing.isNotEmpty) {
        throw FormatException('الأعمدة المطلوبة غير موجودة: ${missing.join(', ')}');
      }
      if (table.length - 1 > 100) {
        throw const FormatException('الحد الأقصى 100 أصل في الدفعة الواحدة');
      }
      final existingAssets = await repository.watchAssets().first;
      final existingSerials = existingAssets
          .map((asset) => asset.serialNumber.trim().toUpperCase())
          .where((serial) => serial.isNotEmpty)
          .toSet();
      final officesSnapshot = await FirebaseFirestore.instance.collection('offices').get();
      final offices = <String, Map<String, dynamic>>{
        for (final office in officesSnapshot.docs)
          if (office.data()['isActive'] != false) office.id: office.data(),
      };
      final parsed = <_ParsedAssetRow>[];
      final seenSerials = <String>{};
      String valueAt(List<dynamic> row, String key) {
        final index = headers.indexOf(key);
        if (index < 0 || index >= row.length) return '';
        return row[index].toString().trim();
      }

      for (var i = 1; i < table.length; i++) {
        final row = table[i];
        if (row.every((cell) => cell.toString().trim().isEmpty)) continue;
        final errors = <String>[];
        final categoryValue = valueAt(row, 'category').toLowerCase();
        final category = AssetCategory.values.where((item) => item.name == categoryValue).toList();
        if (category.isEmpty) errors.add('تصنيف الجهاز غير صالح');
        final brand = valueAt(row, 'brand');
        final model = valueAt(row, 'model');
        final serial = valueAt(row, 'serial_number').toUpperCase();
        if (brand.isEmpty) errors.add('الشركة مطلوبة');
        if (model.isEmpty) errors.add('الطراز مطلوب');
        if (serial.isEmpty) errors.add('الرقم التسلسلي مطلوب');
        if (serial.isNotEmpty && existingSerials.contains(serial)) {
          errors.add('الرقم التسلسلي مسجل مسبقاً في النظام');
        }
        if (serial.isNotEmpty && !seenSerials.add(serial)) {
          errors.add('الرقم التسلسلي مكرر داخل ملف الاستيراد');
        }
        final statusValue = valueAt(row, 'status').toLowerCase();
        AssetStatus? status = statusValue.isEmpty ? AssetStatus.available : null;
        for (final candidate in AssetStatus.values) {
          if (candidate.name == statusValue) status = candidate;
        }
        if (status == null) errors.add('حالة الجهاز غير صالحة');
        if (status == AssetStatus.assigned) errors.add('لا يمكن استيراد جهاز بعهدة دون بطاقة عهدة مرتبطة');
        if (status == AssetStatus.maintenance) errors.add('لا يمكن استيراد جهاز قيد الصيانة دون طلب صيانة مرتبط');
        final officeId = valueAt(row, 'office_id');
        final office = officeId.isEmpty ? null : offices[officeId];
        if (officeId.isNotEmpty && office == null) {
          errors.add('معرّف المكتب غير موجود أو غير فعال');
        }
        final receivedText = valueAt(row, 'received_at');
        final receivedAt = receivedText.isEmpty ? null : DateTime.tryParse(receivedText);
        if (receivedText.isNotEmpty && receivedAt == null) errors.add('تاريخ الاستلام غير صالح');
        parsed.add(_ParsedAssetRow(
          rowNumber: i + 1,
          asset: Asset(
            id: const Uuid().v4(),
            category: category.isEmpty ? AssetCategory.other : category.first,
            brand: brand,
            model: model,
            serialNumber: serial,
            status: status ?? AssetStatus.available,
            cpu: valueAt(row, 'cpu').isEmpty ? null : valueAt(row, 'cpu'),
            ram: valueAt(row, 'ram').isEmpty ? null : valueAt(row, 'ram'),
            storage: valueAt(row, 'storage').isEmpty ? null : valueAt(row, 'storage'),
            officeId: officeId.isEmpty ? null : officeId,
            officeName: office == null ? null : office['name'] as String?,
            receivedAt: receivedAt,
          ),
          errors: errors,
        ));
      }
      if (parsed.isEmpty) throw const FormatException('لا توجد صفوف بيانات صالحة للقراءة');
      if (!mounted) return;
      setState(() {
        rows = parsed;
        sourceName = file.name;
      });
    } catch (error) {
      _message('تعذر تحليل الملف: $error');
    }
  }

  Future<void> _importValidRows() async {
    final validRows = rows.where((row) => row.valid).toList();
    if (validRows.isEmpty || importing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد استيراد الأصول'),
        content: Text('سيتم إضافة ${validRows.length} أصل جديد. لن يتم تعديل الأصول الموجودة. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('بدء الاستيراد')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => importing = true);
    var success = 0;
    final failures = <String>[];
    final skippedInvalidRows = rows.where((row) => !row.valid).length;
    final batchId = const Uuid().v4();
    final actorUid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    for (final row in validRows) {
      try {
        await repository.createAsset(row.asset);
        success++;
      } catch (error) {
        row.errors.add('تعذر الاستيراد: $error');
        failures.add('السطر ${row.rowNumber}: $error');
      }
    }
    String? auditError;
    try {
      await FirebaseFirestore.instance.collection('import_batches').doc(batchId).set({
        'sourceName': sourceName ?? 'asset-import.csv',
        'createdBy': actorUid,
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
        'totalRows': rows.length,
        'attemptedRows': validRows.length,
        'succeededRows': success,
        'failedRows': failures.length,
        'skippedInvalidRows': skippedInvalidRows,
        'status': failures.isEmpty ? 'completed' : (success > 0 ? 'partial' : 'failed'),
        'rowErrors': failures,
      });
    } catch (error) {
      auditError = error.toString();
    }
    if (!mounted) return;
    setState(() {
      importing = false;
      rows = rows.where((row) => !row.valid).toList();
    });
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('نتيجة الاستيراد'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('تمت إضافة $success أصل بنجاح من أصل ${validRows.length}.'),
                Text('رقم دفعة الاستيراد: $batchId'),
                if (auditError != null) Text('تعذر حفظ سجل التدقيق: $auditError'),
                if (failures.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('الصفوف التي تعذر استيرادها:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...failures.map((failure) => Text(failure)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
        ],
      ),
    );
    if (mounted && success > 0) _message('اكتمل استيراد $success أصل');
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final validCount = rows.where((row) => row.valid).length;
    final invalidCount = rows.length - validCount;
    return Scaffold(
      appBar: AppBar(title: const Text('استيراد الأصول من CSV')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('استيراد من Excel أو Google Sheets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('نزّل الجدول بصيغة CSV، ثم اختر الملف لمعاينة الصفوف والتحقق من الأرقام التسلسلية والمكاتب قبل الإضافة.'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: importing ? null : _selectCsv,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('اختيار ملف CSV'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => Share.share('category,brand,model,serial_number,status,office_id,cpu,ram,storage,received_at\ndesktop,Dell,OptiPlex,ABC123,available,OFFICE_ID,Core i5,16 GB,512 GB,2026-01-15'),
                          icon: const Icon(Icons.copy),
                          label: const Text('مشاركة قالب CSV'),
                        ),
                      ],
                    ),
                    if (sourceName != null) Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('الملف: $sourceName'),
                    ),
                  ],
                ),
              ),
            ),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                children: [
                  Chip(label: Text('إجمالي الصفوف: ${rows.length}')),
                  Chip(label: Text('صالحة: $validCount')),
                  Chip(label: Text('تحتاج تصحيحاً: $invalidCount')),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(row.valid ? Icons.check_circle_outline : Icons.error_outline,
                            color: row.valid ? Colors.green : Colors.orange),
                        title: Text('${row.asset.brand} ${row.asset.model} • ${row.asset.serialNumber}'),
                        subtitle: Text(row.valid ? 'السطر ${row.rowNumber} • جاهز للاستيراد' :
                          'السطر ${row.rowNumber} • ${row.errors.join('، ')}'),
                        isThreeLine: !row.valid,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: validCount == 0 || importing ? null : _importValidRows,
                icon: importing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(importing ? 'جارٍ الاستيراد...' : 'استيراد $validCount أصل صالح'),
              ),
            ] else
              const Expanded(child: Center(child: Text('اختر ملف CSV لعرض الصفوف والتحقق منها قبل الاستيراد'))),
          ],
        ),
      ),
    );
  }
}
