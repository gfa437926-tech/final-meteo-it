import 'package:flutter/material.dart';

class CustodyScreen extends StatelessWidget {
  const CustodyScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('بطاقات العهدة')),
    body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      Row(children: [const Expanded(child: Text('بطاقات العهدة', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))), FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('بطاقة جديدة'))]),
      const SizedBox(height: 18),
      const Expanded(child: Card(child: Center(child: Text('لا توجد بطاقات عهدة بعد')))),
    ])),
  );
}
