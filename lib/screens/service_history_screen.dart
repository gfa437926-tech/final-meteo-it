import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/asset.dart';
import '../models/maintenance_record.dart';
import '../services/asset_repository.dart';
import '../services/maintenance_repository.dart';

class ServiceHistoryScreen extends StatefulWidget {
  const ServiceHistoryScreen({super.key});

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  final assetsRepository = AssetRepository();
  final maintenanceRepository = MaintenanceRepository();
  String? selectedAssetId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('السجل الفني للأجهزة')),
        body: StreamBuilder<List<Asset>>(
          stream: assetsRepository.watchAssets(),
          builder: (context, assetsSnapshot) {
            if (assetsSnapshot.hasError) {
              return Center(child: Text('تعذر تحميل الأصول: ${assetsSnapshot.error}'));
            }
            if (!assetsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final assets = assetsSnapshot.data!;
            if (assets.isEmpty) {
              return const Center(child: Text('لا توجد أصول ضمن المكاتب المصرح بها'));
            }
            final selected = assets.any((asset) => asset.id == selectedAssetId)
                ? selectedAssetId!
                : assets.first.id;
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
                      final label = '${asset.brand} ${asset.model}'.trim();
                      return DropdownMenuItem(
                        value: asset.id,
                        child: Text(
                          asset.serialNumber.isEmpty ? label : '$label • ${asset.serialNumber}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => selectedAssetId = value),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<MaintenanceRecord>>(
                    stream: maintenanceRepository.watch(),
                    builder: (context, historySnapshot) {
                      if (historySnapshot.hasError) {
                        return Center(child: Text('تعذر تحميل السجل: ${historySnapshot.error}'));
                      }
                      if (!historySnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final records = historySnapshot.data!
                          .where((record) => record.assetId == selected)
                          .toList()
                        ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
                      final totalCost = records.fold<double>(
                        0, (total, record) => total + record.cost + record.partsCost,
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
                                      final record = records[index];
                                      return Card(
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            child: Icon(record.status == MaintenanceStatus.completed
                                                ? Icons.check_circle_outline
                                                : record.status == MaintenanceStatus.cancelled
                                                    ? Icons.cancel_outlined
                                                    : Icons.build_outlined),
                                          ),
                                          title: Text(record.title,
                                              style: const TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text(
                                              'فتح الطلب: ${DateFormat('yyyy/MM/dd').format(record.reportedAt)}'
                                              '${record.completedAt == null ? '' : '\nالإغلاق: ${DateFormat('yyyy/MM/dd').format(record.completedAt!)}'}'
                                              '\nالفني: ${record.technician.isEmpty ? 'غير محدد' : record.technician}'
                                              '\nتكلفة الصيانة: ${NumberFormat('#,##0.##').format(record.cost)}'
                                              '\nقطع الغيار: ${NumberFormat('#,##0.##').format(record.partsCost)}'
                                              '${record.resolution.trim().isEmpty ? '' : '\nالحل: ${record.resolution}'}',
                                            ),
                                          ),
                                          isThreeLine: true,
                                          trailing: Chip(label: Text(record.status.label)),
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
