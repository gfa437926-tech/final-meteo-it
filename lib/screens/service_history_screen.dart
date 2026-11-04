import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ServiceHistoryScreen extends StatefulWidget {
  const ServiceHistoryScreen({super.key});

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  String? selectedAssetId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('السجل الفني للأجهزة')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('assets').snapshots(),
          builder: (context, assetsSnapshot) {
            if (assetsSnapshot.hasError) {
              return Center(child: Text('تعذر تحميل الأصول: ${assetsSnapshot.error}'));
            }
            if (!assetsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final assets = assetsSnapshot.data!.docs;
            if (assets.isEmpty) {
              return const Center(child: Text('لا توجد أصول مسجلة'));
            }
            final validSelection = assets.any((asset) => asset.id == selectedAssetId);
            final selected = validSelection ? selectedAssetId : assets.first.id;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<String>(
                    initialValue: selected,
                    decoration: const InputDecoration(
                      labelText: 'اختر الجهاز لعرض سجله الفني',
                      prefixIcon: Icon(Icons.devices_other),
                    ),
                    items: assets.map((asset) {
                      final data = asset.data();
                      final label = '${data['brand'] ?? ''} ${data['model'] ?? ''}'.trim();
                      final serial = data['serialNumber'] as String? ?? '';
                      return DropdownMenuItem(
                        value: asset.id,
                        child: Text(serial.isEmpty ? label : '$label • $serial',
                            overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => selectedAssetId = value),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('maintenance_records')
                        .snapshots(),
                    builder: (context, historySnapshot) {
                      if (historySnapshot.hasError) {
                        return Center(child: Text('تعذر تحميل السجل: ${historySnapshot.error}'));
                      }
                      if (!historySnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final records = historySnapshot.data!.docs
                          .where((doc) => doc.data()['assetId'] == selected)
                          .toList()
                        ..sort((a, b) => _date(b.data()['reportedAt'])
                            .compareTo(_date(a.data()['reportedAt'])));
                      final totalCost = records.fold<double>(
                        0,
                        (total, doc) => total + ((doc.data()['cost'] as num?)?.toDouble() ?? 0) +
                            ((doc.data()['partsCost'] as num?)?.toDouble() ?? 0),
                      );
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
                            child: Row(
                              children: [
                                Expanded(child: _SummaryTile(
                                  label: 'عدد الطلبات',
                                  value: '${records.length}',
                                  icon: Icons.build_outlined,
                                )),
                                const SizedBox(width: 10),
                                Expanded(child: _SummaryTile(
                                  label: 'إجمالي التكاليف',
                                  value: NumberFormat('#,##0.##').format(totalCost),
                                  icon: Icons.payments_outlined,
                                )),
                              ],
                            ),
                          ),
                          Expanded(
                            child: records.isEmpty
                                ? const Center(child: Text('لا يوجد سجل صيانة لهذا الجهاز'))
                                : ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: records.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final data = records[index].data();
                                      final status = data['status'] as String? ?? 'open';
                                      final reported = _date(data['reportedAt']);
                                      final completed = _date(data['completedAt']);
                                      final cost = (data['cost'] as num?)?.toDouble() ?? 0;
                                      final partsCost = (data['partsCost'] as num?)?.toDouble() ?? 0;
                                      return Card(
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            child: Icon(status == 'completed'
                                                ? Icons.check_circle_outline
                                                : status == 'cancelled'
                                                    ? Icons.cancel_outlined
                                                    : Icons.build_outlined),
                                          ),
                                          title: Text(data['title'] as String? ?? 'طلب صيانة',
                                              style: const TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text(
                                              'فتح الطلب: ${DateFormat('yyyy/MM/dd').format(reported)}'
                                              '${completed.year > 2000 ? '\nالإغلاق: ${DateFormat('yyyy/MM/dd').format(completed)}' : ''}'
                                              '\nالفني: ${data['technician'] ?? 'غير محدد'}'
                                              '\nالتكلفة: ${NumberFormat('#,##0.##').format(cost)}'
                                              '${(data['resolution'] as String? ?? '').trim().isEmpty ? '' : '\nالحل: ${data['resolution']}'}',
                                            ),
                                          ),
                                          isThreeLine: true,
                                          trailing: Chip(label: Text(switch (status) {
                                            'completed' => 'مكتمل',
                                            'cancelled' => 'ملغى',
                                            'inProgress' => 'قيد التنفيذ',
                                            _ => 'مفتوح',
                                          })),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      );

  static DateTime _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime(2000);
    return DateTime(2000);
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
