import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:metra_it_assets/models/asset.dart';
import 'package:metra_it_assets/services/asset_repository.dart';
import 'package:metra_it_assets/services/office_repository.dart';
import 'package:metra_it_assets/screens/offices_screen.dart';
import 'package:metra_it_assets/screens/assets_screen.dart';
import 'package:metra_it_assets/screens/custody_screen.dart';
import 'package:metra_it_assets/screens/reports_screen.dart';
import 'package:metra_it_assets/screens/maintenance_screen.dart';
import 'package:metra_it_assets/screens/asset_movements_screen.dart';
import 'package:metra_it_assets/screens/user_management_screen.dart';
import 'package:metra_it_assets/screens/purchases_screen.dart';
import 'package:metra_it_assets/screens/service_history_screen.dart';
import 'package:metra_it_assets/screens/spare_parts_screen.dart';
import 'package:metra_it_assets/screens/asset_documents_screen.dart';
import 'package:metra_it_assets/screens/asset_import_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const navy = Color(0xFF183B56);
  static const teal = Color(0xFF168C8C);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.inventory_2_outlined, color: teal),
          SizedBox(width: 10),
          Text('METRA IT ASSETS', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          IconButton(onPressed: () {}, tooltip: 'الإشعارات', icon: const Icon(Icons.notifications_none)),
          const Padding(
            padding: EdgeInsetsDirectional.only(end: 4),
            child: CircleAvatar(backgroundColor: Color(0xFFE2F1F1), child: Icon(Icons.person, color: navy)),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('تسجيل الخروج'),
                  content: const Text('هل تريد إنهاء جلسة العمل الحالية؟'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تسجيل الخروج')),
                  ],
                ),
              );
              if (confirmed == true) await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: wide ? null : const Drawer(
        child: SafeArea(child: _SideNavigation()),
      ),
      body: Row(
        children: [
          if (wide) const _SideNavigation(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('لوحة التحكم', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: navy)),
                  const SizedBox(height: 6),
                  const Text('نظرة عامة على الأصول والتجهيزات التقنية', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 24),
                  const _LiveMetrics(),
                  const SizedBox(height: 24),
                  LayoutBuilder(builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth > 760;
                    return Flex(
                      direction: twoColumns ? Axis.horizontal : Axis.vertical,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: twoColumns ? 3 : 0,
                          child: _Panel(
                            title: 'التصنيف حسب نوع الجهاز',
                            child: const _LiveCategoryOverview(),
                          ),
                        ),
                        if (twoColumns) const SizedBox(width: 16) else const SizedBox(height: 16),
                        Expanded(
                          flex: twoColumns ? 2 : 0,
                          child: _Panel(
                            title: 'آخر النشاطات',
                            child: const _LiveActivityFeed(),
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 20),
                  const _Panel(title: 'تنبيه', child: Text('تُحدّث مؤشرات الأصول والمكاتب تلقائياً من قاعدة البيانات عند توفر الاتصال.')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _LiveMetrics extends StatelessWidget {
  const _LiveMetrics();

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AssetRepository().watchAssetDocuments(),
        builder: (context, assetSnapshot) {
          if (assetSnapshot.hasError) {
            return const Text('تعذر تحميل إحصائيات الأصول');
          }
          if (!assetSnapshot.hasData) {
            return const LinearProgressIndicator();
          }
          final assets = assetSnapshot.data!.docs;
          final assigned = assets.where((doc) => doc.data()['status'] == 'assigned').length;
          final maintenance = assets.where((doc) => doc.data()['status'] == 'maintenance').length;
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: OfficeRepository().watchOffices(),
            builder: (context, officeSnapshot) {
              final officeCount = officeSnapshot.data?.length ?? 0;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _MetricCard(title: 'إجمالي الأصول', value: '${assets.length}', icon: Icons.devices, color: DashboardScreen.navy),
                  _MetricCard(title: 'المكاتب', value: '${officeSnapshot.hasError ? '—' : officeCount}', icon: Icons.business_outlined, color: DashboardScreen.teal),
                  _MetricCard(title: 'أجهزة موزعة', value: '$assigned', icon: Icons.assignment_turned_in_outlined, color: const Color(0xFF7C5CBA)),
                  _MetricCard(title: 'تحتاج صيانة', value: '$maintenance', icon: Icons.build_outlined, color: const Color(0xFFD97706)),
                ],
              );
            },
          );
        },
      );
}


class _LiveActivityFeed extends StatelessWidget {
  const _LiveActivityFeed();

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('asset_movements')
            .orderBy('occurredAt', descending: true)
            .limit(5)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('تعذر تحميل سجل النشاطات');
          }
          if (!snapshot.hasData) {
            return const LinearProgressIndicator();
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Text('لا توجد عمليات مسجلة بعد');
          }
          return Column(
            children: docs.map((doc) {
              final data = doc.data();
              final type = data['movementType'] as String? ?? '';
              final label = switch (type) {
                'assigned' => 'تسليم عهدة',
                'returned' => 'إرجاع جهاز',
                'transferred' => 'نقل بين المكاتب',
                'custody_transferred' => 'نقل عهدة لموظف',
                'custody_approved' => 'اعتماد بطاقة عهدة',
                'custody_rejected' => 'رفض بطاقة عهدة',
                'retired' => 'استبعاد أصل',
                'maintenance_opened' => 'إرسال للصيانة',
                'maintenance_completed' => 'إنهاء الصيانة',
                _ => 'حركة أصل',
              };
              final asset = data['assetLabel'] as String? ?? 'جهاز';
              final employee = data['toEmployee'] as String? ??
                  data['fromEmployee'] as String? ??
                  '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    const Icon(Icons.history, size: 18, color: DashboardScreen.teal),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            employee.isEmpty ? asset : '$asset • $employee',
                            style: const TextStyle(color: Colors.black54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      );
}

class _LiveCategoryOverview extends StatelessWidget {
  const _LiveCategoryOverview();

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AssetRepository().watchAssetDocuments(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('تعذر تحميل توزيع الأصول حسب النوع');
          }
          if (!snapshot.hasData) {
            return const LinearProgressIndicator();
          }
          final documents = snapshot.data!.docs;
          return Column(
            children: AssetCategory.values.map((category) {
              final count = documents
                  .where((doc) => doc.data()['category'] == category.name)
                  .length;
              return _CategoryRow(label: category.label, count: count);
            }).toList(),
          );
        },
      );
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation();
  @override
  Widget build(BuildContext context) => Container(
    width: 230, color: DashboardScreen.navy,
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(padding: EdgeInsets.all(12), child: Text('إدارة الأصول', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
      Expanded(child: ListView(padding: EdgeInsets.zero, children: [
      _NavItem(icon: Icons.dashboard_outlined, label: 'لوحة التحكم', selected: true),
      _NavItem(icon: Icons.business_outlined, label: 'المكاتب', destination: const OfficesScreen()),
      _NavItem(icon: Icons.devices_outlined, label: 'الأجهزة والجرد', destination: const AssetsScreen()),
      _NavItem(icon: Icons.assignment_outlined, label: 'بطاقات العهدة', destination: const CustodyScreen()),
      _NavItem(icon: Icons.swap_horiz, label: 'حركة الأجهزة', destination: const AssetMovementsScreen()),
      _NavItem(icon: Icons.build_outlined, label: 'الصيانة', destination: const MaintenanceScreen()),
      _NavItem(icon: Icons.history_edu_outlined, label: 'السجل الفني للأجهزة', destination: const ServiceHistoryScreen()),
      _NavItem(icon: Icons.inventory_2_outlined, label: 'مخزون قطع الغيار', destination: const SparePartsScreen()),
      _NavItem(icon: Icons.receipt_long_outlined, label: 'المشتريات والضمان', destination: const PurchasesScreen()),
      _NavItem(icon: Icons.attach_file_outlined, label: 'مرفقات الأصول', destination: const AssetDocumentsScreen()),
      _NavItem(icon: Icons.file_upload_outlined, label: 'استيراد الأصول', destination: const AssetImportScreen()),
      _NavItem(icon: Icons.analytics_outlined, label: 'التقارير', destination: const ReportsScreen()),
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.data?.data()?['role'] != 'admin') {
            return const SizedBox.shrink();
          }
          return const _NavItem(
            icon: Icons.manage_accounts_outlined,
            label: 'المستخدمون والصلاحيات',
            destination: UserManagementScreen(),
          );
        },
      ),
      _NavItem(icon: Icons.settings_outlined, label: 'الإعدادات'),
      ])),
    ]),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, this.selected = false, this.destination});
  final IconData icon; final String label; final bool selected; final Widget? destination;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: ListTile(
      dense: true, selected: selected, selectedTileColor: Colors.white.withValues(alpha: .13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon, color: Colors.white70), title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: destination == null ? null : () {
        // Close the responsive drawer before opening the selected module.
        Scaffold.maybeOf(context)?.closeDrawer();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => destination!),
        );
      },
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.icon, required this.color});
  final String title, value; final IconData icon; final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(width: 220, child: Card(child: Padding(
    padding: const EdgeInsets.all(18),
    child: Row(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 5), Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
      ])),
    ]),
  )));
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title; final Widget child;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      child,
    ],
  )));
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.label, required this.count});
  final String label; final int count;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [
    Expanded(child: Text(label)), Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
  ]));
}

