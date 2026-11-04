import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String status = 'all', category = 'all', office = 'all';
  static const statuses = <String, String>{
    'all': 'كل الحالات', 'available': 'متوفر', 'assigned': 'بعهدة موظف',
    'maintenance': 'قيد الصيانة', 'damaged': 'تالف', 'retired': 'مستبعد',
    'returned': 'معاد',
  };
  static const categories = <String, String>{
    'all': 'كل التصنيفات', 'desktop': 'كمبيوتر مكتبي', 'laptop': 'لابتوب',
    'monitor': 'شاشة', 'printer': 'طابعة', 'scanner': 'ماسح',
    'network': 'معدات شبكة', 'storage': 'تخزين', 'ups': 'UPS',
    'accessory': 'ملحقات', 'other': 'أخرى',
  };

  String safeCell(Object? value) {
    final text = value?.toString() ?? '';
    if (RegExp(r'^\s*[=+@\\-]').hasMatch(text) ||
        text.startsWith('\t') || text.startsWith('\r')) return "'$text";
    return text;
  }

  Future<void> copyCsv(BuildContext context,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final rows = <List<dynamic>>[
      ['معرّف الأصل', 'التصنيف', 'الشركة', 'الطراز', 'الرقم التسلسلي', 'الحالة', 'المكتب'],
      ...docs.map((doc) {
        final data = doc.data();
        return [
          safeCell(doc.id),
          safeCell(categories[data['category'] as String? ?? 'other'] ?? data['category']),
          safeCell(data['brand']), safeCell(data['model']), safeCell(data['serialNumber']),
          safeCell(statuses[data['status'] as String? ?? 'available'] ?? data['status']),
          safeCell(data['officeName']),
        ];
      }),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    await Clipboard.setData(ClipboardData(text: '\uFEFF$csv'));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم نسخ تقرير ' + docs.length.toString() + ' أصل بعد التصفية')),
      );
    }
  }

  Widget filter<T extends String>({
    required String label, required T value,
    required Map<T, String> options, required ValueChanged<T?> onChanged,
  }) => SizedBox(width: 210, child: DropdownButtonFormField<T>(
    value: value, isExpanded: true,
    decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
    items: options.entries.map((e) => DropdownMenuItem<T>(
      value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
    onChanged: onChanged,
  ));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('التقارير والجرد')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('assets').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('تعذر تحميل الإحصائيات: ' + snapshot.error.toString()));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final allDocs = snapshot.data!.docs;
        final offices = allDocs.map((d) => (d.data()['officeName'] as String? ?? '').trim())
          .where((x) => x.isNotEmpty).toSet().toList()..sort();
        final officeOptions = <String, String>{'all': 'كل المكاتب', for (final x in offices) x: x};
        if (!officeOptions.containsKey(office)) office = 'all';
        final docs = allDocs.where((d) {
          final data = d.data();
          return (status == 'all' || (data['status'] as String? ?? 'available') == status) &&
            (category == 'all' || (data['category'] as String? ?? 'other') == category) &&
            (office == 'all' || (data['officeName'] as String? ?? '').trim() == office);
        }).toList();
        int count(String value) => docs.where((d) => d.data()['status'] == value).length;
        final byCategory = <String, int>{};
        for (final d in docs) {
          final key = d.data()['category'] as String? ?? 'other';
          byCategory[key] = (byCategory[key] ?? 0) + 1;
        }
        return ListView(padding: const EdgeInsets.all(20), children: [
          const Text('ملخص الجرد الحالي', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('نتائج التقرير: ' + docs.length.toString() + ' من أصل ' + allDocs.length.toString() + ' جهاز'),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            filter<String>(label: 'حالة الأصل', value: status, options: statuses,
              onChanged: (v) => setState(() => status = v ?? 'all')),
            filter<String>(label: 'تصنيف الأصل', value: category, options: categories,
              onChanged: (v) => setState(() => category = v ?? 'all')),
            filter<String>(label: 'المكتب', value: office, options: officeOptions,
              onChanged: (v) => setState(() => office = v ?? 'all')),
            OutlinedButton.icon(onPressed: () => setState(() {
              status = 'all'; category = 'all'; office = 'all';
            }), icon: const Icon(Icons.filter_alt_off), label: const Text('مسح التصفية')),
          ]),
          const SizedBox(height: 18),
          GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.sizeOf(context).width > 850 ? 4 : 2,
            childAspectRatio: 1.65, crossAxisSpacing: 12, mainAxisSpacing: 12,
            children: [
              _Metric('إجمالي النتائج', docs.length, Icons.devices),
              _Metric('متوفر', count('available'), Icons.inventory_2_outlined),
              _Metric('بعهدة الموظفين', count('assigned'), Icons.assignment_ind),
              _Metric('قيد الصيانة', count('maintenance'), Icons.build_circle_outlined),
            ]),
          const SizedBox(height: 22),
          const Text('التوزيع حسب التصنيف', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Card(child: byCategory.isEmpty
            ? const ListTile(title: Text('لا توجد بيانات مطابقة للتصفية'))
            : Column(children: byCategory.entries.map((e) => ListTile(
                title: Text(categories[e.key] ?? e.key),
                trailing: Text(e.value.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              )).toList())),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: docs.isEmpty ? null : () => copyCsv(context, docs),
            icon: const Icon(Icons.content_copy), label: const Text('نسخ النتائج المصفاة بصيغة CSV')),
          const SizedBox(height: 8),
          const Text('يتضمن التقرير معرّف الأصل والتصنيف والشركة والطراز والرقم التسلسلي والحالة والمكتب. وتحمي عملية التصدير الخلايا النصية من صيغ الجداول التنفيذية.',
            style: TextStyle(color: Colors.black54)),
        ]);
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
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: const Color(0xFF168C8C)), const Spacer(),
        Text(value.toString(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.black54)),
      ]),
  ));
}
