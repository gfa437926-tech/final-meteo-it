import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('التقارير والجرد')),
    body: Padding(padding: const EdgeInsets.all(20), child: GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 800 ? 3 : 1,
      childAspectRatio: 2.4, crossAxisSpacing: 14, mainAxisSpacing: 14,
      children: const [
        _ReportTile(icon: Icons.devices, title: 'جرد جميع الأصول', subtitle: 'قائمة شاملة حسب التصنيف'),
        _ReportTile(icon: Icons.business, title: 'الجرد حسب المكتب', subtitle: 'الأجهزة التابعة لكل مكتب'),
        _ReportTile(icon: Icons.calendar_month, title: 'الجرد حسب التاريخ', subtitle: 'استلام وتوزيع وإعادة'),
        _ReportTile(icon: Icons.memory, title: 'المواصفات الفنية', subtitle: 'CPU وRAM وStorage'),
        _ReportTile(icon: Icons.build, title: 'الصيانة', subtitle: 'الأعطال والإصلاحات'),
        _ReportTile(icon: Icons.file_download_outlined, title: 'التصدير', subtitle: 'Excel وCSV وPDF'),
      ],
    )),
  );
}
class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.icon, required this.title, required this.subtitle});
  final IconData icon; final String title, subtitle;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
    Icon(icon, size: 32, color: const Color(0xFF168C8C)), const SizedBox(width: 14),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(subtitle, style: const TextStyle(color: Colors.black54)),
    ])),
    const Icon(Icons.chevron_left),
  ])));
}
