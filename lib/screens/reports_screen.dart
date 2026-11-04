import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  Future<void> _copyCsv(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) async {
    final rows = <List<dynamic>>[
      ['معرّف الأصل', 'التصنيف', 'الشركة', 'الطراز', 'الرقم التسلسلي', 'الحالة', 'المكتب'],
      ...documents.map((document) {
        final data = document.data();
        return [
          document.id,
          _categoryLabel(data['category'] as String? ?? 'other'),
          data['brand'] ?? '',
          data['model'] ?? '',
          data['serialNumber'] ?? '',
          _statusLabel(data['status'] as String? ?? 'available'),
          data['officeName'] ?? '',
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

            final documents = snapshot.data!.docs;
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
                const Text(
                  'يحتوي التقرير على معرّف الأصل والتصنيف والشركة والطراز والرقم التسلسلي والحالة والمكتب. يدعم النص العربي ويمكن لصقه مباشرة في Excel.',
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
