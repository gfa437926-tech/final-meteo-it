import 'package:flutter/material.dart';
import 'package:metra_it_assets/models/office.dart';

class OfficesScreen extends StatelessWidget {
  const OfficesScreen({super.key});
  static const sampleOffices = <Office>[];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('دليل المكاتب')),
    body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      Row(children: [
        const Expanded(child: Text('المكاتب ومراكز العمل', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
        FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('إضافة مكتب')),
      ]),
      const SizedBox(height: 18),
      TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'ابحث باسم المكتب أو المديرية', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
      const SizedBox(height: 18),
      Expanded(child: Card(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.business_outlined, size: 54, color: Colors.blueGrey.shade300),
        const SizedBox(height: 12),
        const Text('لا توجد مكاتب مسجلة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const Text('اربط Firestore أو أضف أول مكتب لبدء الجرد'),
      ])))),
    ])),
  );
}
