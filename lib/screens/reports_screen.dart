import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? categoryFilter;
  String? statusFilter;
  String? officeFilter;

  String _safeCell(Object? value) {
    final text = value?.toString() ?? '';
    if (RegExp(r'^\\s*[=+@\\-]').hasMatch(text) ||
        text.startsWith('\\t') || text.startsWith('\\r')) {
      return \"'$text\";
    }
    return text;
  }
  String? officeFilter;

  Future<void> _copyCsv(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) async {
    final rows = <List<dynamic>>[
      ['معرّف الأصل', 'التصنيف', 'الشركة', 'الطراز', 'الرقم التسلسلي', 'الحالة', 'المكتب'],
      ...documents.map((document) {
        final data = document.data();
        return [
          _safeCell(document.id),
          _safeCell(_categoryLabel(data['category'] as String? ?? 'other')),
          _safeCell(data['brand']),
          _safeCell(data['model']),
          _safeCell(data['serialNumber']),
          _safeCell(_statusLabel(data['status'] as String? ?? 'available')),
          _safeCell(data['officeName']),
        ];
      }),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    await Clipboard.setData(ClipboardData(text: '\uFEFF$csv'));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ تقرير CSV إلى الحافظة؛ يمكنك لصقه مباشرة في Excel')),
      );
    }
  }

  Future<void> _exportExcel(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) async {
    final workbook = Excel.createExcel();
    final sheet = workbook['الأصول'];
    sheet.appendRow([
      TextCellValue('معرّف الأصل'),
      TextCellValue('التصنيف'),
      TextCellValue('الشركة'),
      TextCellValue('الطراز'),
      TextCellValue('الرقم التسلسلي'),
      TextCellValue('الحالة'),
      TextCellValue('المكتب'),
    ]);
    for (final document in documents) {
      final data = document.data();
      sheet.appendRow([
        TextCellValue(_safeCell(document.id)),
        TextCellValue(_safeCell(_categoryLabel(data['category'] as String? ?? 'other'))),
        TextCellValue(_safeCell(data['brand'])),
        TextCellValue(_safeCell(data['model'])),
        TextCellValue(_safeCell(data['serialNumber'])),
        TextCellValue(_safeCell(_statusLabel(data['status'] as String? ?? 'available'))),
        TextCellValue(_safeCell(data['officeName'])),
      ]);
    }
    final bytes = workbook.encode();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('تعذر إنشاء ملف Excel');
    }
    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          name: 'it-assets.xlsx',
        ),
      ],
      text: 'تقرير جرد الأصول التقنية',
    );
  }

  Future<void> _shareCsv(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) async {
    final rows = <List<dynamic>>[
      ['معرّف الأصل', 'التصنيف', 'الشركة', 'الطراز', 'الرقم التسلسلي', 'الحالة', 'المكتب'],
      ...documents.map((document) {
        final data = document.data();
        return [
          _safeCell(document.id),
          _safeCell(_categoryLabel(data['category'] as String? ?? 'other')),
          _safeCell(data['brand']),
          _safeCell(data['model']),
          _safeCell(data['serialNumber']),
          _safeCell(_statusLabel(data['status'] as String? ?? 'available')),
          _safeCell(data['officeName']),
        ];
      }),
    ];
    final csv = '\uFEFF${const ListToCsvConverter().convert(rows)}';
    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(utf8.encode(csv)),
          mimeType: 'text/csv',
          name: 'it-assets.csv',
        ),
      ],
      text: 'تقرير جرد الأصول التقنية بصيغة CSV',
    );
  }

  static String _categoryLabel(String value) => const {
        'desktop': 'كمبيوتر مكتبي',
        'laptop': 'لابتوب',
        'monitor': 'شاشة',
        'printer': 'طابعة',
        'scanner': 'ماسح',
        'network': 'معدات شبكة',
        'storage': 'تخزين',
        'ups': 'UPS',
        'accessory': 'ملحقات',
        'other': 'أخرى',
      }[value] ?? value;

  static String _statusLabel(String value) => const {
        'available': 'متوفر',
        'assigned': 'بعهدة موظف',
        'maintenance': 'قيد الصيانة',
        'damaged': 'تالف',
        'retired': 'مستبعد',
        'returned': 'معاد',
      }[value] ?? value;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('التقارير والجرد')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('assets').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('تعذر تحميل الإحصائيات: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final documents = snapshot.data!.docs.where((document) {
              final data = document.data();
              return (categoryFilter == null || data['category'] == categoryFilter) &&
                  (statusFilter == null || data['status'] == statusFilter) &&
                  (officeFilter == null || data['officeId'] == officeFilter);
            }).toList();
            int count(String status) => documents
                .where((document) => document.data()['status'] == status)
                .length;
            final categories = <String, int>{};
            for (final document in documents) {
              final key = document.data()['category'] as String? ?? 'other';
              categories[key] = (categories[key] ?? 0) + 1;
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'ملخص الجرد الحالي',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('offices').orderBy('name').snapshots(),
                  builder: (context, officeSnapshot) {
                    final offices = officeSnapshot.data?.docs ?? [];
                    return Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            initialValue: categoryFilter,
                            decoration: const InputDecoration(labelText: 'تصفية حسب التصنيف'),
                            items: [
                              const DropdownMenuItem<String>(value: null, child: Text('كل التصنيفات')),
                              ...['desktop','laptop','monitor','printer','scanner','network','storage','ups','accessory','other']
                                  .map((value) => DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(_categoryLabel(value)),
                                      )),
                            ],
                            onChanged: (value) => setState(() => categoryFilter = value),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            initialValue: statusFilter,
                            decoration: const InputDecoration(labelText: 'تصفية حسب الحالة'),
                            items: [
                              const DropdownMenuItem<String>(value: null, child: Text('كل الحالات')),
                              ...['available','assigned','maintenance','damaged','retired','returned']
                                  .map((value) => DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(_statusLabel(value)),
                                      )),
                            ],
                            onChanged: (value) => setState(() => statusFilter = value),
                          ),
                        ),
                        SizedBox(
                          width: 240,
                          child: DropdownButtonFormField<String>(
                            initialValue: officeFilter,
                            decoration: const InputDecoration(labelText: 'تصفية حسب المكتب'),
                            items: [
                              const DropdownMenuItem<String>(value: null, child: Text('كل المكاتب')),
                              ...offices.map((office) => DropdownMenuItem<String>(
                                    value: office.id,
                                    child: Text(
                                      office.data()['name'] as String? ?? office.id,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )),
                            ],
                            onChanged: (value) => setState(() => officeFilter = value),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: categoryFilter == null && statusFilter == null && officeFilter == null
                              ? null
                              : () => setState(() {
                                    categoryFilter = null;
                                    statusFilter = null;
                                    officeFilter = null;
                                  }),
                          icon: const Icon(Icons.filter_alt_off),
                          label: const Text('مسح التصفية'),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: MediaQuery.sizeOf(context).width > 850 ? 4 : 2,
                  childAspectRatio: 1.65,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _Metric('إجمالي الأصول', documents.length, Icons.devices),
                    _Metric('متوفر', count('available'), Icons.inventory_2_outlined),
                    _Metric('بعهدة الموظفين', count('assigned'), Icons.assignment_ind),
                    _Metric('قيد الصيانة', count('maintenance'), Icons.build_circle_outlined),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'التوزيع حسب التصنيف',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Card(
                  child: categories.isEmpty
                      ? const ListTile(title: Text('لا توجد بيانات بعد'))
                      : Column(
                          children: categories.entries
                              .map(
                                (entry) => ListTile(
                                  title: Text(_categoryLabel(entry.key)),
                                  trailing: Text(
                                    '${entry.value}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: documents.isEmpty
                      ? null
                      : () => _copyCsv(context, documents),
                  icon: const Icon(Icons.content_copy),
                  label: const Text('نسخ تقرير الأصول بصيغة CSV'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: documents.isEmpty
                      ? null
                      : () async {
                          try {
                            await _shareCsv(context, documents);
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('تعذر مشاركة CSV: $error')),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('تصدير CSV كملف'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: documents.isEmpty
                      ? null
                      : () async {
                          try {
                            await _exportExcel(context, documents);
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('تعذر تصدير Excel: $error')),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.table_view_outlined),
                  label: const Text('تصدير Excel'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يمكن نسخ التقرير أو مشاركته كملف CSV أو Excel، مع المحافظة على أسماء الحقول والبيانات العربية.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            );
          },
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF168C8C)),
              const Spacer(),
              Text(
                '$value',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              Text(label, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      );
}
