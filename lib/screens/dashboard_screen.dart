import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:metra_it_assets/models/asset.dart';
import 'package:metra_it_assets/screens/offices_screen.dart';
import 'package:metra_it_assets/screens/assets_screen.dart';
import 'package:metra_it_assets/screens/custody_screen.dart';
import 'package:metra_it_assets/screens/reports_screen.dart';
import 'package:metra_it_assets/screens/maintenance_screen.dart';
import 'package:metra_it_assets/screens/asset_movements_screen.dart';

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
                  Wrap(spacing: 14, runSpacing: 14, children: const [
                    _MetricCard(title: 'إجمالي الأصول', value: '0', icon: Icons.devices, color: navy),
                    _MetricCard(title: 'المكاتب', value: '0', icon: Icons.business_outlined, color: teal),
                    _MetricCard(title: 'أجهزة موزعة', value: '0', icon: Icons.assignment_turned_in_outlined, color: Color(0xFF7C5CBA)),
                    _MetricCard(title: 'تحتاج صيانة', value: '0', icon: Icons.build_outlined, color: Color(0xFFD97706)),
                  ]),
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
                            child: Column(children: AssetCategory.values.map((c) =>
                              _CategoryRow(label: c.label, count: 0)).toList()),
                          ),
                        ),
                        if (twoColumns) const SizedBox(width: 16) else const SizedBox(height: 16),
                        Expanded(
                          flex: twoColumns ? 2 : 0,
                          child: _Panel(
                            title: 'آخر النشاطات',
                            child: const Column(children: [
                              _ActivityRow(icon: Icons.add_box_outlined, text: 'لا توجد عمليات مسجلة بعد'),
                              Divider(),
                              _ActivityRow(icon: Icons.sync_alt, text: 'ستظهر حركة الأصول هنا'),
                              Divider(),
                              _ActivityRow(icon: Icons.build_outlined, text: 'ستظهر طلبات الصيانة هنا'),
                            ]),
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 20),
                  const _Panel(title: 'تنبيه', child: Text('هذه نسخة تأسيسية. الأرقام صفر حتى ربط قاعدة البيانات وإدخال الأصول الفعلية.')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation();
  @override
  Widget build(BuildContext context) => Container(
    width: 230, color: DashboardScreen.navy,
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(padding: EdgeInsets.all(12), child: Text('إدارة الأصول', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
      _NavItem(icon: Icons.dashboard_outlined, label: 'لوحة التحكم', selected: true),
      _NavItem(icon: Icons.business_outlined, label: 'المكاتب', destination: const OfficesScreen()),
      _NavItem(icon: Icons.devices_outlined, label: 'الأجهزة والجرد', destination: const AssetsScreen()),
      _NavItem(icon: Icons.assignment_outlined, label: 'بطاقات العهدة', destination: const CustodyScreen()),
      _NavItem(icon: Icons.swap_horiz, label: 'حركة الأجهزة', destination: const AssetMovementsScreen()),
      _NavItem(icon: Icons.build_outlined, label: 'الصيانة', destination: const MaintenanceScreen()),
      _NavItem(icon: Icons.analytics_outlined, label: 'التقارير', destination: const ReportsScreen()),
      const Spacer(),
      _NavItem(icon: Icons.settings_outlined, label: 'الإعدادات'),
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
      onTap: destination == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => destination!)),
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

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.icon, required this.text});
  final IconData icon; final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
    Icon(icon, size: 18, color: DashboardScreen.teal), const SizedBox(width: 10), Expanded(child: Text(text)),
  ]));
}
